# UniqueBash

Chinese: [README.md](README.md)

## Overview
UniqueBash is an extensible collection of Bash configuration modules for general Linux distributions. It aims to provide an out-of-the-box, customizable shell experience. Modules include prompt, aliases, env, functions and more. Config files live in the `bashrc.d` directory.

This project evolved from the author's personal Bash setup used on development boards (e.g. Milk-V Duo S) and is now modularized for reuse. Feedback and contributions are welcome.

## Features
- **Modular**: every setting lives in its own file under `bashrc.d/`, decoupled and easy to replace or extend.
- **Dual prompt styles**: Powerline (colored arrows) and 8-color ASCII, switchable at runtime with `Ctrl-p`; defaults to ASCII on TTY.
- **Git status**: branch, staged/unstaged/untracked counts, conflicts, and ahead/behind commits, with a 3-second cache (skips `git` when the directory is unchanged).
- **Pipeline error display**: any failed segment is shown in red — e.g. `true | false | true` prints `✕0|1|0` instead of only the last exit code.
- **Smart completion**: Tab cycling, substring history search (`Alt+↑/↓`), case-insensitive matching, on-demand hidden-file completion, and more.
- **Directory-stack `cd`**: `cd +n` / `cd -n` jump through the directory stack; bare numbers are tried as stack indices.
- **Command-not-found hints**: friendly, multi-language (zh/en/es) messages, or a "did you mean XXX?" suggestion.
- **App integration**: auto-wires `thefuck`, `memo`, etc. when available.

## Quick Start
```sh
./setup.sh
```
> Note: existing `~/.bashrc` and `~/.bash_profile` are backed up automatically.

## Install Options
```sh
./setup.sh                 # normal install (auto backup)
./setup.sh --force         # overwrite without backup
./setup.sh --preview       # show what would change, write nothing
./setup.sh --tui           # pick modules with a TUI (dialog / fzf)
./setup.sh --update        # refresh ~/.bashrc.d from repo defaults (backup, skip *.local.*)
./setup.sh --uninstall     # restore from backups and remove default modules
./setup.sh --help          # show help
./setup.sh --version       # show version
```

Default behavior:
1. Back up `~/.bashrc` to `~/.bashrc.bak.<timestamp>` and symlink it to this repo's `main.bashrc`.
2. Back up `~/.bash_profile` to `~/.bash_profile.bak.<timestamp>` and symlink it to `startup.bash_profile`.
3. Copy `bashrc.d/*` into `~/.bashrc.d/` (existing files are backed up first).

> **Updating (keeps your edits)**: `--update` uses a 3-way diff-merge (your version / base version / upstream version). The rules:
> - **Repo added a new file**: installed into your `~/.bashrc.d/`; your existing files are untouched.
> - **You didn't edit a file, but the repo did**: updated directly to the upstream version.
> - **You and the repo edited different parts of the same file**: `git merge-file` merges automatically — **your edits are kept and the repo's additions are also applied**.
> - **You and the repo edited the same line (real conflict)**: your working version is kept (so the shell keeps working), and the conflicting merge result with `<<<<<<<` markers is written to `~/.bashrc.d/.merged_<file>` for you to resolve manually; your previous version is backed up to `~/.bashrc.d/.backups/`.
> - **`*.local.*` files**: always skipped — no merge happens at all (they are your fully private config).
>
> Your version is backed up to `~/.bashrc.d/.backups/` before merging. Day-to-day updates can simply use `ub-update` (see below).
> **Uninstalling**: `--uninstall` restores `~/.bashrc` / `~/.bash_profile` from the install-time backups and removes the default modules installed by this project (restoring your edited version if you had one), keeping `*.local.*` files.

## Update Tools (in interactive shells)
After installing/updating, `func.bashrc` provides:
- `ub-update` — same as `./setup.sh --update` (auto-locates the repo).
- `ub-status` — show loaded module count, last update time, and any merge conflicts.
- `ub-diff` — show per-file diffs between your `~/.bashrc.d/` and the upstream repo.

## Repository Structure
- `main.bashrc`: main entry (the loader for `~/.bashrc`); it loads `interactive.startup` and the `bashrc.d` modules. **The prompt implementation (colors, Git parsing, rendering) has been moved into `bashrc.d/prompt.bashrc`** for easier maintenance.
- `startup.bash_profile`: login-shell startup file chaining `/etc/profile`, `/etc/bashrc`, and this config.
- `bashrc.d/`: module directory; default files include:
  - `aliases.bashrc` — command aliases (auto-detects `eza` / GNU `ls` / BSD `ls`)
  - `apps.bashrc` — app integrations (e.g. `thefuck`)
  - `env.bashrc` — environment variables (PATH, pager, locale-aware language)
  - `func.bashrc` — user functions (`mkcd`, `command_not_found_handle`, etc.)
  - `interactive.startup` — interactive-only settings (history, completion, key bindings, `PROMPT_COMMAND`)
  - `memo.bashrc` — personal memos (if `~/.memo` exists)
  - `prompt.bashrc` — prompt core (colors, Git status parsing, Powerline/ASCII rendering and style toggle)

## Keybindings Quick Reference
The following keybindings and readline settings are enabled for interactive shells (see `bashrc.d/interactive.startup`):

| Key | Function |
| --- | --- |
| `Ctrl-p` | Toggle prompt style (Powerline ↔ ASCII) |
| `Alt + ↑` | History substring search backward |
| `Alt + ↓` | History substring search forward |
| `Tab` | Menu-based completion (`menu-complete`) |
| `Shift + Tab` | Menu completion backward (`menu-complete-backward`) |
| `cd +n` / `cd -n` | Directory-stack jump |

Additional readline/completion settings: `skip-completed-text on`, `colored-stats on`, `visible-stats on`, `completion-ignore-case on`, `show-all-if-ambiguous on`, `menu-complete-display-prefix on`, `mark-symlinked-directories on`, `match-hidden-files off`, `horizontal-scroll-mode on`.

Note: these keybindings and settings apply only to interactive shells. To view or modify them, edit `bashrc.d/interactive.startup`.

## Extensibility Tips
- Put personal changes in new files inside `bashrc.d` to avoid modifying defaults and simplify upstream updates.
- Use a naming convention like `XX.local.bashrc` for machine/user-specific configuration and add them to `.gitignore`.
- To upgrade default modules run `./setup.sh --update`; to fully remove run `./setup.sh --uninstall`.

## Development & Linting
- A `.shellcheckrc` is provided at the repo root. Run:
  ```sh
  shellcheck setup.sh main.bashrc bashrc.d/*.bashrc bashrc.d/interactive.startup
  ```
- After editing, verify syntax with `bash -n <file>`.

## Contributing
Please open issues or PRs; discuss major design changes in an issue first.

## License
See the `LICENSE` file at the repository root.

---

For the Chinese version, click the link at the top: [README.md](README.md)
