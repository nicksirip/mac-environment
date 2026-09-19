# /path/to/.bash_profile

# ==========================================
# 1. Bash Version Upgrade (macOS Compatibility)
# ==========================================
# Use Homebrew bash for interactive shells started under macOS bash 3.2.
# This keeps modern completion features working (bash-completion@2 needs bash >= 4.1).
# Skip re-exec inside VS Code/Electron processes and prevent re-exec loops.
# The interactive + version gate is checked FIRST so non-interactive shells
# (scripts, `bash -c`) never pay for the `ps` fork below.
if (( BASH_VERSINFO[0] < 4 )) && [[ $- == *i* ]] \
        && [[ "${TERM_PROGRAM:-}" != "vscode" ]] \
        && [[ -z "${ELECTRON_RUN_AS_NODE:-}" ]] \
        && [[ -x /opt/homebrew/bin/bash ]] \
        && [[ -z "${BASH_PROFILE_REEXEC:-}" ]]; then
    _ppid_comm=$(ps -o comm= -p "$PPID" 2>/dev/null || true)
    if [[ "${_ppid_comm}" != *"node"* ]] \
            && [[ "${_ppid_comm}" != *"Electron"* ]] \
            && [[ "${_ppid_comm}" != *"Code Helper"* ]]; then
        unset _ppid_comm
        export BASH_PROFILE_REEXEC=1
        exec -l /opt/homebrew/bin/bash
    fi
    unset _ppid_comm
fi

# ==========================================
# 2. Environment Variables
# ==========================================

# Homebrew
export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_REPOSITORY="/opt/homebrew"

# Prepend Homebrew paths
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin${PATH+:$PATH}"
export MANPATH="/opt/homebrew/share/man${MANPATH+:$MANPATH}:"
export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}:"

# General Environment
export EDITOR=vi
# LANG (not LC_ALL) — sets the default locale for all categories but can be
# selectively overridden by a more specific LC_* var if ever needed. LC_ALL
# forcibly overrides everything with no override path, which is exactly what
# would force an `env -u LC_ALL` workaround in the tmux launch block below.
export LANG=C.UTF-8

# Ensure child processes (especially tmux panes) spawn with the current bash.
# tmux panes are non-login shells, so they do not read this file themselves.
# $BASH is the path to the currently-running bash binary (e.g. the Homebrew
# bash re-exec'd in section 1) — intentionally the binary, not a login wrapper.
export SHELL="${BASH}"

# ==========================================
# 3. History Settings  (see interactive block in section 4 — history is only
#    meaningful for interactive shells, so the config lives there)
# ==========================================

