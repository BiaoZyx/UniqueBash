# ==================================
#  __  __
# |  \/  |___ _ __  ___
# | |\/| / -_) '  \/ _ \
# |_|  |_\___|_|_|_\___/
#          (~/.bashrc.d/memo.bashrc)
# ==================================

if [ -f "$HOME/.memo" ]; then
    if command -v lolcat &>/dev/null; then
        alias memo='lolcat "$HOME/.memo"'
    else
        alias memo='cat "$HOME/.memo"'
    fi
else
    alias memo='echo "Memo file not found: ~/.memo"'
fi
