# Re-exec with Homebrew bash when running under the macOS system bash (3.2)
# in an interactive session. bash-completion@2 requires bash >= 4.1; without
# this, tab completions that rely on _get_comp_words_by_ref (e.g. podman) will
# not work correctly. The interactive check avoids re-exec for non-interactive
# shells (e.g. VS Code extensions) where exec -l can cause unexpected failures.
# BASH_PROFILE_REEXEC guards against infinite loops if the Homebrew bash is
# somehow also older than version 4.
if (( BASH_VERSINFO[0] < 4 )) && [[ $- == *i* ]] && [[ -x /opt/homebrew/bin/bash ]] \
        && [[ -z "${BASH_PROFILE_REEXEC:-}" ]]; then
    export BASH_PROFILE_REEXEC=1
    exec -l /opt/homebrew/bin/bash
fi

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

