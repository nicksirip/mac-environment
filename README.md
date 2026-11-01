# environment
This is my MBP setup.

## Shell Requirement: Bash ≥ 4

macOS ships with **bash 3.2** (GNU bash, version 3.2.x), which is too old for `bash-completion@2` and the tab-completion scripts in this repository.  `bash-completion@2` requires **bash ≥ 4.1**; without it, helpers such as `_get_comp_words_by_ref` are never defined and completions (e.g. `podman <TAB>`) fail.

### Fix: install and use Homebrew bash

```bash
brew install bash
```

Once installed, `.bash_profile` will automatically re-exec itself with `/opt/homebrew/bin/bash` whenever it detects that the current shell is older than version 4.  All subsequent profiles and completions will therefore run under a modern bash.

To make Homebrew bash your permanent login shell (optional, but recommended):

```bash
# Add the Homebrew bash to the list of allowed shells
echo /opt/homebrew/bin/bash | sudo tee -a /etc/shells

# Set it as your default login shell
chsh -s /opt/homebrew/bin/bash
```

## Brew Command Autocompletion

This repository includes Homebrew (`brew`) tab autocomplete support for Bash, powered by the completion scripts that ship with Homebrew itself.

### Features

- **Subcommand completion**: Press TAB after `brew ` to see all available subcommands (`install`, `uninstall`, `upgrade`, `search`, etc.)
- **Formula & cask completion**: Press TAB after `brew install ` to autocomplete package names
- **Option completion**: Flags and options for each subcommand are also tab-completable
- **Automatic detection**: Resolves the Homebrew prefix from `$HOMEBREW_PREFIX` or `brew --prefix`

### Installation

Brew autocompletion is automatically enabled when you source the `.bash_profile`:

```bash
source ~/.bash_profile
```

Or manually source the completion script:

```bash
source ~/.brew-completion.bash
```

### Usage

```bash
brew <TAB>
# Shows: install uninstall upgrade search info list ...

brew install <TAB>
# Shows available formulae matching what you've typed

brew install wget<TAB>
# Autocompletes to: brew install wget
```

### Requirements

