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
#                (~/.bashrc)
# =======================================================

# ------------------------------
# Core Settings
# ------------------------------

# Setup for interactive shell
if [[ $- == *i* ]]; then
  . $HOME/.bashrc.d/interactive.startup
fi

# Load Global Configs
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# User's Configs
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

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

# ------------------------------
# Prompt Settings
# ------------------------------
# The Powerline-like Prompt

# Colors Definitions
R='\[\033[0m\]'     # Reset
BR='\[\033[30m\]'   # Black - Regular
BB='\[\033[1;30m\]' # Black - Bold

# Unused Colors Definitions
#R1='\[\033[1;31m\]' # Red
#G1='\[\033[1;32m\]' # Green
#Y1='\[\033[1;33m\]' # Yellow
#B1='\[\033[1;34m\]' # Blue
#M1='\[\033[1;35m\]' # Magenta
#C1='\[\033[1;36m\]' # Cyan

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

# Prompt style and git cache settings
GIT_PROMPT_CACHE_TTL=3
#PROMPT_STYLE=1
PROMPT_STYLE_COUNT=2
PROMPT_STYLE_NAMES=(Powerline ASCII)
__git_info_cache=''
__git_info_cache_time=0

# PWD Collapse Function
_collapse() {
  local home_dir path
  if [[ -n "$HOME" && "$HOME" == /* ]]; then
    home_dir=$(cd -- "$HOME" 2>/dev/null && pwd) || home_dir=""
  else
    home_dir=""
  fi

  path="${PWD:-$(pwd -P 2>/dev/null)}"
  [[ -z "$path" ]] && return

  if [[ "$path" == "/" ]]; then
    echo "/"
    return
  elif [[ -n "$home_dir" && "$path" == "$home_dir" ]]; then
    echo "~"
    return
  fi

  if [[ -n "$home_dir" && "$path" == "$home_dir/"* ]]; then
    path="~${path:${#home_dir}}"
  fi

  local leading_slash=""
  if [[ "$path" == /* ]]; then
    leading_slash="/"
    path="${path#/}"
  fi

  local IFS="/"
  local segments=()
  read -ra segments <<< "$path"
  local last_index=$(( ${#segments[@]} - 1 ))
  local result="${leading_slash}"

  for i in "${!segments[@]}"; do
    local seg="${segments[i]}"
    if (( i < last_index )); then
      if [[ -n "$seg" ]]; then
        if [[ "$seg" == .* ]]; then
          result+="${seg:0:2}"
        else
          result+="${seg:0:1}"
        fi
      fi
      result+="/"
    else
      result+="$seg"
    fi
  done

  echo "$result"
}

# Git Branch and Status Function
_git_info() {
    local now
    now=$(date +%s)
    if [[ -n "$__git_info_cache_time" && $((now - __git_info_cache_time)) -lt GIT_PROMPT_CACHE_TTL ]]; then
        printf '%s' "$__git_info_cache"
        return
    fi

    # 1. 仅在 Git 仓库中计算信息，避免无谓开销
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        __git_info_cache=''
        __git_info_cache_time=$now
        return
    fi

    local b r="" s line
    b=$(git branch --show-current 2>/dev/null) || return

    # 2. 使用 GIT_OPTIONAL_LOCKS=0 降低 git status 的锁开销
    s=$(GIT_OPTIONAL_LOCKS=0 git status --porcelain=2 --branch --untracked-files=normal 2>/dev/null) || return

    # Parse branch information
    local ahead=0 behind=0 ab="$R"
    local ab_line=$(echo "$s" | grep "^# branch\.ab")
    if [[ -n "$ab_line" ]]; then
        ahead=$(echo "$ab_line" | cut -d' ' -f3 | tr -d '+')
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

    __git_info_cache="$branch_info"
    __git_info_cache_time=$now

    printf '%s' "$branch_info "
}

# ====== Core: Build Powerline Prompt ======
_powerline_prompt() {
  # 使用传入的退出码和管道状态；若没有传入，则回退到当前上下文的值
  local ec="${1:-${_saved_ec:-$?}}"
  local pstatus=()
  if [[ $# -gt 1 ]]; then
    shift
    pstatus=("$@")
  else
    pstatus=("${_saved_ps[@]}")
    if [[ ${#pstatus[@]} -eq 0 ]]; then
      pstatus=("${PIPESTATUS[@]}")
    fi
  fi
  local now=$(date +%s)

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

__prompt_set_powerline() {
  PROMPT_STYLE=1
}

__prompt_set_ascii() {
  PROMPT_STYLE=2
}

__prompt_toggle_style() {
  if [[ $PROMPT_STYLE -eq 1 ]]; then
    PROMPT_STYLE=2
  else
    PROMPT_STYLE=1
  fi
  # 重建 PS1
  _build_prompt

  # 让 readline 立即重绘当前行
  if [[ -n "$READLINE_LINE" ]]; then
    printf '\r\e[K'
    READLINE_LINE="$READLINE_LINE"
    READLINE_POINT=${READLINE_POINT:-${#READLINE_LINE}}
  fi
}

_build_prompt() {
  # 从全局变量获取保存的退出码
  local ec="${_saved_ec:-0}"
  local pstatus=()
  if [[ ${#_saved_ps[@]} -gt 0 ]]; then
    pstatus=("${_saved_ps[@]}")
  else
    pstatus=("${PIPESTATUS[@]}")
  fi

  case "$PROMPT_STYLE" in
    1)
      _powerline_prompt "${_saved_ec}" "${_saved_ps[@]}"
      ;;
    2)
      # === 带 8 色的 ASCII 风格 ===
      local git="$(_git_info)"
      local path="$(_collapse)"
      local git_part=""

      if [[ -n "$git" ]]; then
        local clean_git="${git///}"
        clean_git="${clean_git//○/-}"
        clean_git="${clean_git//●/*}"
        clean_git="${clean_git//✦/!}"
        clean_git="${clean_git//↑/[ahead]}"
        clean_git="${clean_git//↓/[behind]}"
        clean_git="${clean_git//+/ +}"
        clean_git="${clean_git//~/ ~}"
        clean_git="${clean_git//…/ .}"
        clean_git="$(echo "$clean_git" | tr -s ' ')"
        clean_git="$(echo "$clean_git" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        git_part=" (${dY1}${clean_git}${R})"
      fi

      # 命令退出码和管道状态（保留你之前的错误提示）
      local ec=$_saved_ec
      local pstatus=("${_saved_ps[@]}")
      local st=""
      if ((ec != 0)); then
        if [[ ${#pstatus[@]} -gt 1 ]]; then
          local pipe_info=$(IFS='|'; echo "${pstatus[*]}")
          st=" ${dR1}[✕${pipe_info}]${R}"
        else
          st=" ${dR1}[${ec}]${R}"
        fi
      fi

      # 根据命令执行结果决定 `>` 的颜色
      local prompt_color="${dG1}"
      if (( ec != 0 )); then
        prompt_color="${dR1}"
      fi

      # 构建提示符：用户名、主机、路径、Git、错误状态，最后是带颜色的 `>`
      PS1="\n${dC1}\u${R}@${dM1}\h${R}:${dB1}${path}${R}${git_part}${st}\n${prompt_color}> ${R}"
      ;;
  esac
}