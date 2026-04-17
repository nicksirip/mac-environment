# Re-exec with Homebrew bash when running under the macOS system bash (3.2).
# bash-completion@2 requires bash >= 4.1; without this, tab completions that
# rely on _get_comp_words_by_ref (e.g. podman) will not work correctly.
# Guards:
#   $- == *i*               – only re-exec for interactive shells
#   TERM_PROGRAM            – skip in VS Code integrated terminal (sets TERM_PROGRAM=vscode)
#   ELECTRON_RUN_AS_NODE    – skip when running inside any Electron/VS Code subprocess;
#                             VS Code sets ELECTRON_RUN_AS_NODE=1 on Code Helper processes
#                             and it is inherited by all descendants (including shells
#                             spawned via /bin/sh intermediaries)
#   _ppid_comm              – secondary guard: skip when the immediate parent comm
#                             contains "node", "Electron", or "Code Helper" (substring
#                             match handles both bare names and full macOS binary paths)
#   BASH_PROFILE_REEXEC     – prevent infinite loops within a single re-exec chain;
#                             unset below so tmux child shells can re-exec independently
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
# Clear the re-exec flag (belt-and-suspenders for login-shell descendants).
unset BASH_PROFILE_REEXEC
# Update $SHELL to the running bash so every program that inherits the
# environment — most importantly tmux, which uses $SHELL to spawn pane
# shells — gets Homebrew bash rather than the macOS system bash 3.2.
# tmux panes are non-login shells and never source .bash_profile, so the
# re-exec block above cannot help them; updating $SHELL here is the only
# reliable way to ensure they start under the correct bash.
export SHELL="${BASH}"

# Homebrew
export HOMEBREW_PREFIX="/opt/homebrew";
export HOMEBREW_CELLAR="/opt/homebrew/Cellar";
export HOMEBREW_REPOSITORY="/opt/homebrew";
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin${PATH+:$PATH}";
export MANPATH="/opt/homebrew/share/man${MANPATH+:$MANPATH}:";
export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}";

# Environment
export EDITOR=vi
export LC_ALL=C.UTF-8

# History
HISTCONTROL=ignoredups:erasedups:ignorespace

# Interactive-only settings
if [[ $- == *i* ]]; then

# Signal traps
trap INT
trap HUP
trap TERM

# Completions
if [ -f ~/.brew-completion.bash ]; then
    . ~/.brew-completion.bash
fi

if [ -f ~/.ssh-completion.bash ]; then
    . ~/.ssh-completion.bash
fi

if [ -f ~/.podman-completion.bash ]; then
    . ~/.podman-completion.bash
fi

# Tools
if command -v atuin &>/dev/null; then
    [[ -n "${HOMEBREW_PREFIX:-}" ]] && [[ -f "$HOMEBREW_PREFIX/etc/profile.d/bash-preexec.sh" ]] && . "$HOMEBREW_PREFIX/etc/profile.d/bash-preexec.sh"
    eval "$(atuin init bash)"
fi

if command -v fzf &>/dev/null; then
    eval "$(fzf --bash)"
fi

if command -v keychain &>/dev/null; then
    eval "$(keychain --nolock --eval -q)"
fi

if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi

# Session
if [ -z "$TMUX" ]; then
    unset LC_ALL
    tmux new -t default || tmux new -s default
fi

fi # end interactive-only settings