- [Homebrew](https://brew.sh) must be installed
- For the best experience, install `bash-completion@2` via Homebrew (`brew install bash-completion@2`). Without it, the script falls back to sourcing individual completion files from `bash_completion.d`, which may provide partial or no completion support depending on your Homebrew version.

---

## SSH Hostname Autocompletion

This repository includes an intelligent SSH hostname autocompletion feature that extracts hostnames from your SSH configuration files and enables tab completion in Bash.

### Features

- **Automatic hostname extraction**: Parses `~/.ssh/config` and `/etc/ssh/ssh_config` to find all configured hosts
- **Intelligent filtering**: Automatically filters out wildcard patterns (*, ?, [])
- **Deduplication**: Ensures each hostname appears only once in completion suggestions
- **Robust error handling**: Gracefully handles missing, empty, or malformed config files
- **Easy customization**: Easily extend to parse additional config file locations

### Installation

The SSH autocompletion is automatically enabled when you source the `.bash_profile`:

```bash
source ~/.bash_profile
```

Or manually source the completion script:

```bash
source ~/.ssh-completion.bash
```

### Usage

Once installed, simply type `ssh` followed by a space and press `TAB` to see all available hostnames:

```bash
ssh <TAB>
# Shows: host1 host2 host3 ...

ssh web<TAB>
# Autocompletes to: ssh webserver
```

### Customization

To parse additional SSH config files, edit `.ssh-completion.bash` and modify the `SSH_CONFIG_FILES` array:

```bash
declare -a SSH_CONFIG_FILES=(
    "$HOME/.ssh/config"
    "/etc/ssh/ssh_config"
    "$HOME/.ssh/custom_config"  # Add your custom config here
)
```

You can also enable autocompletion for related SSH commands by uncommenting these lines in `.ssh-completion.bash`:

```bash
complete -F _ssh_hostname_completion scp
complete -F _ssh_hostname_completion sftp
complete -F _ssh_hostname_completion ssh-copy-id
```

### How It Works

The completion script:
1. Parses SSH config files for `Host` directives (case-insensitive)
2. Extracts hostname entries, filtering out wildcards and patterns
3. Deduplicates hostnames while maintaining order of appearance
4. Integrates with Bash's programmable completion system via `complete` and `compgen`

### Limitations

- Does not expand wildcards or patterns in Host directives
- Does not parse Match blocks or conditional configurations
- Does not follow Include directives (OpenSSH 7.3+)

### Example SSH Config

```
# ~/.ssh/config
Host webserver
    HostName web.example.com
    User admin

Host db-prod
    HostName db.prod.example.com
    User root

Host dev-*
    HostName dev.example.com
    # This wildcard entry won't appear in completions
```

With this config, typing `ssh <TAB>` will suggest: `webserver` and `db-prod` (but not `dev-*`).

---

## Podman Command Autocompletion

Tab completion for `podman` is provided by `.podman-completion.bash`, which is sourced automatically from `.bash_profile`.

### Installation

```bash
source ~/.bash_profile
```

Or manually:

```bash
source ~/.podman-completion.bash
```

### Usage

```bash
podman <TAB>
# Shows: run pull push ps images ...

podman run <TAB>
# Shows available options and flags
```

### Requirements

- [Podman](https://podman.io) must be installed (`brew install podman`)
- Bash ≥ 4.1 is required (see [Shell Requirement](#shell-requirement-bash--4) above); `podman` completion relies on `_get_comp_words_by_ref` from `bash-completion@2`

---

## fzf (Fuzzy Finder)

[fzf](https://github.com/junegunn/fzf) provides interactive fuzzy search for files, command history, and more. When `fzf` is found in `PATH`, `.bash_profile` initialises it with `fzf --bash`, which sets up both tab-completions and key-bindings in a single call. The init output is cached in `~/.cache/bash-init/` (by the `_cached_init` helper) and regenerated only when the `fzf` binary is newer than the cache, so new shells and tmux panes don't spawn `fzf` every time.

### Installation

```bash
brew install fzf
```

No additional configuration is needed; `.bash_profile` detects `fzf` automatically.

### Key Bindings (enabled automatically)

| Key | Action |
|-----|--------|
| `Ctrl-R` | Fuzzy-search command history |
| `Ctrl-T` | Fuzzy-search files and paste selection |
| `Alt-C`  | `cd` into a fuzzy-selected directory |

### Usage

```bash
vim **<TAB>
# Opens fzf to fuzzy-select a file path

ssh **<TAB>
# Opens fzf to fuzzy-select an SSH host
```

---

## Shell History

History is configured in the interactive block of `.bash_profile`. It's tuned so tmux panes share history in near real time without paying a per-prompt cost:

| Setting | Effect |
|---|---|
| `HISTSIZE=50000`, `HISTFILESIZE=50000` | Keep 50k commands in memory and on disk |
| `HISTCONTROL=ignoredups:ignorespace` | Skip consecutive duplicates and any command prefixed with a space (handy for one-off secrets) |
| `shopt -s histappend` | Append to `~/.bash_history` on exit instead of overwriting, so concurrent shells don't clobber each other |
| `history -a` in `PROMPT_COMMAND` | Flush each command to disk as it runs, so new panes see it immediately. Appended *after* Starship init, because Starship overwrites `PROMPT_COMMAND` |

`erasedups` is deliberately not used: at 50k entries it rescans the whole list on every command. `Ctrl-R` history search is provided by fzf (above).

---

## Keychain (SSH Key Management)

[Keychain](https://www.funtoo.org/Keychain) manages `ssh-agent` across login sessions so you only need to enter your passphrase once per boot. `.bash_profile` runs `keychain --nolock --eval -q` when `keychain` is found in `PATH`.

### Installation

```bash
brew install keychain
```

No additional configuration is required; keys are picked up from your default SSH key locations.

---

## Starship Prompt

[Starship](https://starship.rs) is a fast, cross-shell prompt. When `starship` is found in `PATH`, `.bash_profile` caches the output of `starship init bash --print-full-init` (the full init, not the one-line bootstrap, so the subprocess is actually saved) via `_cached_init`.

### Installation

```bash
brew install starship
```

Customise the prompt by editing `~/.config/starship.toml`. See the [Starship docs](https://starship.rs/config/) for all available options.

---

## tmux Session Management

`.bash_profile` automatically puts every interactive shell into tmux when it's opened outside of tmux:

- **A tmux server is already running** → opens a *grouped* session on the newest existing session (`tmux new-session -t <session>`). It shares the same windows but keeps its own current-window selection, so each terminal can look at a different window without moving the others. The grouped session is set to `destroy-unattached`, so it's cleaned up when you detach.
- **No server yet** → creates a session named `default`.

It's skipped in VS Code integrated terminals, and you can skip it for a single shell with `NO_TMUX=1` (e.g. `NO_TMUX=1 bash -l`). tmux is launched under `env -u LANG` so tmux applies its own locale handling.

```bash
# Simplified view of the launch block in .bash_profile:
if [ -z "$TMUX" ] && [ "${TERM_PROGRAM:-}" != "vscode" ] && [ -z "${NO_TMUX:-}" ]; then
    if env -u LANG tmux has-session 2>/dev/null; then
        target=$(env -u LANG tmux list-sessions -F '#{session_name}' | head -1)
        env -u LANG tmux new-session -t "$target" \; set-option destroy-unattached on
    else
        env -u LANG tmux new-session -s default
    fi
fi
```

### Installation

```bash
brew install tmux
```

See `.tmux.conf` in this repository for the tmux configuration used with this setup. It passes OSC 8 hyperlinks through to the terminal (`terminal-features …:hyperlinks`, tmux 3.4+), so clickable links from programs like `ls --hyperlink` keep working inside tmux. That setting only takes effect after `tmux kill-server`; reloading the config isn't enough.

---

## Ghostty (Terminal)

[Ghostty](https://ghostty.org) config lives at `.config/ghostty/config.ghostty`. Copy it to `~/.config/ghostty/config.ghostty`; Ghostty loads that path automatically (`$XDG_CONFIG_HOME/ghostty/config.ghostty`), and a file named plain `config` there is **not** picked up.

Highlights:
- **Appearance:** iTerm2 Default theme, Inconsolata Nerd Font Mono 16, 90% background opacity, Display P3, non-blinking cursor.
- **Window:** native macOS tabs in the titlebar; new windows always open at 120×30 (`window-save-state = never` so the size isn't overridden by a restored window); new tabs/splits inherit the working directory.
- **Clipboard:** copy-on-select, trailing whitespace trimmed on copy, paste protection for risky multi-line pastes.
- **Quick terminal:** global hotkey `Ctrl+Option+/` slides a terminal in from the right edge at 60% of the screen width. The global hotkey needs Accessibility permission (System Settings → Privacy & Security → Accessibility → Ghostty).

Check the config parses after editing:

```bash
/Applications/Ghostty.app/Contents/MacOS/ghostty +show-config
```

Most settings apply on config reload (`Cmd+Shift+,`); changing `quick-terminal-position` needs a full quit and relaunch of Ghostty.

---

## AeroSpace (Tiling Window Manager)

[AeroSpace](https://github.com/nikitabobko/AeroSpace) is an i3-like tiling window manager. Config lives at `.config/aerospace/aerospace.toml`; copy it (and `layouts/`) to `~/.config/aerospace/`. AeroSpace also reads `~/.aerospace.toml`, and reports an error if **both** exist, so keep only one.

```bash
brew install --cask nikitabobko/tap/aerospace
aerospace reload-config --dry-run   # validate the active config
```

The config sets `start-at-login` and `auto-reload-config`, so edits apply on save after one manual reload (`alt-shift-c`).

Key bindings (modifier = `alt`/Option):

| Keys | Action |
|---|---|
| `alt-h/j/k/l` | Focus left/down/up/right |
| `alt-shift-h/j/k/l` | Move window |
| `alt-ctrl-h/j/k/l` | Join window into the neighbor's container |
| `alt-1..9` / `alt-shift-1..9` | Go to workspace / move window there (and follow) |
| `alt-u` / `alt-i` | Previous / next workspace (wraps) |
| `alt-tab` | Back to the previous workspace |
| `alt-enter` | New Ghostty window, split below the focused one |
| `alt-slash` / `alt-comma` | Toggle split orientation / accordion |
| `alt-f` | Fullscreen |
| `alt-minus` / `alt-equal` | Shrink / grow |
| `alt-shift-c` | Reload config |
| `alt-shift-;` | Service mode: `r` reset tree, `f` toggle floating, `backspace` close others, `1` run `layouts/ws1.sh`, `esc` back |

App rules send Ghostty and Chrome to workspace 1, VS Code / Kiro / Obsidian to 2, Slack to 3, Outlook to 4, Zoom to 6; any other window floats. `layouts/ws1.sh` rebuilds workspace 1 as Chrome on the left with two Ghostty windows stacked on the right. AeroSpace has no built-in layout save/restore.

---

## Zoxide (Smarter `cd`)

[zoxide](https://github.com/ajeetdsouza/zoxide) learns the directories you use and jumps by frecency. Initialized (and cached) in the interactive block of `.bash_profile`, after Starship so its directory-tracking hook survives. Skipped automatically if not installed.

```bash
brew install zoxide
z proj        # jump to the best match for "proj"
zi            # interactive picker (uses fzf)
```

---

## Shell Helpers

Defined in `.bash_profile` (section 5). Each checks for its dependency and prints a hint if it's missing.

| Helper | What it does | Needs |
|---|---|---|
| `killport <port> [signal]` | Kill whatever is listening on a port (targets the listener via `lsof`, not a string match) | built-in `lsof` |
| `watchconns [iface]` | Live view of outbound TCP SYNs, DNS queries, and TLS SNI | `brew install wireshark` (tshark), sudo |
| `lint-shell` | Run shellcheck over the shell dotfiles and `~/.tmux/scripts/*.sh` | `brew install shellcheck` |
| `pw <service>` / `pw search` / `pw add` | Small macOS Keychain password helper | built-in `security` |
| `penv VAR pass/path` | Export a secret from `pass` into the current shell | `brew install pass` + a gpg key |
| `prun VAR=pass/path -- cmd` | Inject a secret into one command's environment only (never set in the shell) | `pass` |
| `ppick [--show] [query]` | Fuzzy-pick a `pass` entry and copy it to the clipboard; preview shows only non-secret metadata | `pass`, `fzf` |

Also set in section 5:
- `set -o vi`: vi-style command-line editing.
- `PASSWORD_STORE_GENERATED_LENGTH` / `PASSWORD_STORE_CHARACTER_SET`: `pass generate <name>` defaults to 8 characters from an unambiguous, shell/URL-safe set.

`mise` (`brew install mise`) and the Rust toolchain (`~/.cargo/env`) are activated just before the PATH de-duplication, only if present.
