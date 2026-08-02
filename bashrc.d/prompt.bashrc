#=================================
#                         _
# _ __ _ _ ___ _ __  _ __| |_
#| '_ \ '_/ _ \ '  \| '_ \  _|
#| .__/_| \___/_|_|_| .__/\__|
#|_|                |_|
#      (~/.bashrc.d/prompt.bashrc)
# ================================

# If using tty, set prompt style to 1, else set to 2
if [[ "$(tty 2>/dev/null)" == *tty* ]]; then
    PROMPT_STYLE=1
else
    PROMPT_STYLE=2
fi

# Cover it
PROMPT_STYLE=1