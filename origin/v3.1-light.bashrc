#!/bin/bash
# ~/.bashrc
# Version     : 3.1-light
# Update-time : 2026-6-18
# Author      : BiaoZyx
# Email       : BiaoZyx@outlook.com
#####################################
# Commit      : 轻量版，移除计时功能，保留 Git、路径折叠、状态图标


# 加载全局配置
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# 用户环境变量
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        [ -f "$rc" ] && . "$rc"
    done
    unset rc
fi

# bash自动补全
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

############################## 自定义 ##############################
export PATH=~/.npm-global/bin:$PATH

# 备忘录
if [ -f ~/文档/memo.xue ]; then
    memo=$HOME/文档/memo.xue
fi

## 别名
if command -v eza &> /dev/null; then
    export EZA_ICONS_AUTO=1
    alias ls='eza'
else
    alias ls='ls --color=auto'
fi
alias ll='ls -l'
alias la='ls -A'
alias l='ls -lah'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias grep='grep --color=auto'
alias ip='ip --color=auto'

if [[ -z $memo ]]; then
    alias memo='echo "备忘录路径为空！请手动添加到~/.bashrc！"'
else
    if command -v lolcat &>/dev/null; then
        alias memo="lolcat $memo"
    else
        alias memo="cat $memo"
    fi
fi

if [[ -e /usr/bin/thefuck ]]; then
    eval "$(thefuck --alias f)"
fi

####################################################################
# ============ 提示符 ============

# 颜色
R='\[\033[0m\]'
BL='\[\033[1;30m\]'
R1='\[\033[1;31m\]'
G1='\[\033[1;32m\]'
Y1='\[\033[1;33m\]'
B1='\[\033[1;34m\]'
C1='\[\033[1;36m\]'
W1='\[\033[1;37m\]'

BG_BLACK='\[\033[40m\]'
BG_RED='\[\033[41m\]'
BG_GREEN='\[\033[42m\]'
BG_YELLOW='\[\033[43m\]'
BG_BLUE='\[\033[44m\]'
BG_MAGENTA='\[\033[45m\]'
BG_CYAN='\[\033[46m\]'

# 路径折叠
_collapse() {
    local pwd="$PWD" home="$HOME"
    [[ -z "$pwd" ]] && return

    if [[ "$pwd" == "/" ]]; then
        echo "/"; return
    elif [[ "$pwd" == "$home" ]]; then
        echo "~"; return
    fi

    if [[ "$pwd" == "$home/"* ]]; then
        pwd="~${pwd:${#home}}"
    fi

    local IFS="/"
    local elements=($pwd)
    local len=${#elements[@]}
    local start=0
    [[ -z "${elements[0]}" ]] && start=1

    local i elem
    for ((i = start; i < len - 1; i++)); do
        elem="${elements[$i]}"
        [[ -n "$elem" ]] && elements[$i]="${elem:0:1}"
    done

    IFS="/"
    echo "${elements[*]}"
}

# Git 信息（带缓存）
_git_info() {
    local git_dir
    git_dir=$(git rev-parse --show-toplevel 2>/dev/null) || return

    local cache_key="git_$git_dir"
    local -n _git_cache="__git_cache_$cache_key" 2>/dev/null || return

    local now=$(date +%s)
    if [[ -n "${_git_cache[1]}" ]] && ((now - _git_cache[0] < 3)); then
        echo -n "${_git_cache[1]} "
        return
    fi

    local b
    b=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null)
    [[ -z "$b" ]] && return

    local staged=0 unstaged=0 untracked=0 conflicts=0
    local line
    while IFS= read -r line; do
        case "${line:0:2}" in
            "1 ") ((staged++)) ;;
            "2 ") ((unstaged++)) ;;
            " D") ((unstaged++)) ;;
            "u ") ((conflicts++)) ;;
            "? ") ((untracked++)) ;;
        esac
    done < <(git status --porcelain=v2 2>/dev/null | grep -v '^#')

    local r=""
    if (( conflicts > 0 )); then
        r=" ✦${conflicts}"
    elif (( staged + unstaged + untracked == 0 )); then
        r=" ○"
    else
        r=" ●"
        (( staged > 0 ))    && r="$r +${staged}"
        (( unstaged > 0 ))  && r="$r ~${unstaged}"
        (( untracked > 0 )) && r="$r …${untracked}"
    fi

    local result="${b}${r}"
    _git_cache=($now "$result")
    echo -n "$result "
}

# ====== 提示符 ======
_powerline_prompt() {
    local ec=$?

    # Git
    local git=""
    if git rev-parse --show-toplevel &>/dev/null; then
        git=$(_git_info)
    fi

    # 状态图标
    local st_icon="" st_bg="${BG_GREEN}" st_fg="${BL}" st_arr_fg="${G1}"
    if ((ec != 0)); then
        st_icon=" ✕${ec}"
        st_bg="${BG_RED}"
        st_fg="${W1}"
        st_arr_fg="${R1}"
    fi

    # 拼装
    local s1="${BG_CYAN}${BL} \u@\h ${R}${C1}${BG_BLUE}"
    local s2="${BG_BLUE}${W1} $(_collapse) ${R}"
    local s3=""
    if [[ -n "$git" ]]; then
        s2+="${BG_BLACK}${B1}${BG_YELLOW}"
        s3="${BG_YELLOW}${BL}${git}${R}${BG_BLACK}${Y1}${st_bg}"
    else
        s3="${BG_BLACK}${B1}${st_bg}"
    fi
    local s4="${st_bg}${st_fg}${st_icon}${t}${R}${st_arr_fg}"
    if [[ -n "$st_icon" ]]; then
        local s4="${st_bg}${st_fg}${st_icon}${t} ${R}${st_arr_fg}"
    fi

    PS1="${R}\[\033[1;30m\]───${R}\n${s1}${s2}${s3}${s4}${R} "
}

PROMPT_COMMAND=(_powerline_prompt)

# =========================== 欢迎 ==============================
if [[ -e /usr/bin/figlet ]]; then
    figlet_lock_file="/tmp/figlet_lock_$$"
    if [ ! -f "$figlet_lock_file" ]; then
        touch "$figlet_lock_file"
        echo "         _   _ _
/\\_/\\   | | | (_)
(o.o)   | |_| | |_
> ^ < . |  _  | ( )
/   \\ . |_| |_|_|/
"
        figlet "$USER! "
    fi
    trap 'rm -f "$figlet_lock_file"' EXIT TERM
fi
