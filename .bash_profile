# /path/to/.bash_profile

# ==========================================
# 1. Bash Version Upgrade (macOS Compatibility)
# ==========================================
# Use Homebrew bash for interactive shells started under macOS bash 3.2.
# This keeps modern completion features working (bash-completion@2 needs bash >= 4.1).
# Skip re-exec inside VS Code/Electron processes and prevent re-exec loops.
_ppid_comm=$(ps -o comm= -p "$PPID" 2>/dev/null || true)

if (( BASH_VERSINFO[0] < 4 )) && [[ $- == *i* ]] \
        && [[ "${TERM_PROGRAM:-}" != "vscode" ]] \
        && [[ -z "${ELECTRON_RUN_AS_NODE:-}" ]] \
        && [[ "${_ppid_comm}" != *"node"* ]] \
        && [[ "${_ppid_comm}" != *"Electron"* ]] \
        && [[ "${_ppid_comm}" != *"Code Helper"* ]] \
        && [[ -x /opt/homebrew/bin/bash ]] \
        && [[ -z "${BASH_PROFILE_REEXEC:-}" ]]; then
    unset _ppid_comm
    export BASH_PROFILE_REEXEC=1
    exec -l /opt/homebrew/bin/bash
fi
unset _ppid_comm

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
export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"

# General Environment
export EDITOR=vi
export LC_ALL=C.UTF-8

# Ensure child processes (especially tmux panes) spawn with the current bash.
# tmux panes are non-login shells, so they do not read this file themselves.
export SHELL="${BASH}"

# ==========================================
# 3. History Settings
# ==========================================
HISTCONTROL=ignoredups:erasedups:ignorespace

# ==========================================
# 4. Interactive-Only Settings
# ==========================================
if [[ $- == *i* ]]; then

    # Signal traps
    trap INT
    trap HUP
    trap TERM

    # --- Completions ---
    # Source completion scripts if they exist
    [ -f ~/.brew-completion.bash ]   && . ~/.brew-completion.bash
    [ -f ~/.ssh-completion.bash ]    && . ~/.ssh-completion.bash
    [ -f ~/.podman-completion.bash ] && . ~/.podman-completion.bash

    # --- Tool Initialization ---

    # Load bash-preexec.sh (required by atuin and potentially others)
    if [[ -n "${HOMEBREW_PREFIX:-}" ]] && [[ -f "$HOMEBREW_PREFIX/etc/profile.d/bash-preexec.sh" ]]; then
        . "$HOMEBREW_PREFIX/etc/profile.d/bash-preexec.sh"
    fi

    # Atuin (requires bash-preexec)
    if command -v atuin &>/dev/null; then
        eval "$(atuin init bash)"
    fi

    # Fzf
    if command -v fzf &>/dev/null; then
        eval "$(fzf --bash)"
    fi

    # Keychain (SSH agent manager)
    if command -v keychain &>/dev/null; then
        eval "$(keychain --nolock --eval -q)"
    fi

    # Starship Prompt
    if command -v starship &>/dev/null; then
        eval "$(starship init bash)"
    fi

    # --- Session Management (Tmux) ---
    # Do not auto-enter tmux in VS Code integrated terminals.
    if [ -z "$TMUX" ] && [ "${TERM_PROGRAM:-}" != "vscode" ]; then
        # Avoid locale issues in tmux unless explicitly set later.
        env -u LC_ALL tmux new -t default || env -u LC_ALL tmux new -s default
    fi

fi # end interactive-only settings