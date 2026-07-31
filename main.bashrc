#!/bin/bash
# =======================================================
#    __  __      _                  ____             __
#   / / / /___  (_)___ ___  _____  / __ )____ ______/ /_
#  / / / / __ \/ / __ `/ / / / _ \/ __  / __ `/ ___/ __ \
# / /_/ / / / / / /_/ / /_/ /  __/ /_/ / /_/ (__  ) / / /
# \____/_/ /_/_/\__, /\__,_/\___/_____/\__,_/____/_/ /_/
#                 /_/
# =======================================================
# Version      : 3.2
# Updated-time : 2026-7-31
# Auther       : BiaoZyx
# Email        : BiaoZyx@outlook.com
# =======================================================
#  __  __      _
# |  \/  |__ _(_)_ _
# | |\/| / _` | | ' \
# |_|  |_\__,_|_|_||_|
#                (~/.bashrc)
# =======================================================

# ------------------------------
# Core Settings
# ------------------------------
# Load Global Configs
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# User's Configs
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
  PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*; do
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

# ------------------------------
# Prompt Settings
# ------------------------------
# The Powerline-like Prompt

# Colors Definitions
R='\[\033[0m\]'     # Reset
BR='\[\033[30m\]'   # Black - Regular
BB='\[\033[1;30m\]' # Black - Bold
if false; then      # - Unused colors -
R1='\[\033[1;31m\]' # Red
G1='\[\033[1;32m\]' # Green
Y1='\[\033[1;33m\]' # Yellow
B1='\[\033[1;34m\]' # Blue
M1='\[\033[1;35m\]' # Magenta
C1='\[\033[1;36m\]' # Cyan
fi

W1='\[\033[1;37m\]' # White

# Dark Colors Definitions
dR1='\[\033[0;31m\]' # Dark Red
dG1='\[\033[0;32m\]' # Dark Green
dY1='\[\033[0;33m\]' # Dark Yellow
dB1='\[\033[0;34m\]' # Dark Blue
dM1='\[\033[0;35m\]' # Dark Magenta
dC1='\[\033[0;36m\]' # Dark Cyan

# Background Colors Definitions
BG_BLACK='\[\033[40m\]'
BG_RED='\[\033[41m\]'
BG_GREEN='\[\033[42m\]'
BG_YELLOW='\[\033[43m\]'
BG_BLUE='\[\033[44m\]'
BG_MAGENTA='\[\033[45m\]'
BG_CYAN='\[\033[46m\]'
BG_WHITE='\[\033[47m\]'

