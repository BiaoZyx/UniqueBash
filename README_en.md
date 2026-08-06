# UniqueBash

Chinese: [README.md](README.md)

## Overview
UniqueBash is an extensible collection of Bash configuration modules for general Linux distributions. It aims to provide an out-of-the-box, customizable shell experience. Modules include prompt, aliases, env, functions and more. Config files live in the `bashrc.d` directory.

This project evolved from the author's personal Bash setup used on development boards (e.g. Milk-V Duo S) and is now modularized for reuse. Feedback and contributions are welcome.

## Quick Start
```sh
./setup.sh
```
> Note: Backed up

## Repository Structure
- `main.bashrc`: Main entry that loads modules from `bashrc.d` and initializes the prompt.
- `bashrc.d/`: Modular directory; default files include:
  - `aliases.bashrc` — command aliases
  - `apps.bashrc` — app integrations (tmux, thefuck, etc.)
  - `env.bashrc` — environment variables (PATH, Homebrew mirrors, etc.)
  - `func.bashrc` — user functions
  - `memo.bashrc` — personal memos (optional)
  - `prompt.bashrc` — prompt styles and toggles (TTY/Powerline)
  - `interactive.startup` — settings only for interactive shells (key bindings, history behavior). Note: keybindings should be loaded only in interactive shells to avoid warnings or errors in non-interactive scripts.

## Extensibility Tips
- Put personal changes in new files inside `bashrc.d` to avoid modifying defaults and simplify upstream updates.
- Use a naming convention like `XX.local.bashrc` for machine/user-specific configuration and add them to `.gitignore`.

## Contributing
Please open issues or PRs; discuss major design changes in an issue first.

## License
See the `LICENSE` file at the repository root.

---

For the Chinese version, click the link at the top: [README.md](README.md)

## Keybindings Quick Reference
The following keybindings and readline settings are enabled for interactive shells (see `bashrc.d/interactive.startup`):

- `Ctrl-p`: Toggle prompt style (Powerline ↔ ASCII) via `__prompt_toggle_style`.
- `Alt + ↑`: History substring search backward (`history-substring-search-backward`).
- `Alt + ↓`: History substring search forward (`history-substring-search-forward`).
- `Tab`: Menu-based completion (`menu-complete`).
- `Shift + Tab`: Menu completion backward (`menu-complete-backward`).
- Additional readline/completion settings:
  - `skip-completed-text on` — avoid duplicated text during completion
  - `colored-stats on`, `visible-stats on` — show colored completion stats
  - `completion-ignore-case on` — case-insensitive completion
  - `show-all-if-ambiguous on`, `menu-complete-display-prefix on`
  - `mark-symlinked-directories on`, `match-hidden-files off`
  - `horizontal-scroll-mode on` — horizontal scroll for long commands

Note: these keybindings and settings apply only to interactive shells. To view or modify them, edit `bashrc.d/interactive.startup`.
