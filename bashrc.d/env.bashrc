# ========================
#  ___ _ ___ __
# / -_) ' \ V /
# \___|_||_\_/
# (~/.bashrc.d/env.bashrc)
# ========================

# Path Settings, you can add your own path settings here,
# but please do not modify the main.bashrc file directly.
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$HOME/bin:$PATH"

#export EDITOR='vim'  # Change it to your favorite
export PAGER='less'
export MANPAGER='less -R'
export LESS='-R'     # Colorful less

# If using tty, set language to English, else set to Chinese
# (btw, you can change it to your language)
if [[ "$(tty 2>/dev/null)" == *tty* ]]; then
    LANG=en_US.UTF-8
else
    LANG=zh_CN.UTF-8
fi