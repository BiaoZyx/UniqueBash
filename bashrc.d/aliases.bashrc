# ======================================
#    _   _ _
#   /_\ | (_)__ _ ___ ___ ___
#  / _ \| | / _` (_-</ -_|_-<
# /_/ \_\_|_\__,_/__/\___/__/
#           (~/.bashrc.d/aliases.bashrc)
# ======================================

## ls command alias
# If `eza` is installed, use it with icons; otherwise, use cross-platform `ls` with color.
if command -v eza &> /dev/null; then
    export EZA_ICONS_AUTO=1
    alias ls='eza'
    alias l='ls -lA'  # Default `l`
else
    # GNU/Linux: --color=auto, macOS/BSD: -G
    alias ls='ls --color=auto 2>/dev/null || ls -G'
    alias l='ls -lAh' # Default `l`
fi

# Long listing with all files and classification symbols
alias ll='ls -alF'

# Almost all files (excluding . and ..), with color if available
alias la='ls -A'

# Directory navigation shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'

# Colorize grep and ip output
alias grep='grep --color=auto'
alias ip='ip --color=auto'

# Safety aliases (confirm before overwrite/delete)
#alias cp='cp -i'
#alias mv='mv -i'
# rm uses -i in Bash; if you ever use ash, it would need -I, but this is Bash-specific
#alias rm='rm -i'

# Clear screen shortcut
alias cls='clear'