# PWD Collapse Function
_collapse() {
  local pwd="$PWD"
  local home="$HOME"
  local size=${#home}

  [[ -z "$pwd" ]] && return

  if [[ "$pwd" == "/" ]]; then
    echo "/"
    return
  elif [[ "$pwd" == "$home" ]]; then
    echo "~"
    return
  fi

  # Replace $HOME with ~
  if [[ "$pwd" == "$home/"* ]]; then
    pwd="~${pwd:$size}"
  fi

  # Split the path into elements
  local IFS="/"
  local elements=($pwd)
  local length=${#elements[@]}
  local start=0

  # If the path starts with /, skip the first empty element
  if [[ -z "${elements[0]}" ]]; then
    start=1
  fi

  for ((i = start; i < length - 1; i++)); do
    local elem="${elements[$i]}"
    if [[ -n "$elem" ]]; then
      if [[ "$elem" == .* ]]; then
        # Hidden folders show the first 2 characters
        elements[$i]="${elem:0:2}"
      else
        # Non-hidden folders show the first character
        elements[$i]="${elem:0:1}"
      fi
    fi
  done

  # Reassemble the path
  IFS="/"
  echo "${elements[*]}"
}

# Git Branch and Status Function
_git_info() {
    # 性能优化：
    # 1. 检查是否在 Git 仓库内（避免执行 git status 失败）
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return
    fi

    # 2. 大型仓库跳过（对象数 > 50000）
    local git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [[ -n "$git_dir" && -d "$git_dir/objects" ]]; then
        local obj_count=$(find "$git_dir/objects" -type f 2>/dev/null | wc -l)
        if (( obj_count > 50000 )); then
            return
        fi
    fi

    local b r="" s line
    b=$(git branch --show-current 2>/dev/null) || return

    # Get all information in one command
    s=$(git status --porcelain=2 --branch 2>/dev/null)

    # Parse branch information
    local ahead=0 behind=0 ab="$R"
    local ab_line=$(echo "$s" | grep "^# branch\.ab")
    if [[ -n "$ab_line" ]]; then
        ahead=$(echo "$ab_line"  | cut -d' ' -f3 | tr -d '+')
        behind=$(echo "$ab_line" | cut -d' ' -f4 | tr -d '-')
    fi

    # Count files
    local staged=0 unstaged=0 untracked=0 conflicts=0
    while IFS= read -r line; do
        [[ "$line" == "# "* ]] && continue
        case "$line" in
            "1 "*)         staged=$((staged + 1))      ;;  # Staged
            "2 "*)         unstaged=$((unstaged + 1))  ;;  # Unstaged
            " D"*)         unstaged=$((unstaged + 1))  ;;  # Unstaged deletion
            " D"????*)     staged=$((staged + 1))      ;;  # Staged deletion
            "u "*)         conflicts=$((conflicts + 1));;  # Conflicts
            "? "*)         untracked=$((untracked + 1));;  # Untracked
        esac
    done <<< "$(echo "$s" | grep -v '^#')"

    # Build status string
    if (( conflicts > 0 )); then
        r=" ✦${conflicts}"          # Conflicts take precedence
    elif (( staged + unstaged + untracked == 0 )); then
        r=" ○"                       # Clean
    else
        r=" ●"                       # Dirty
        (( staged > 0 ))    && r="$r +${staged}"
        (( unstaged > 0 ))  && r="$r ~${unstaged}"
        (( untracked > 0 )) && r="$r …${untracked}"  # Untracked files
    fi

    # Branch name + status
    local branch_info=" ${b}${r}"

    # Remote sync status
    if (( ahead > 0 )); then
        branch_info="$branch_info ↑${ahead}"
    fi
    if (( behind > 0 )); then
        branch_info="$branch_info ↓${behind}"
    fi

    echo -n "$branch_info "
}

# Check if the user is root
__is_root() { [[ $(id -u) -eq 0 ]] && echo 1; }

# ====== Core: Build Powerline Prompt ======
_powerline_prompt() {
  # 立即保存上一个命令的退出码和管道状态（快照）
  local ec=$?
  local pstatus=("${PIPESTATUS[@]}")   # 数组快照
  local now=$(date +%s)

  # 计算耗时
  local t=""
  if [[ -n "$__ts" ]]; then
    t=$(_fmt_t $((now - __ts)))
    __ts=""
  fi

  local git="$(_git_info)"

  # 状态图标和颜色
  local st_icon=""
  local st_bg="${BG_GREEN}"
  local st_fg="${BR}"
  local st_arr_fg="${dG1}"

  if ((ec != 0)); then
    # 判断是否为管道（多于一个命令）
    if [[ ${#pstatus[@]} -gt 1 ]]; then
      local pipe_info=$(IFS='|'; echo "${pstatus[*]}")
      st_icon=" ✕${pipe_info}"
    else
      st_icon=" ✕${ec}"
    fi
    st_bg="${BG_RED}"
    st_fg="${W1}"
    st_arr_fg="${dR1}"
  fi

  # 构建 Powerline 分段
  local s1="${BG_CYAN}${BB} \u@\h ${R}${dC1}${BG_BLUE}"
  local s2="${BG_BLUE}${W1} $(_collapse) ${R}"
  local s3=""
  if [[ -n "$git" ]]; then
    s2+="${BG_BLACK}${dB1}${BG_YELLOW}"
    s3="${BG_YELLOW}${BR}${git}${R}${BG_BLACK}${dY1}${st_bg}"
  else
    s3="${BG_BLACK}${dB1}${st_bg}"
  fi
  # 状态段：仅在 st_icon 非空时显示图标，否则留空
  if [[ -n "$st_icon" ]]; then
    local s4="${st_bg}${st_fg}${st_icon} ${R}${st_arr_fg}"
  else
    local s4="${st_bg}${st_fg}${R}${st_arr_fg}"   # 留一个空格，避免箭头紧贴
  fi

  PS1="${R}\[\033[1;30m\]───${R}\n${s1}${s2}${s3}${s4} ${R}"
}

PROMPT_COMMAND+=(_powerline_prompt)

# ------------------------------
# Welcome Message
# ------------------------------
printf "Welcome to Bash, \033[0;32m%s\033[0m! \n" "$USER"