# ==========================================
# 4. Interactive-Only Settings
# ==========================================
if [[ $- == *i* ]]; then

    # --- History ---
    # ignoredups:ignorespace — skip consecutive dups and space-prefixed commands.
    # Dropped 'erasedups': at HISTSIZE 50000 it rescans the whole in-memory list
    # on every command to purge older dups, which adds measurable per-prompt cost.
    HISTCONTROL=ignoredups:ignorespace
    HISTSIZE=50000
    HISTFILESIZE=50000
    # Append rather than overwrite, so concurrent shells/tmux panes don't clobber
    # each other's history when they exit (last-writer-wins without this).
    shopt -s histappend

    # Reset INT/HUP/TERM to their default disposition (clears any traps that a
    # parent process or earlier sourcing may have installed) so interactive
    # Ctrl-C / hangup behave normally in this shell.
    trap INT
    trap HUP
    trap TERM

    # --- Completions ---
    # Source completion scripts if they exist.
    [ -f ~/.brew-completion.bash ]   && . ~/.brew-completion.bash
    [ -f ~/.ssh-completion.bash ]    && . ~/.ssh-completion.bash
    [ -f ~/.podman-completion.bash ] && . ~/.podman-completion.bash

    # --- Tool Initialization ---

    # _cached_init <tool> <cache-name> <command...>
    # Caches the stdout of a tool's shell-init command to ~/.cache/bash-init/ and
    # sources the cache instead of spawning the tool every shell. Regenerates only
    # when the tool binary is NEWER than the cache, so upgrades are picked up.
    # Avoids one subprocess per shell/pane.
    #   Safety: some tools (fzf, starship) emit init only for a real interactive
    #   shell and print little/nothing otherwise. We only WRITE the cache if the
    #   capture looks substantial (>5 lines); otherwise we fall back to a live
    #   eval this shell and leave no cache, so a degraded capture never sticks.
    #   Only use for STABLE init output — never session-specific data (e.g. the
    #   keychain agent socket).
    _cached_init() {
        local tool="$1" name="$2"; shift 2
        command -v "$tool" &>/dev/null || return 0
        local dir="$HOME/.cache/bash-init" cache tmp
        cache="$dir/$name.bash"
        if [[ -s "$cache" && ! "$(command -v "$tool")" -nt "$cache" ]]; then
            source "$cache"; return
        fi
        mkdir -p "$dir"
        tmp="$(mktemp "$dir/.$name.XXXXXX")"
        if "$@" > "$tmp" 2>/dev/null && [[ "$(wc -l < "$tmp")" -gt 5 ]]; then
            mv -f "$tmp" "$cache"
            source "$cache"
        else
            # Capture too thin to trust — don't cache; init live this shell.
            rm -f "$tmp"
            eval "$("$@" 2>/dev/null)"
        fi
    }

    # Fzf (cached) — skipped automatically if fzf isn't installed.
    _cached_init fzf fzf fzf --bash

    # Keychain (SSH agent manager) — NOT cached: output carries the live agent
    # socket/PID, which is session-specific and must be evaluated fresh.
    if command -v keychain &>/dev/null; then
        eval "$(keychain --nolock --eval -q)"
    fi

    # Starship Prompt (cached).
    #   `starship init bash` only prints a 1-line bootstrap that itself evals
    #   `starship init bash --print-full-init` at runtime — so we cache the REAL
    #   full-init payload directly (~150 lines) to actually save the subprocess.
    #   Starship preserves/prepends any existing PROMPT_COMMAND, so the history
    #   `history -a` set below survives.
    _cached_init starship starship starship init bash --print-full-init

    # Now that starship has set PROMPT_COMMAND (it overwrites, doesn't preserve),
    # append the per-command history flush so tmux panes share history in near
    # real-time. Guard against double-adding if this file is re-sourced.
    case "${PROMPT_COMMAND:-}" in
      *"history -a"*) : ;;
      *) PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a" ;;
    esac

    # --- Session Management (Tmux) ---
    # Do not auto-enter tmux in VS Code integrated terminals.
    # Escape hatch: set NO_TMUX=1 before launching a shell to skip auto-attach
    # for that one shell (e.g. `NO_TMUX=1 bash -l`).
    if [ -z "$TMUX" ] && [ "${TERM_PROGRAM:-}" != "vscode" ] && [ -z "${NO_TMUX:-}" ]; then
        # Always attach to the running tmux server if it has ANY session; only
        # create a session when the server is empty/not running. `tmux attach`
        # (no target) attaches to the most-recently-used existing session.
        # env -u LANG avoids locale issues inside tmux unless explicitly set later.
        if env -u LANG tmux has-session 2>/dev/null; then
            # Attach with an INDEPENDENT view instead of mirroring. Plain
            # `tmux attach` shares the current window with other clients, so
            # switching windows/panes in one terminal moves them in all. A
            # grouped session (`new-session -t <target>`) shares the SAME
            # windows but keeps its own current-window selection, so this
            # terminal can view a different window/pane without disturbing the
            # others. `destroy-unattached on` (scoped to just this throwaway
            # grouped session via `\;`) cleans it up on detach so grouped
            # sessions don't pile up. Target the newest existing session by name.
            _tmux_target=$(env -u LANG tmux list-sessions -F '#{session_name}' 2>/dev/null | head -1)
            env -u LANG tmux new-session -t "$_tmux_target" \; set-option destroy-unattached on
        else
            env -u LANG tmux new-session -s default
        fi
    fi

fi # end interactive-only settings

# ─────────────────────────────────────────────────────────────────────────
# De-duplicate PATH/MANPATH/INFOPATH — prevents entries from accumulating
# if this file is sourced more than once in the same shell (e.g. after
# editing it and running `source ~/.bash_profile`). Placed near the end so
# it catches everything added above it.
# ─────────────────────────────────────────────────────────────────────────
_dedup_path() {
  local p="$1" seen=":" out=""
  local IFS=:
  for dir in $p; do
    [[ -z "$dir" ]] && continue
    case "$seen" in
      *":$dir:"*) ;;
      *) out="${out:+$out:}$dir"; seen="$seen$dir:" ;;
    esac
  done
  printf '%s' "$out"
}
export PATH="$(_dedup_path "$PATH")"
export MANPATH="$(_dedup_path "$MANPATH")"
export INFOPATH="$(_dedup_path "$INFOPATH")"
unset -f _dedup_path

# s - reload shell environment (re-source bash_profile + bashrc)
s() {
  local f
  local -a targets=(~/.bash_profile ~/.bashrc)
  local -a present=()
  for f in "${targets[@]}"; do
    [[ -r "$f" ]] && present+=("${f/#$HOME/~}")
  done
  for f in "${targets[@]}"; do
    [[ -r "$f" ]] && source "$f"
  done
  echo "sourced: ${present[*]}"
}
