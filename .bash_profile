# Re-exec with Homebrew bash when running under the macOS system bash (3.2).
# bash-completion@2 requires bash >= 4.1; without this, tab completions that
# rely on _get_comp_words_by_ref (e.g. podman) will not work correctly.
# Guards:
#   $- == *i*            – only re-exec for interactive shells
#   TERM_PROGRAM         – skip in VS Code integrated terminal (sets TERM_PROGRAM=vscode)
#   _ppid_comm           – skip when the parent process is node or Electron (the
#                          VS Code extension host); this catches all extension-
#                          spawned shells (e.g. Container Tools) regardless of
#                          which environment variables they do or do not inherit
#   BASH_PROFILE_REEXEC  – prevent infinite loops
_ppid_comm=$(ps -o comm= -p "$PPID" 2>/dev/null || true)
if (( BASH_VERSINFO[0] < 4 )) && [[ $- == *i* ]] \
        && [[ "${TERM_PROGRAM:-}" != "vscode" ]] \
        && [[ "${_ppid_comm}" != "node" && "${_ppid_comm}" != "Electron" ]] \
        && [[ -x /opt/homebrew/bin/bash ]] \
        && [[ -z "${BASH_PROFILE_REEXEC:-}" ]]; then
    unset _ppid_comm
    export BASH_PROFILE_REEXEC=1
    exec -l /opt/homebrew/bin/bash
fi
unset _ppid_comm

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

if [ -f /usr/share/bash-completion/completions/fzf ]; then
    . /usr/share/bash-completion/completions/fzf
fi

if [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
    . /usr/share/doc/fzf/examples/key-bindings.bash
fi

# Tools
if [ -f /usr/share/bash-completion/completions/fzf ]; then
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

