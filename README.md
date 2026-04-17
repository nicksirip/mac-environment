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

[fzf](https://github.com/junegunn/fzf) provides interactive fuzzy search for files, command history, and more. When `fzf` is found in `PATH`, `.bash_profile` initialises it with `fzf --bash`, which sets up both tab-completions and key-bindings in a single call.

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

## Atuin (Shell History)

[Atuin](https://atuin.sh) replaces shell history with a searchable, syncable SQLite database. `.bash_profile` initialises it via `atuin init bash` when `atuin` is found in `PATH`, and loads the required `bash-preexec` hook from Homebrew beforehand.

### Installation

```bash
brew install atuin bash-preexec
```

### Usage

Press `Ctrl-R` to open the Atuin interactive history search (replaces the default readline reverse-search when Atuin is active).

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

[Starship](https://starship.rs) is a fast, cross-shell prompt. `.bash_profile` initialises it with `starship init bash` when `starship` is found in `PATH`.

### Installation

```bash
brew install starship
```

Customise the prompt by editing `~/.config/starship.toml`. See the [Starship docs](https://starship.rs/config/) for all available options.

---

## tmux Session Management

`.bash_profile` automatically attaches to (or creates) a persistent tmux session named `default` whenever you open an interactive shell outside of tmux. This ensures you always land in a tmux session with a consistent environment.

```bash
# In .bash_profile:
if [ -z "$TMUX" ]; then
    unset LC_ALL
    tmux new -t default || tmux new -s default
fi
```

`LC_ALL` is unset before handing off to tmux so that the locale is inherited correctly by tmux panes (tmux has its own locale handling).

### Installation

```bash
brew install tmux
```

See `.tmux.conf` in this repository for the tmux configuration used with this setup.
