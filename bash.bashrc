#!/bin/bash
# ~/.bashrc
# Version     : 3.0
# Update-time : 2026-5-4
# Author      : BiaoZyx
# Email       : BiaoZyx@outlook.com

# 加载全局配置
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# 用户环境变量
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

# 在交互shell启用bash自动补全，建议安装`bash-completion`并启用
if ! shopt -oq posix; then
	if [ -f /usr/share/bash-completion/bash_completion ]; then
		. /usr/share/bash-completion/bash_completion
	elif [ -f /etc/bash_completion ]; then
		. /etc/bash_completion
	fi
fi
############################## 自定义 ##############################
## 变量
# 如果使用opkg，添加以下内容
#export PATH=$PATH:/opt/bin
export PATH=~/.npm-global/bin:$PATH

# ----- 备忘录 -----
if [ -f ~/文档/memo.xue ]; then # 自定义备忘录
	memo=/home/xue/文档/memo.xue

fi

## 别名
alias ls="ls --color -F"   # 自定义`ls`，可自行删减
alias l="ls -lah"          # 自定义`ls`，可自行删减
alias ll="ls -lh"          # 自定义`ls`，可自行删减
alias ip='ip --color=auto' # `ip a`的彩色，很有必要

if [[ -z $memo ]]; then
	alias memo="echo 备忘录路径为空！请手动添加到~/.bashrc！"
else
	if command -v lolcat &>/dev/null; then
		alias memo="lolcat $memo"
	else
		alias memo="cat $memo"
	fi
fi

alias irssi-rizon="irssi -c irc.rizon.net" # 我的`irssi`快捷配置

alias d--="g++ -x cpp"

# `thefuck`配置，安装才加载
if [[ -e /usr/bin/thefuck ]]; then
	eval $(thefuck --alias f)
fi
####################################################################
# ============ 现代 Powerline 风格提示符 ============
# ============ Powerline 全箭头风格 ============

# 颜色定义
R='\[\033[0m\]'     # 重置
BL='\[\033[1;30m\]' # 黑体
R1='\[\033[1;31m\]' # 红色
G1='\[\033[1;32m\]' # 绿色
Y1='\[\033[1;33m\]' # 黄色
B1='\[\033[1;34m\]' # 蓝色
M1='\[\033[1;35m\]' # 紫色
C1='\[\033[1;36m\]' # 青色
W1='\[\033[1;37m\]' # 白色

# 背景色
BG_BLACK='\[\033[40m\]'
BG_RED='\[\033[41m\]'
BG_GREEN='\[\033[42m\]'
BG_YELLOW='\[\033[43m\]'
BG_BLUE='\[\033[44m\]'
BG_MAGENTA='\[\033[45m\]'
BG_CYAN='\[\033[46m\]'
BG_WHITE='\[\033[47m\]'

# 路径折叠
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

	# 替换 $HOME 为 ~
	if [[ "$pwd" == "$home/"* ]]; then
		pwd="~${pwd:$size}"
	fi

	# 分割路径
	local IFS="/"
	local elements=($pwd)
	local length=${#elements[@]}
	local start=0

	# 如果路径以 / 开头，跳过第一个空元素
	if [[ -z "${elements[0]}" ]]; then
		start=1
	fi

	for ((i = start; i < length - 1; i++)); do
		local elem="${elements[$i]}"
		if [[ -n "$elem" ]]; then
			if [[ "$elem" == .* ]]; then
				# 隐藏文件夹（以 . 开头）显示前 2 个字符
				elements[$i]="${elem:0:2}"
			else
				# 普通文件夹显示第 1 个字符
				elements[$i]="${elem:0:1}"
			fi
		fi
	done

	# 重新组合路径
	IFS="/"
	echo "${elements[*]}"
}

# Git 分支+状态
_git_info() {
    local b r="" s line
    b=$(git branch --show-current 2>/dev/null) || return

    # 一次命令获取所有信息
    s=$(git status --porcelain=2 --branch 2>/dev/null)

    # 解析分支信息
    local ahead=0 behind=0 ab="$R"
    local ab_line=$(echo "$s" | grep "^# branch\.ab")
    if [[ -n "$ab_line" ]]; then
        ahead=$(echo "$ab_line"  | cut -d' ' -f3 | tr -d '+')
        behind=$(echo "$ab_line" | cut -d' ' -f4 | tr -d '-')
    fi

    # 统计文件
    local staged=0 unstaged=0 untracked=0 conflicts=0
    while IFS= read -r line; do
        [[ "$line" == "# "* ]] && continue
        case "$line" in
            "1 "*)  staged=$((staged + 1))      ;;  # 暂存区
            "2 "*)  unstaged=$((unstaged + 1))  ;;  # 工作区修改
            "u "*)  conflicts=$((conflicts + 1));;  # 冲突（最重要）
            "? "*)  untracked=$((untracked + 1));;  # 未跟踪
        esac
    done <<< "$(echo "$s" | grep -v '^#')"

    # 构建状态字符串
    if (( conflicts > 0 )); then
        r=" ✦${conflicts}"          # 有冲突最优先
    elif (( staged + unstaged + untracked == 0 )); then
        r=" ○"                       # 干净
    else
        r=" ●"                       # 有修改
        (( staged > 0 ))    && r="$r +${staged}"
        (( unstaged > 0 ))  && r="$r ~${unstaged}"
        (( untracked > 0 )) && r="$r …${untracked}"  # 未跟踪文件
    fi

    # 分支名 + 状态
    local branch_info=" ${b}${r}"

    # 远程同步状态
    if (( ahead > 0 )); then
        branch_info="$branch_info ↑${ahead}"
    fi
    if (( behind > 0 )); then
        branch_info="$branch_info ↓${behind}"
    fi

    echo -n "$branch_info "
}

