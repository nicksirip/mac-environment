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

    # Zoxide (cached) — smarter cd: `z <dir>` jumps by frecency, `zi` interactive.
    # Placed AFTER starship (which overwrites PROMPT_COMMAND) so zoxide's dir-track
    # hook survives, mirroring the history -a append above. Skipped if zoxide
    # isn't installed (brew install zoxide).
    _cached_init zoxide zoxide zoxide init bash

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
# Runtime managers — guarded so a machine without them doesn't error.
# ─────────────────────────────────────────────────────────────────────────
# mise (runtime/version manager: brew install mise)
command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"
# Rust toolchain (rustup installs ~/.cargo/env)
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

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

# ==========================================
# 5. Generic Helpers
# ==========================================

# vi-style command-line editing (bash). Enables modal editing at the prompt.
set -o vi

# killport <port> [signal] — kill whatever process is bound to a TCP/UDP port.
#   Uses lsof to target the actual listener (not a command-line string match), so
#   it won't kill unrelated processes that merely mention the number. Prints the
#   PIDs it's about to kill first. Default signal TERM (graceful); pass a signal
#   name/number as the 2nd arg to override.
#   Usage: killport 8080        (SIGTERM)
#          killport 8080 9      (SIGKILL)  |  killport 8080 KILL
killport() {
    [ -z "$1" ] && { echo "usage: killport <port> [signal]" >&2; return 1; }
    local pids; pids=$(lsof -ti ":$1" 2>/dev/null)
    [ -z "$pids" ] && { echo "killport: nothing listening on port $1" >&2; return 1; }
    echo "killport: port $1 -> PID(s): $(echo "$pids" | tr '\n' ' ')" >&2
    # shellcheck disable=SC2086  # intentional word-split: optional signal flag + multiple PIDs as separate args
    kill ${2:+-$2} $pids
}

# watchconns [iface] — live outbound-connection watcher via tshark (plain output).
#   Shows outbound TCP SYNs, DNS queries, and TLS SNI (covers HTTPS over TCP AND
#   QUIC/HTTP3, since QUIC carries a TLS ClientHello). Straight tshark, no
#   post-processing — columns are tshark's own -T fields / -E output.
#   Fields: time | ip.dst | ipv6.dst | tcp.dstport | dns.qry.name | tls SNI
#   Default iface: en0.  Usage: watchconns  |  watchconns en1
#   Needs sudo (BPF capture) + tshark on PATH (brew install wireshark). Ctrl-C to stop.
watchconns() {
    local iface="${1:-en0}"
    command -v tshark >/dev/null 2>&1 || { echo "watchconns: tshark not found on PATH" >&2; return 1; }
    sudo tshark -i "$iface" -l -n -t ad \
        -Y "(tcp.flags.syn==1 && tcp.flags.ack==0) || dns.flags.response==0 || tls.handshake.type==1" \
        -T fields \
        -e frame.time -e ip.dst -e ipv6.dst -e tcp.dstport \
        -e dns.qry.name -e tls.handshake.extensions_server_name \
        -E header=y -E separator='  ' -E quote=n
}

