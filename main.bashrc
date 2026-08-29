#!/bin/bash
# =======================================================
#    __  __      _                  ____             __
#   / / / /___  (_)___ ___  _____  / __ )____ ______/ /_
#  / / / / __ \/ / __ `/ / / / _ \/ __  / __ `/ ___/ __ \
# / /_/ / / / / / /_/ / /_/ /  __/ /_/ / /_/ (__  ) / / /
# \____/_/ /_/_/\__, /\__,_/\___/_____/\__,_/____/_/ /_/
#                 /_/
# =======================================================
# Version      : 3.4
# Updated-time : 2026-8-4
# Auther       : BiaoZyx
# Email        : BiaoZyx@outlook.com
# =======================================================
#  __  __      _
# |  \/  |__ _(_)_ _
# | |\/| / _` | | ' \
# |_|  |_\__,_|_|_||_|
#              (~/.bashrc)
# =======================================================

# ------------------------------
# Core Settings
# ------------------------------
# Setup for interactive shell
if [[ $- == *i* ]]; then
  . $HOME/.bashrc.d/interactive.startup
fi

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*.bashrc; do
    if [ -f "$rc" ]; then
      . "$rc"
    fi
  done
fi
unset rc

# Completions in Interactive Shell
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# User's Configs
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# ------------------------------
# Prompt Settings
# ------------------------------
# Prompt colors, git status parsing and prompt builders live in
# bashrc.d/prompt.bashrc (loaded above via the *.bashrc glob).