# 耗时格式化
_fmt_t() {
	local ms=$((($1 + 500000) / 1000000))
	if ((ms < 1000)); then
		printf "%dms" $ms
	elif ((ms < 60000)); then
		printf "%d.%01ds" $((ms / 1000)) $(((ms % 1000) / 100))
	elif ((ms < 3600000)); then
		printf "%dm%02ds" $((ms / 60000)) $(((ms % 60000) / 1000))
	else
		printf "%dh%02dm" $((ms / 3600000)) $(((ms % 3600000) / 60000))
	fi
}

# 计时
__ts=""
trap '__ps=("${PIPESTATUS[@]}"); [[ -z "$__ts" ]] && __ts=$(date +%s%N)' DEBUG

# 根用户检测
__is_root() { [[ $(id -u) -eq 0 ]] && echo 1; }

# ====== 核心：构建 Powerline 提示符 ======
_powerline_prompt() {
	local ec=$?
	local now=$(date +%s%N)

	# 耗时
	local t=""
	if [[ -n "$__ts" ]]; then
		t=$(_fmt_t $((now - __ts)))
		__ts=""
	fi

	# Git
	local git="$(_git_info)"

	# 状态图标（支持管道状态）
	local st_icon=""
	local st_bg="${BG_GREEN}"
	local st_fg="${BL}"
	local st_arr_fg="${G1}"
	if ((ec != 0)); then
		# 检查管道状态
		if [[ -n "${__ps[*]}" && ${#__ps[@]} -gt 1 ]]; then
			local pipe_info=$(
				IFS='|'
				echo "${__ps[*]}"
			)
			st_icon=" ✕${pipe_info}"
		else
			st_icon=" ✕${ec}"
		fi
		st_bg="${BG_RED}"
		st_fg="${W1}"
		st_arr_fg="${R1}"
	fi

	# === 拼装 Powerline 全箭头 ===
	# 段1: 用户@主机  (青色底+黑字) → 箭头进入蓝色
	local s1="${BG_CYAN}${BL} \u@\h ${R}${C1}${BG_BLUE}"

	# 段2: 路径 (蓝色底+白字)
	local s2="${BG_BLUE}${W1} $(_collapse) ${R}"

	# 段3: Git部分 / 直接跳到耗时
	local s3=""
	if [[ -n "$git" ]]; then
		# 有git：蓝色箭头进入黄色 → git文字 → 黄色箭头进入状态色
		s2+="${BG_BLACK}${B1}${BG_YELLOW}"
		s3="${BG_YELLOW}${BL}${git}${R}${BG_BLACK}${Y1}${st_bg}"
	else
		# 没git：蓝色箭头直接进入状态色
		s3="${BG_BLACK}${B1}${st_bg}"
	fi

	# 段4: 耗时+状态图标 → 末端箭头
	local s4="${st_bg}${st_fg}${st_icon} ${t} ${R}${st_arr_fg}"

	# 最终单行
	PS1="\n${s1}${s2}${s3}${s4} ${R}"
}

PROMPT_COMMAND+=(_powerline_prompt)

# =========================== 欢迎界面 ==============================
if [[ -e /usr/bin/figlet ]]; then
	figlet_lock_file="/tmp/figlet_lock_$$"
	# 使用 $$ 作为文件名的一部分，确保每个进程都有自己的锁文件
	# 检查锁文件是否存在
	if [ ! -f "$figlet_lock_file" ]; then
		# 创建锁文件并执行 figlet
		touch "$figlet_lock_file"
		echo "         _   _ _
/\\_/\\   | | | (_)
(o.o)   | |_| | |_
> ^ < . |  _  | ( )
/   \\ . |_| |_|_|/
"
		figlet "$USER! "
	fi
fi
trap 'rm -f "$figlet_lock_file"' EXIT TERM # 用钩子，等退出删除锁文件