# lint-shell - run shellcheck over the shell dotfiles + helper scripts in one pass.
# Dotfiles have no shebang so are linted as bash; in-file `# shellcheck disable=`
# directives are honored. SC1090/SC1091 (can't-follow-source) are excluded as noise.
# Install the linter first if missing:  brew install shellcheck
lint-shell() {
  if ! command -v shellcheck >/dev/null 2>&1; then
    echo "lint-shell: shellcheck not installed — run: brew install shellcheck" >&2
    return 1
  fi
  local rc=0 f
  local -a dotfiles=(~/.bash_profile ~/.bashrc ~/.zshrc ~/.profile)
  local -a scripts=(~/.tmux/scripts/*.sh)
  for f in "${dotfiles[@]}"; do
    [[ -r "$f" ]] || continue
    echo "== ${f/#$HOME/~} =="
    shellcheck -s bash -e SC1090,SC1091 "$f" || rc=1
  done
  for f in "${scripts[@]}"; do
    [[ -r "$f" ]] || continue
    echo "== ${f/#$HOME/~} =="
    shellcheck -e SC1090,SC1091 "$f" || rc=1
  done
  [[ $rc -eq 0 ]] && echo "lint-shell: clean" || echo "lint-shell: findings above"
  return $rc
}

# pw - small password helper on the macOS Keychain (`security` CLI).
#   pw <service>               Get password by exact service name
#   pw search <term>           Search entries by partial name
#   pw add <svc> <acct> <pw>   Add/update a secret
#   Note: `pw add` takes the secret as an argument, so it lands in shell history
#   unless the command is prefixed with a space (HISTCONTROL=ignorespace).
pw() {
  case "$1" in
    -l|search)
      # Search for entries by partial name
      security dump-keychain | grep -i "svce" | grep -i "$2" | sed 's/.*"svce"<blob>="//;s/"//'
      ;;
    -a|add)
      # Add/update a secret: pw add <service> <account> <password>
      if [[ -z "$2" || -z "$3" || -z "$4" ]]; then
        echo "Usage: pw add <service-name> <account> <password>"
        echo "Example: pw add my-service myuser 'S3cret!'"
        return 1
      fi
      security add-generic-password -s "$2" -a "$3" -w "$4" -U
      echo "✓ Saved: $2 ($3)"
      ;;
    -h|help)
      echo "pw <service>         Get password by exact service name"
      echo "pw search <term>     Search entries by partial name"
      echo "pw add <svc> <acct> <pw>  Add/update a secret"
      ;;
    *)
      # Get password by exact service name
      security find-generic-password -s "$1" -w 2>/dev/null || echo "Not found: $1 (try: pw search $1)"
      ;;
  esac
}

# penv / prun — pull secrets from `pass` into the environment.
# Secrets are read from `pass` on demand (first line of the entry) so nothing is
# hardcoded in dotfiles. Requires `pass` + a gpg key (pinentry prompts for the
# passphrase on first decrypt per agent-cache window).  brew install pass

# penv VAR pass/path   — export VAR=<secret> into THIS shell (persists for the session).
#   e.g.  penv GH_TOKEN github/token    ->  $GH_TOKEN is now set
penv() {
  if [ $# -ne 2 ]; then echo "usage: penv VAR pass/path" >&2; return 2; fi
  command -v pass >/dev/null 2>&1 || { echo "penv: pass not found" >&2; return 1; }
  local var="$1" path="$2" val
  case "$var" in [!A-Za-z_]*|*[!A-Za-z0-9_]*) echo "penv: '$var' is not a valid env var name" >&2; return 2;; esac
  val=$(pass show "$path" 2>/dev/null | head -n1)
  if [ -z "$val" ]; then echo "penv: '$path' not found in pass (or empty)" >&2; return 1; fi
  export "$var=$val"
  echo "penv: exported $var from pass:$path"
}

# prun VAR=pass/path [VAR2=pass/path2 ...] -- cmd [args...]
#   Runs cmd with the given vars injected ONLY into that command's environment —
#   never set in this shell, gone when cmd exits. Safer than penv for one-offs.
#   e.g.  prun GH_TOKEN=github/token -- gh repo list
prun() {
  command -v pass >/dev/null 2>&1 || { echo "prun: pass not found" >&2; return 1; }
  local -a envassign=()
  local sawsep=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --) sawsep=1; shift; break ;;
      *=*)
        local var="${1%%=*}" path="${1#*=}" val
        case "$var" in [!A-Za-z_]*|*[!A-Za-z0-9_]*) echo "prun: invalid var name '$var'" >&2; return 2;; esac
        val=$(pass show "$path" 2>/dev/null | head -n1)
        if [ -z "$val" ]; then echo "prun: '$path' not found in pass (or empty)" >&2; return 1; fi
        envassign+=("$var=$val")
        shift ;;
      *) echo "prun: expected VAR=pass/path before '--', got '$1'" >&2; return 2 ;;
    esac
  done
  if [ "$sawsep" -ne 1 ] || [ $# -eq 0 ]; then
    echo "usage: prun VAR=pass/path [VAR2=pass/path2 ...] -- cmd [args...]" >&2; return 2
  fi
  env "${envassign[@]}" "$@"
}

# ppick [--show] [query] — fuzzy-find a pass entry with fzf, then copy its
#   password to the clipboard via `pass -c` (auto-clears after
#   PASSWORD_STORE_CLIP_TIME, default 45s).
#   - The fzf preview pane shows the entry's NON-secret metadata only (lines
#     after line 1 — URL/username/notes), never the password, so a
#     screenshare/shoulder-surf of the picker doesn't leak the secret.
#   - Pass an initial [query] to pre-filter the list (forwarded to fzf).
#   - --show ALSO prints the password to the terminal (line 1) after copying,
#     for the cases where you need to read it; off by default.
#   e.g.  ppick                 -> pick, copy to clipboard (nothing printed)
#         ppick email           -> pre-filtered to entries matching 'email'
#         ppick --show github   -> copy AND print the password
ppick() {
  command -v pass >/dev/null 2>&1 || { echo "ppick: pass not found" >&2; return 1; }
  command -v fzf  >/dev/null 2>&1 || { echo "ppick: fzf not found"  >&2; return 1; }
  local show=0
  if [ "$1" = "--show" ]; then show=1; shift; fi
  local store="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
  [ -d "$store" ] || { echo "ppick: no pass store at $store" >&2; return 1; }
  local entry
  entry=$(
    cd "$store" 2>/dev/null \
      && find . -name '*.gpg' | sed 's|^\./||; s|\.gpg$||' | sort \
      | fzf --query="${1:-}" --select-1 --exit-0 --height=40% --reverse \
            --prompt='pass> ' \
            --preview 'pass show {} 2>/dev/null | tail -n +2' \
            --preview-window='down,30%,wrap'
  )
  [ -n "$entry" ] || { echo "ppick: no entry selected" >&2; return 1; }
  pass show -c "$entry" || { echo "ppick: failed to copy '$entry'" >&2; return 1; }
  echo "ppick: copied '$entry' to clipboard (clears in ${PASSWORD_STORE_CLIP_TIME:-45}s)"
  if [ "$show" -eq 1 ]; then
    printf 'ppick: %s = %s\n' "$entry" "$(pass show "$entry" 2>/dev/null | head -n1)"
  fi
}

# pass generate defaults. Tune `pass generate` so a bare
#   pass generate <name>
# yields an 8-char password from a safe, visually-unambiguous character set — no
# need to remember -n. These set the DEFAULT character set (used when -n is NOT
# given), so symbols are included but limited to shell/URL/CSV/JSON-safe ones.
#   - length default 8 (override per-call: `pass generate <name> 16`)
#   - dropped confusables: 0 1 2 5 6 8  and  B G I O S Z / b g l o s z
#   - symbols limited to - _ . = +  (no quoting/escaping/URL-encoding needed)
export PASSWORD_STORE_GENERATED_LENGTH=8
export PASSWORD_STORE_CHARACTER_SET='34679ACDEFHJKLMNPQRTUVWXYacdefhijkmnpqrtuvwxy-_.=+'
