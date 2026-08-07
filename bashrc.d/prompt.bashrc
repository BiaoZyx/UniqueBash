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
    PROMPT_STYLE=2
else
    PROMPT_STYLE=1
fi

export SHOW_USER_HOST=0  # 1 to show user@host in prompt, 0 to hide

# Flyline - enhanced Bash experience
if [[ -f "$HOME/.local/lib/libflyline.so" ]]; then
    enable -f "$HOME/.local/lib/libflyline.so" flyline
fi