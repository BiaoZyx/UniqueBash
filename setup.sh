#!/usr/bin/env bash
# ============================================================
# UniqueBash Setup Script
# 一键安装 / 更新 / 卸载 UniqueBash（bash）配置
# ============================================================
# 用法:   ./setup.sh [子命令] [选项]
# 子命令: install | update | uninstall | status | preview | help | version
# 退出码: 0 成功 | 1 致命错误 | 2 用法错误 | 3 前置检查失败
#         4 动作完成但存在合并冲突 | status 子命令: 1 = 发现问题
# ============================================================

set -e
set -o pipefail
shopt -s extglob

# ===================== L1 常量 =====================

PROGRAM='UniqueBash'
VERSION='3.4'
RC_FILE="$HOME/.bashrc"
PROFILE_FILE="$HOME/.bash_profile"
MOD_DIR="$HOME/.bashrc.d"
STATE_FILE="$MOD_DIR/.install_state"
REPO_ROOT_FILE="$MOD_DIR/.repo_root"
LAST_UPDATE_FILE="$MOD_DIR/.last_update"
RC_NAME='main.bashrc'
PROFILE_NAME='startup.bash_profile'
MOD_NAME='bashrc.d'

# ---------- 运行时状态（parse_args / 动作过程写入） ----------
ACTION='install'
DRY_RUN=0
NONINTERACTIVE=0
NO_BACKUP=0
OVERWRITE_MODULES=0
SEL_MODE='all'          # all | tui | numeric | arg
MODULES_SPEC=''
LANG_OVERRIDE=''
HAS_CONFLICT=0
MODULES_CSV=''
CONFLICTS_CSV=''
SCRIPT_DIR=''
MSG_TEXT=''
STATE_VALUE=''
NEWEST=''
TMPFILES=()
MODULES=()
SELECTED=()

# ---------- L3 颜色（init_colors 依据 TTY / NO_COLOR 决定） ----------
C_RESET=''
C_RED=''
C_GREEN=''
C_YELLOW=''
C_BLUE=''

# ---------- 临时文件清理 ----------
cleanup() {
    if ((${#TMPFILES[@]} > 0)); then
        rm -f "${TMPFILES[@]}" 2>/dev/null || true
    fi
    return 0
}
trap cleanup EXIT

# ===================== L2 国际化（zh / en） =====================

TEXT_LANG='en'

init_lang() {
    local c=''
    if [[ -n $LANG_OVERRIDE ]]; then
        c=$LANG_OVERRIDE
    elif [[ -n ${UNIQUEBASH_LANG:-} ]]; then
        c=$UNIQUEBASH_LANG
    elif [[ -n ${LC_ALL:-} ]]; then
        c=$LC_ALL
    elif [[ -n ${LC_MESSAGES:-} ]]; then
        c=$LC_MESSAGES
    elif [[ -n ${LANGUAGE:-} ]]; then
        c=$LANGUAGE
    elif [[ -n ${LANG:-} ]]; then
        c=$LANG
    fi
    case $c in
        zh*|ZH*) TEXT_LANG='zh' ;;
        *)       TEXT_LANG='en' ;;
    esac
    if [[ -n $LANG_OVERRIDE ]]; then
        case $LANG_OVERRIDE in
            zh|en) TEXT_LANG=$LANG_OVERRIDE ;;
            *)     die 2 bad.lang "$LANG_OVERRIDE" ;;
        esac
    fi
    return 0
}

# _msg KEY [args...]：把模板写入 MSG_TEXT；未翻译的 KEY 回退为 KEY 本身
_msg() {
    local key=$1
    local tpl=''
    local a
    shift
    if [[ $TEXT_LANG == 'zh' ]]; then
        case $key in
            bad.source) tpl='请勿用 source 运行本脚本，请执行: bash setup.sh <子命令>' ;;
            bad.missing_main) tpl='找不到 {}，请在仓库根目录运行本脚本' ;;
            bad.missing_dir) tpl='无法进入目录 {}' ;;
            bad.unknown_opt) tpl='未知选项: {}' ;;
            bad.unknown_subcmd) tpl='未知子命令: {}' ;;
            bad.no_value) tpl='选项 {} 需要一个取值' ;;
            bad.lang) tpl='不支持的语言: {}（可用: zh / en）' ;;
            bad.two_cmds) tpl='一次只能指定一个子命令（已有 {}，又给出 {}）' ;;
            hint.help) tpl="运行 './setup.sh help' 查看用法" ;;
            preview.banner) tpl='预览模式：以下操作不会写入磁盘' ;;
            preview.done) tpl='预览结束，未修改任何文件。' ;;
            repo.dir) tpl='仓库目录: {}' ;;
            no.main) tpl='模块目录 {} 不存在，跳过模块部分' ;;
            no.modules) tpl='{} 目录为空，跳过模块部分' ;;
            backup.none) tpl='{} 不是常规文件，无需备份' ;;
            backup.skip) tpl='按 --no-backup 跳过备份: {}' ;;
            backup.ok) tpl='已备份 {} -> {}' ;;
            plan.backup) tpl='  计划备份: {} -> {}' ;;
            plan.link) tpl='  计划链接: {} -> {}' ;;
            plan.copy) tpl='  计划复制: {} -> {}' ;;
            plan.merge) tpl='  计划三方合并: {}（保留你的修改，合入上游新增）' ;;
            plan.merge_conflict) tpl='  计划三方合并: {}（预计冲突，保留你的版本，结果写入 .merged_{}）' ;;
            plan.remove) tpl='  计划移除: {}' ;;
            plan.restore) tpl='  计划恢复: {} <- {}' ;;
            link.ok) tpl='已链接 {} -> {}' ;;
            link.same) tpl='{} 已指向 {}，无需更改' ;;
            modules.list_title) tpl='可用模块：' ;;
            modules.default_all) tpl='缺省安装全部 {} 个模块（可用 --select / --tui 自选）' ;;
            modules.none_selected) tpl='未选择任何模块' ;;
            modules.unknown_name) tpl='未知模块名: {}' ;;
            select.notty) tpl='非交互式环境，改为全量安装' ;;
            select.no_tui_tool) tpl='未检测到 dialog / fzf，改用编号选择' ;;
            select.cancelled) tpl='已取消，未做任何更改' ;;
            select.numeric_prompt) tpl='输入模块编号（逗号分隔），all 全选，空行结束:' ;;
            select.numeric_invalid) tpl='无效编号: {}' ;;
            select.tui_title) tpl='选择要安装的模块（空格勾选）' ;;
            select.tui_header) tpl='模块多选（Ctrl-O 保存）' ;;
            merge.new) tpl='已安装 {}（新模块）' ;;
            merge.latest) tpl='{} 已是最新' ;;
            merge.subset) tpl='已更新 {}（应用仓库新增）' ;;
            merge.forced) tpl='已强制覆盖 {}' ;;
            merge.nogit) tpl='已更新 {}（未检测到 git，无法三方合并；旧版备份: {}）' ;;
            merge.ok) tpl='已合并 {}（你的修改已保留，备份: {}）' ;;
            merge.conflict) tpl='{} 合并冲突！已保留你的可用版本；冲突合并结果: {}' ;;
            merge.conflict_hint) tpl='解决后执行: cp {} {}' ;;
            install.done) tpl='安装完成！' ;;
            install.hint) tpl='新开一个终端生效；或执行 {}' ;;
            update.start) tpl='开始更新 {}（三方融合，跳过 *.local.*）...' ;;
            update.done) tpl='更新完成！' ;;
            conflict_count) tpl='完成，但 {} 个模块存在合并冲突，请按上方提示处理' ;;
            uninstall.start) tpl='开始卸载 {} ...' ;;
            uninstall.restore) tpl='已恢复 {} <- {}' ;;
            uninstall.no_backup) tpl='未找到 {} 的备份，已移除该文件' ;;
            uninstall.remove_module) tpl='已移除默认模块 {}' ;;
            uninstall.restore_user) tpl='已恢复 {} <- {}（你的修改版本）' ;;
            uninstall.done) tpl='卸载完成。个人自定义文件（*.local.*）已保留。' ;;
            status.title) tpl='UniqueBash 安装状态' ;;
            status.shell) tpl='运行环境: {}' ;;
            status.no_state) tpl='未找到状态文件 {}（旧版安装或尚未安装）' ;;
            status.version) tpl='安装版本: {}' ;;
            status.at) tpl='安装时间: {}' ;;
            status.action) tpl='上次动作: {}' ;;
            status.commit) tpl='仓库提交: {}' ;;
            status.repo) tpl='仓库路径: {}' ;;
            status.rc_ok) tpl='{} -> {} （软链正常）' ;;
            status.rc_bad) tpl='{} 未链接到本仓库（当前指向 {}）' ;;
            status.rc_notlink) tpl='{} 不是软链接' ;;
            status.rc_missing) tpl='{} 不存在' ;;
            status.not_symlink) tpl='不是软链接' ;;
            status.modules) tpl='默认模块 {} 个，与上游有差异 {} 个' ;;
            status.modules_clean) tpl='全部默认模块与上游一致' ;;
            status.drift_list) tpl='差异清单: {}' ;;
            status.conflicts) tpl='待处理合并冲突: {}' ;;
            status.no_conflicts) tpl='无待处理冲突' ;;
            status.not_installed) tpl='未安装（找不到 {}）' ;;
            status.ok) tpl='状态正常' ;;
            status.bad) tpl='发现 {} 处问题' ;;
        esac
    else
        case $key in
            bad.source) tpl='Do not source this script; run: bash setup.sh <subcommand>' ;;
            bad.missing_main) tpl='{} not found; run this script from the repository root' ;;
            bad.missing_dir) tpl='Cannot enter directory {}' ;;
            bad.unknown_opt) tpl='Unknown option: {}' ;;
            bad.unknown_subcmd) tpl='Unknown subcommand: {}' ;;
            bad.no_value) tpl='Option {} requires a value' ;;
            bad.lang) tpl='Unsupported language: {} (choose zh / en)' ;;
            bad.two_cmds) tpl='Only one subcommand is allowed (have {}, got {})' ;;
            hint.help) tpl="Run './setup.sh help' for usage" ;;
            preview.banner) tpl='Preview mode: nothing below will be written to disk' ;;
            preview.done) tpl='Preview finished. No files were modified.' ;;
            repo.dir) tpl='Repository: {}' ;;
            no.main) tpl='Module directory {} is missing; skipping modules' ;;
            no.modules) tpl='{} is empty; skipping modules' ;;
            backup.none) tpl='{} is not a regular file; nothing to back up' ;;
            backup.skip) tpl='Backup skipped (--no-backup): {}' ;;
            backup.ok) tpl='Backed up {} -> {}' ;;
            plan.backup) tpl='  would back up: {} -> {}' ;;
            plan.link) tpl='  would link: {} -> {}' ;;
            plan.copy) tpl='  would copy: {} -> {}' ;;
            plan.merge) tpl='  would 3-way merge: {} (keep your edits, apply upstream additions)' ;;
            plan.merge_conflict) tpl='  would 3-way merge: {} (likely conflict; your version kept, result in .merged_{})' ;;
            plan.remove) tpl='  would remove: {}' ;;
            plan.restore) tpl='  would restore: {} <- {}' ;;
            link.ok) tpl='Linked {} -> {}' ;;
            link.same) tpl='{} already points to {}; unchanged' ;;
            modules.list_title) tpl='Available modules:' ;;
            modules.default_all) tpl='Installing all {} modules by default (use --select / --tui to choose)' ;;
            modules.none_selected) tpl='No modules selected' ;;
            modules.unknown_name) tpl='Unknown module: {}' ;;
            select.notty) tpl='Non-interactive environment; installing everything' ;;
            select.no_tui_tool) tpl='dialog / fzf not found; falling back to numeric selection' ;;
            select.cancelled) tpl='Cancelled; no changes were made' ;;
            select.numeric_prompt) tpl='Enter module numbers (comma-separated), or "all", empty line to finish:' ;;
            select.numeric_invalid) tpl='Invalid number: {}' ;;
            select.tui_title) tpl='Select modules to install (space to toggle)' ;;
            select.tui_header) tpl='Multi-select (Ctrl-O to accept)' ;;
            merge.new) tpl='Installed {} (new module)' ;;
            merge.latest) tpl='{} is already up to date' ;;
            merge.subset) tpl='Updated {} (applied upstream additions)' ;;
            merge.forced) tpl='Force-overwrote {}' ;;
            merge.nogit) tpl='Updated {} (git not found, no 3-way merge; previous version backed up at {})' ;;
            merge.ok) tpl='Merged {} (your changes kept; backup: {})' ;;
            merge.conflict) tpl='Conflict in {}! Your working version was kept; merge result: {}' ;;
            merge.conflict_hint) tpl='After resolving, run: cp {} {}' ;;
            install.done) tpl='Installation complete!' ;;
            install.hint) tpl='Open a new terminal to apply; or run {}' ;;
            update.start) tpl='Updating {} (3-way merge, skipping *.local.*)...' ;;
            update.done) tpl='Update complete!' ;;
            conflict_count) tpl='Finished, but {} module(s) have merge conflicts; follow the messages above' ;;
            uninstall.start) tpl='Uninstalling {} ...' ;;
            uninstall.restore) tpl='Restored {} <- {}' ;;
            uninstall.no_backup) tpl='No backup found for {}; the file was removed' ;;
            uninstall.remove_module) tpl='Removed default module {}' ;;
            uninstall.restore_user) tpl='Restored {} <- {} (your edited version)' ;;
            uninstall.done) tpl='Uninstalled. Your personal files (*.local.*) were kept.' ;;
            status.title) tpl='UniqueBash install status' ;;
            status.shell) tpl='Runtime: {}' ;;
            status.no_state) tpl='State file {} not found (older install or not installed)' ;;
            status.version) tpl='Installed version: {}' ;;
            status.at) tpl='Installed at: {}' ;;
            status.action) tpl='Last action: {}' ;;
            status.commit) tpl='Repo commit: {}' ;;
            status.repo) tpl='Repo path: {}' ;;
            status.rc_ok) tpl='{} -> {} (symlink OK)' ;;
            status.rc_bad) tpl='{} does not link to this repo (currently points to {})' ;;
            status.rc_notlink) tpl='{} is not a symlink' ;;
            status.rc_missing) tpl='{} does not exist' ;;
            status.not_symlink) tpl='not a symlink' ;;
            status.modules) tpl='Default modules: {}, differing from upstream: {}' ;;
            status.modules_clean) tpl='All default modules match upstream' ;;
            status.drift_list) tpl='Drifting: {}' ;;
            status.conflicts) tpl='Pending merge conflicts: {}' ;;
            status.no_conflicts) tpl='No pending conflicts' ;;
            status.not_installed) tpl='Not installed ({} not found)' ;;
            status.ok) tpl='Status OK' ;;
            status.bad) tpl='Found {} problem(s)' ;;
        esac
    fi
    [[ -n $tpl ]] || tpl=$key
    for a in "$@"; do
        tpl=${tpl/"{}"/$a}
    done
    MSG_TEXT=$tpl
    return 0
}

msg() {
    _msg "$@"
    printf '%s\n' "$MSG_TEXT"
    return 0
}

# ===================== L3 输出 =====================

init_colors() {
    if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
        C_RESET=$'\e[0m'
        C_RED=$'\e[0;31m'
        C_GREEN=$'\e[0;32m'
        C_YELLOW=$'\e[0;33m'
        C_BLUE=$'\e[0;34m'
    fi
    return 0
}

# say LEVEL KEY [args...]   LEVEL: info | success | warn | error | plain
say() {
    local level=$1
    shift
    _msg "$@"
    case $level in
        info)    printf '%s\n' "${C_BLUE}ℹ${C_RESET} ${MSG_TEXT}" ;;
        success) printf '%s\n' "${C_GREEN}✔${C_RESET} ${MSG_TEXT}" ;;
        warn)    printf '%s\n' "${C_YELLOW}⚠${C_RESET} ${MSG_TEXT}" >&2 ;;
        error)   printf '%s\n' "${C_RED}✘${C_RESET} ${MSG_TEXT}" >&2 ;;
        plain)   printf '%s\n' "$MSG_TEXT" ;;
    esac
    return 0
}

# 状态输出行（2 空格缩进）
sline() {
    _msg "$@"
    printf '%s\n' "  ${MSG_TEXT}"
    return 0
}

# 预览计划行
plan_line() {
    _msg "$@"
    printf '%s\n' "  ${MSG_TEXT}"
    return 0
}

die() {
    local code=$1
    shift
    say error "$@"
    exit "$code"
}

show_help() {
    if [[ $TEXT_LANG == 'zh' ]]; then
        printf '%s\n' "${PROGRAM} 安装脚本 ${VERSION}"
        printf '%s\n' ''
        cat <<'EOF'
用法:
  ./setup.sh [子命令] [选项]        缺省子命令 = install

子命令:
  install        安装：备份并软链 ~/.bashrc、~/.bash_profile，安装模块
  update         更新：修复软链，三方融合升级模块（跳过 *.local.*）
  uninstall      卸载：按备份恢复 ~/.bashrc、~/.bash_profile，移除默认模块
  status         查看安装状态、软链指向、模块差异与待处理冲突
  preview [动作] 预演任意动作（install/update/uninstall），不写盘
  help           显示帮助
  version        显示版本

选项:
  --yes, --auto          非交互（缺省即全装）
  --tui                  用 TUI（dialog / fzf）选择模块
  --select               用编号交互选择模块
  --modules=a,b,c        按模块名非交互选择
  --no-backup            不备份 ~/.bashrc / ~/.bash_profile
  --overwrite-modules    更新时直接以仓库版本覆盖你的模块修改
  --force                兼容别名 = --no-backup + --overwrite-modules
  --lang=zh|en           界面语言（缺省跟随系统 locale）
  --preview              对当前动作做 dry-run（不写盘）
  --help / --version     同 help / version 子命令

退出码:
  0 成功        1 致命错误      2 用法错误      3 前置检查失败
  4 动作完成但存在合并冲突（status 子命令: 0 正常, 1 发现问题）

兼容旧标志:
  --update --uninstall --preview --tui --yes --force --help --version

示例:
  ./setup.sh                      # 全量安装（零提问）
  ./setup.sh --select             # 编号选择模块
  ./setup.sh update               # 日常更新
  ./setup.sh preview update       # 预演更新，不写盘
  ./setup.sh status               # 查看状态
  ./setup.sh uninstall --yes      # 非交互卸载
  ./setup.sh --lang=en help       # 英文帮助
EOF
    else
        printf '%s\n' "${PROGRAM} setup script ${VERSION}"
        printf '%s\n' ''
        cat <<'EOF'
Usage:
  ./setup.sh [subcommand] [options]     default subcommand = install

Subcommands:
  install        back up + symlink ~/.bashrc and ~/.bash_profile, install modules
  update         repair symlinks, 3-way merge modules (skip *.local.*)
  uninstall      restore ~/.bashrc / ~/.bash_profile from backups, remove default modules
  status         show install state, symlink targets, module drift, pending conflicts
  preview [act]  dry-run any action (install/update/uninstall), write nothing
  help           show this help
  version        show version

Options:
  --yes, --auto          non-interactive (default is already a full install)
  --tui                  pick modules with a TUI (dialog / fzf)
  --select               pick modules with numbered prompts
  --modules=a,b,c        pick modules by name, non-interactively
  --no-backup            do not back up ~/.bashrc / ~/.bash_profile
  --overwrite-modules    overwrite your edited modules with the repo version
  --force                legacy alias = --no-backup + --overwrite-modules
  --lang=zh|en           UI language (default follows your locale)
  --preview              dry-run the current action (write nothing)
  --help / --version     same as the help / version subcommands

Exit codes:
  0 success     1 fatal error   2 usage error   3 preflight failure
  4 finished with merge conflicts (status subcommand: 0 OK, 1 problems)

Legacy flags (still accepted):
  --update --uninstall --preview --tui --yes --force --help --version

Examples:
  ./setup.sh                      # full install, no questions
  ./setup.sh --select             # pick modules by number
  ./setup.sh update               # everyday update
  ./setup.sh preview update       # dry-run an update
  ./setup.sh status               # show status
  ./setup.sh uninstall --yes      # non-interactive uninstall
  ./setup.sh --lang=zh help       # Chinese help
EOF
    fi
    return 0
}

show_version() {
    printf '%s\n' "${PROGRAM} setup ${VERSION}"
    return 0
}

# ===================== L4 基础 helper =====================

stamp_now() {
    date +%Y%m%d_%H%M%S
}

# newest_backup <glob...>：把最近修改的匹配文件写入 NEWEST（无匹配则为空）
newest_backup() {
    local out
    out=$(ls -t "$@" 2>/dev/null || true)
    if [[ -n $out ]]; then
        NEWEST=${out%%$'\n'*}
    else
        NEWEST=''
    fi
    return 0
}

# backup_file <path>：备份到 path.bak.<timestamp>（受 --no-backup / --preview 影响）
backup_file() {
    local f=$1
    local dest
    if [[ $NO_BACKUP -eq 1 ]]; then
        say info backup.skip "$f"
        return 0
    fi
    dest="$f.bak.$(stamp_now)"
    if [[ $DRY_RUN -eq 1 ]]; then
        plan_line plan.backup "$f" "$dest"
        return 0
    fi
    cp "$f" "$dest"
    say success backup.ok "$f" "$dest"
    return 0
}

# link_file <src> <dst>：symlink 到位（幂等）
link_file() {
    local src=$1
    local dst=$2
    if [[ $DRY_RUN -eq 1 ]]; then
        plan_line plan.link "$src" "$dst"
        return 0
    fi
    ln -sfn "$src" "$dst"
    say success link.ok "$src" "$dst"
    return 0
}

# remove_path <path>：存在才移除（dry-run 只打印计划）
remove_path() {
    if [[ ! -e $1 && ! -L $1 ]]; then
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        plan_line plan.remove "$1"
        return 0
    fi
    rm -f "$1"
    return 0
}

# remove_tree <path>
remove_tree() {
    if [[ ! -e $1 ]]; then
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        plan_line plan.remove "$1"
        return 0
    fi
    rm -rf "$1"
    return 0
}

# read_state <key>：读取状态文件字段到 STATE_VALUE；缺失返回 1
read_state() {
    local line
    STATE_VALUE=''
    [[ -f $STATE_FILE ]] || return 1
    while IFS= read -r line; do
        case $line in
            "$1"=*)
                STATE_VALUE=${line#*=}
                return 0
                ;;
        esac
    done < "$STATE_FILE"
    return 1
}

# write_state <action>：原子写 .install_state，并刷新旧契约 .repo_root/.last_update
write_state() {
    local action=$1
    local commit=''
    local tmp
    if [[ $DRY_RUN -eq 1 ]]; then
        return 0
    fi
    mkdir -p "$MOD_DIR"
    commit=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null) || commit=''
    [[ -n $commit ]] || commit='unknown'
    tmp="$STATE_FILE.tmp.$$"
    {
        printf '%s\n' "version=$VERSION"
        printf '%s\n' "installed_at=$(date '+%Y-%m-%d %H:%M:%S')"
        printf '%s\n' "repo=$SCRIPT_DIR"
        printf '%s\n' "commit=$commit"
        printf '%s\n' "lang=$TEXT_LANG"
        printf '%s\n' "modules=$MODULES_CSV"
        printf '%s\n' "last_action=$action"
        printf '%s\n' "conflicts=$CONFLICTS_CSV"
    } > "$tmp"
    mv "$tmp" "$STATE_FILE"
    printf '%s\n' "$SCRIPT_DIR" > "$REPO_ROOT_FILE"
    date > "$LAST_UPDATE_FILE"
    return 0
}

# ===================== L5 领域操作 =====================

# collect_repo_modules：收集仓库侧模块（脚本目录下的 bashrc.d/）
collect_repo_modules() {
    local f
    local src="$SCRIPT_DIR/$MOD_NAME"
    MODULES=()
    [[ -d $src ]] || return 0
    for f in "$src"/*; do
        [[ -f $f ]] || continue
        MODULES+=("$f")
    done
    return 0
}

list_modules() {
    local i=0
    local f name
    _msg modules.list_title
    printf '%s\n' "${MSG_TEXT}"
    while (( i < ${#MODULES[@]} )); do
        f=${MODULES[i]}
        name=$(basename "$f")
        printf '  %2d) %s\n' "$(( i + 1 ))" "$name"
        i=$(( i + 1 ))
    done
    return 0
}

select_all() {
    SELECTED=("${MODULES[@]}")
    return 0
}

select_by_arg() {
    local spec=$1
    local part rest found f name
    SELECTED=()
    rest=$spec
    while [[ -n $rest ]]; do
        part=${rest%%,*}
        if [[ $rest == *,* ]]; then
            rest=${rest#*,}
        else
            rest=''
        fi
        [[ -n $part ]] || continue
        found=0
        for f in "${MODULES[@]}"; do
            name=$(basename "$f")
            if [[ $name == "$part" ]]; then
                SELECTED+=("$f")
                found=1
                break
            fi
        done
        if [[ $found -eq 0 ]]; then
            die 2 modules.unknown_name "$part"
        fi
    done
    return 0
}

select_numeric() {
    local sel c f name
    local -a parts
    if [[ $NONINTERACTIVE -eq 1 || ! -t 0 ]]; then
        say warn select.notty
        select_all
        return 0
    fi
    list_modules
    _msg select.numeric_prompt
    printf '%s\n' "${MSG_TEXT}"
    if ! read -r sel; then
        sel=''
    fi
    sel=${sel//[ ]/}
    if [[ -z $sel ]]; then
        return 0
    fi
    if [[ $sel == all || $sel == ALL ]]; then
        select_all
        return 0
    fi
    SELECTED=()
    IFS=',' read -r -a parts <<< "$sel"
    for c in "${parts[@]}"; do
        [[ -n $c ]] || continue
        if [[ $c =~ ^[0-9]+$ ]] && (( 10#$c >= 1 && 10#$c <= ${#MODULES[@]} )); then
            SELECTED+=("${MODULES[$(( 10#$c - 1 ))]}")
        else
            say warn select.numeric_invalid "$c"
        fi
    done
    return 0
}

select_tui() {
    local dlg fz
    if [[ ! -t 0 || ! -t 1 ]]; then
        say warn select.notty
        select_all
        return 0
    fi
    dlg=$(command -v dialog 2>/dev/null) || dlg=''
    fz=$(command -v fzf 2>/dev/null) || fz=''
    if [[ -n $dlg ]]; then
        local args=()
        local i=0 name choices si title
        while (( i < ${#MODULES[@]} )); do
            name=$(basename "${MODULES[i]}")
            args+=("$(( i + 1 ))" "$name" "on")
            i=$(( i + 1 ))
        done
        _msg select.tui_title
        title=$MSG_TEXT
        if ! choices=$("$dlg" --checklist "$title" 0 0 0 "${args[@]}" 3>&1 1>&2 2>&3); then
            say warn select.cancelled
            exit 1
        fi
        SELECTED=()
        for si in $choices; do
            [[ $si =~ ^[0-9]+$ ]] || continue
            (( 10#$si >= 1 && 10#$si <= ${#MODULES[@]} )) || continue
            SELECTED+=("${MODULES[$(( 10#$si - 1 ))]}")
        done
        return 0
    fi
    if [[ -n $fz ]]; then
        local list='' selected_lines line idx header i
        i=0
        while (( i < ${#MODULES[@]} )); do
            list+="$(( i + 1 ))) $(basename "${MODULES[i]}")"$'\n'
            i=$(( i + 1 ))
        done
        _msg select.tui_header
        header=$MSG_TEXT
        if ! selected_lines=$(printf '%s' "$list" | "$fz" -m --header "$header"); then
            say warn select.cancelled
            exit 1
        fi
        SELECTED=()
        while IFS= read -r line; do
            [[ -n $line ]] || continue
            idx=${line%%)*}
            idx=${idx//[ ]/}
            [[ $idx =~ ^[0-9]+$ ]] || continue
            (( 10#$idx >= 1 && 10#$idx <= ${#MODULES[@]} )) || continue
            SELECTED+=("${MODULES[$(( 10#$idx - 1 ))]}")
        done <<< "$selected_lines"
        return 0
    fi
    say warn select.no_tui_tool
    select_numeric
    return 0
}

# merge_module <upstream> <user_file>
# 只返回 0（成功/已处理）或 1（产生冲突）；调用方必须用 if / || 接住，
# 绝不能让它以非零状态出现在“简单命令”位置（set -e 会中断整个安装）。
merge_module() {
    local upstream=$1
    local user_file=$2
    local name base_dir backup_dir base_file base_src bak extra
    name=$(basename "$upstream")
    base_dir="$MOD_DIR/.base"
    backup_dir="$MOD_DIR/.backups"
    base_file="$base_dir/$name"
    bak="$backup_dir/${name}.user.$(stamp_now)"

    # 1) --overwrite-modules：直接以仓库版本覆盖
    if [[ $OVERWRITE_MODULES -eq 1 ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            plan_line plan.copy "$upstream" "$user_file"
            return 0
        fi
        mkdir -p "$base_dir"
        cp "$upstream" "$user_file"
        cp "$upstream" "$base_file"
        say success merge.forced "$name"
        return 0
    fi

    # 2) 新模块：直接安装
    if [[ ! -f $user_file ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            plan_line plan.copy "$upstream" "$user_file"
            return 0
        fi
        mkdir -p "$base_dir"
        cp "$upstream" "$user_file"
        cp "$upstream" "$base_file"
        say success merge.new "$name"
        return 0
    fi

    # 3) 与上游一致：已是最新
    if diff -q "$user_file" "$upstream" >/dev/null 2>&1; then
        if [[ $DRY_RUN -eq 0 ]]; then
            mkdir -p "$base_dir"
            cp "$upstream" "$base_file"
        fi
        say info merge.latest "$name"
        return 0
    fi

    # 4) 未改过检测：用户文件是上游的子集（没有任何上游所无的独有行）
    extra=$(comm -23 <(sort "$user_file") <(sort "$upstream") 2>/dev/null || true)
    if [[ -z $extra ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            plan_line plan.copy "$upstream" "$user_file"
            return 0
        fi
        mkdir -p "$base_dir"
        cp "$upstream" "$user_file"
        cp "$upstream" "$base_file"
        say success merge.subset "$name"
        return 0
    fi

    # 5) 用户确有个人改动 → 三方合并（user / base / upstream）
    base_src="$base_file"
    if [[ ! -f $base_src ]]; then
        if [[ $DRY_RUN -eq 0 ]]; then
            mkdir -p "$base_dir"
            cp "$upstream" "$base_src"
        fi
        base_src="$upstream"
    fi

    # 无 git：退化为“备份后覆盖”
    if ! command -v git >/dev/null 2>&1; then
        if [[ $DRY_RUN -eq 1 ]]; then
            plan_line plan.backup "$user_file" "$bak"
            plan_line plan.copy "$upstream" "$user_file"
            return 0
        fi
        mkdir -p "$backup_dir"
        cp "$user_file" "$bak"
        cp "$upstream" "$user_file"
        cp "$upstream" "$base_file"
        say warn merge.nogit "$name" "$bak"
        return 0
    fi

    # 有 git：三方合并。dry-run 时在临时副本上预演，预测是否冲突
    if [[ $DRY_RUN -eq 1 ]]; then
        local mu
        mu=$(mktemp)
        TMPFILES+=("$mu")
        cp "$user_file" "$mu"
        if git merge-file -L '用户' -L '基础' -L '上游' "$mu" "$base_src" "$upstream" >/dev/null 2>&1; then
            plan_line plan.merge "$name"
        else
            plan_line plan.merge_conflict "$name" "$name"
        fi
        return 0
    fi

    mkdir -p "$backup_dir"
    cp "$user_file" "$bak"
    if git merge-file -L '用户' -L '基础' -L '上游' "$user_file" "$base_file" "$upstream" >/dev/null 2>&1; then
        cp "$upstream" "$base_file"
        say success merge.ok "$name" "$bak"
        return 0
    fi

    # 冲突：还原为用户原版保证 shell 可用，合并结果另存供手动解决
    cp "$user_file" "$MOD_DIR/.merged_$name"
    cp "$bak" "$user_file"
    touch "$MOD_DIR/.conflict_$name"
    say error merge.conflict "$name" "$MOD_DIR/.merged_$name"
    say info merge.conflict_hint "$MOD_DIR/.merged_$name" "$user_file"
    { diff -U 2 "$bak" "$upstream" || true; } | sed -n '1,30p'
    return 1
}

# install_modules <skip_local 0|1>
install_modules() {
    local skip_local=$1
    local f name
    local src="$SCRIPT_DIR/$MOD_NAME"

    if [[ ! -d $src ]]; then
        say warn no.main "$src"
        return 0
    fi
    collect_repo_modules
    if (( ${#MODULES[@]} == 0 )); then
        say warn no.modules "$src"
        return 0
    fi

    case $SEL_MODE in
        arg)
            select_by_arg "$MODULES_SPEC"
            ;;
        numeric)
            select_numeric
            ;;
        tui)
            select_tui
            ;;
        *)
            say info modules.default_all "${#MODULES[@]}"
            select_all
            ;;
    esac

    if [[ $skip_local -eq 1 ]]; then
        local kept=()
        local i=0
        local n=${#SELECTED[@]}
        while (( i < n )); do
            f=${SELECTED[i]}
            name=$(basename "$f")
            if [[ $name != *.local.* ]]; then
                kept+=("$f")
            fi
            i=$(( i + 1 ))
        done
        SELECTED=("${kept[@]}")
    fi

    if (( ${#SELECTED[@]} == 0 )); then
        say warn modules.none_selected
        return 0
    fi

    if [[ $DRY_RUN -eq 0 ]]; then
        mkdir -p "$MOD_DIR"
    fi

    for f in "${SELECTED[@]}"; do
        name=$(basename "$f")
        MODULES_CSV="${MODULES_CSV:+$MODULES_CSV,}$name"
        if ! merge_module "$f" "$MOD_DIR/$name"; then
            HAS_CONFLICT=$(( HAS_CONFLICT + 1 ))
            CONFLICTS_CSV="${CONFLICTS_CSV:+$CONFLICTS_CSV,}$name"
        fi
    done
    return 0
}

# _link_one <file> <repo-file-name>：备份后软链（已正确则跳过）
_link_one() {
    local f=$1
    local src="$SCRIPT_DIR/$2"
    local cur=''
    if [[ -L $f ]]; then
        cur=$(readlink "$f") || cur=''
        if [[ $cur == "$src" ]]; then
            say info link.same "$f" "$src"
            return 0
        fi
    fi
    if [[ -f $f ]]; then
        backup_file "$f"
    else
        say info backup.none "$f"
    fi
    link_file "$src" "$f"
    return 0
}

link_rc_files() {
    _link_one "$RC_FILE" "$RC_NAME"
    _link_one "$PROFILE_FILE" "$PROFILE_NAME"
    return 0
}

# ===================== L6 动作 =====================

action_install() {
    say info repo.dir "$SCRIPT_DIR"
    link_rc_files
    install_modules 0
    write_state install
    if (( HAS_CONFLICT > 0 )); then
        say warn conflict_count "$HAS_CONFLICT"
        exit 4
    fi
    if [[ $DRY_RUN -eq 0 ]]; then
        say success install.done
        say info install.hint "source $RC_FILE"
    fi
    return 0
}

action_update() {
    say info repo.dir "$SCRIPT_DIR"
    say info update.start "$MOD_DIR"
    link_rc_files
    install_modules 1
    write_state update
    if (( HAS_CONFLICT > 0 )); then
        say warn conflict_count "$HAS_CONFLICT"
        exit 4
    fi
    if [[ $DRY_RUN -eq 0 ]]; then
        say success update.done
    fi
    return 0
}

# _restore_rc <file>：用最近一次安装时的备份恢复
_restore_rc() {
    local f=$1
    local bak=''
    newest_backup "$f.bak."*
    bak=$NEWEST
    if [[ -n $bak ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            plan_line plan.restore "$f" "$bak"
            return 0
        fi
        rm -f "$f"
        cp "$bak" "$f"
        say success uninstall.restore "$f" "$bak"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        remove_path "$f"
        return 0
    fi
    remove_path "$f"
    say warn uninstall.no_backup "$f"
    return 0
}

action_uninstall() {
    say info uninstall.start "$PROGRAM"
    _restore_rc "$RC_FILE"
    _restore_rc "$PROFILE_FILE"

    if [[ -d $MOD_DIR ]]; then
        local f name ubak
        collect_repo_modules
        for f in "${MODULES[@]}"; do
            name=$(basename "$f")
            [[ $name != *.local.* ]] || continue
            if [[ -f $MOD_DIR/$name ]]; then
                newest_backup "$MOD_DIR/.backups/${name}.user."*
                ubak=$NEWEST
                if [[ -n $ubak ]]; then
                    if [[ $DRY_RUN -eq 1 ]]; then
                        plan_line plan.restore "$MOD_DIR/$name" "$ubak"
                    else
                        cp "$ubak" "$MOD_DIR/$name"
                        say success uninstall.restore_user "$MOD_DIR/$name" "$ubak"
                    fi
                else
                    remove_path "$MOD_DIR/$name"
                    if [[ $DRY_RUN -eq 0 ]]; then
                        say info uninstall.remove_module "$MOD_DIR/$name"
                    fi
                fi
            fi
            remove_path "$MOD_DIR/.conflict_$name"
            remove_path "$MOD_DIR/.merged_$name"
        done
        remove_path "$REPO_ROOT_FILE"
        remove_path "$LAST_UPDATE_FILE"
        remove_path "$STATE_FILE"
        remove_tree "$MOD_DIR/.base"
    fi

    if [[ $DRY_RUN -eq 0 ]]; then
        say success uninstall.done
    fi
    return 0
}

# _check_link <path> <expected-target>：正常返回 0，问题返回 1
_check_link() {
    local f=$1
    local src=$2
    local cur=''
    if [[ ! -e $f && ! -L $f ]]; then
        sline status.rc_missing "$f"
        return 1
    fi
    if [[ ! -L $f ]]; then
        sline status.rc_notlink "$f"
        return 1
    fi
    cur=$(readlink "$f") || cur=''
    if [[ $cur == "$src" ]]; then
        sline status.rc_ok "$f" "$src"
        return 0
    fi
    sline status.rc_bad "$f" "$cur"
    return 1
}

action_status() {
    local problems=0

    if [[ ! -d $MOD_DIR && ! -e $RC_FILE && ! -L $RC_FILE ]]; then
        say warn status.not_installed "$STATE_FILE"
        return 1
    fi

    _msg status.title
    printf '%s\n' "${MSG_TEXT}"
    sline status.shell "bash $BASH_VERSION"

    if [[ -f $STATE_FILE ]]; then
        if read_state version; then
            sline status.version "$STATE_VALUE"
        fi
        if read_state installed_at; then
            sline status.at "$STATE_VALUE"
        fi
        if read_state last_action; then
            sline status.action "$STATE_VALUE"
        fi
        if read_state commit; then
            sline status.commit "$STATE_VALUE"
        fi
        if read_state repo; then
            sline status.repo "$STATE_VALUE"
        fi
    else
        # 旧版安装（无状态文件）只提示，不计为问题
        sline status.no_state "$STATE_FILE"
    fi

    if ! _check_link "$RC_FILE" "$SCRIPT_DIR/$RC_NAME"; then
        problems=$(( problems + 1 ))
    fi
    if ! _check_link "$PROFILE_FILE" "$SCRIPT_DIR/$PROFILE_NAME"; then
        problems=$(( problems + 1 ))
    fi

    # 模块：与仓库上游逐个比对
    local src="$SCRIPT_DIR/$MOD_NAME"
    local f name total=0 drift=0
    local drift_list=''
    if [[ -d $src && -d $MOD_DIR ]]; then
        for f in "$src"/*; do
            [[ -f $f ]] || continue
            name=$(basename "$f")
            total=$(( total + 1 ))
            if [[ ! -f $MOD_DIR/$name ]] || ! diff -q "$MOD_DIR/$name" "$f" >/dev/null 2>&1; then
                drift=$(( drift + 1 ))
                drift_list="${drift_list:+$drift_list }$name"
            fi
        done
        sline status.modules "$total" "$drift"
        if (( drift == 0 )); then
            sline status.modules_clean
        else
            # 与上游有差异通常是你的正常定制，仅提示、不计为问题
            sline status.drift_list "$drift_list"
        fi
    fi

    # 待处理冲突
    local conflicts=''
    local -a cfs=()
    mapfile -t cfs < <(compgen -G "$MOD_DIR/.conflict_*" || true)
    for f in "${cfs[@]}"; do
        [[ -e $f ]] || continue
        conflicts="${conflicts:+$conflicts }$(basename "$f")"
    done
    if [[ -n $conflicts ]]; then
        sline status.conflicts "$conflicts"
        problems=$(( problems + 1 ))
    else
        sline status.no_conflicts
    fi

    if (( problems == 0 )); then
        say success status.ok
        return 0
    fi
    say warn status.bad "$problems"
    return 1
}

# ===================== L7 参数解析与入口 =====================

parse_args() {
    local explicit=0
    while (( $# > 0 )); do
        case $1 in
            install|update|uninstall|status)
                if (( explicit )); then
                    die 2 bad.two_cmds "$ACTION" "$1"
                fi
                ACTION=$1
                explicit=1
                shift
                ;;
            preview)
                if (( explicit )); then
                    die 2 bad.two_cmds "$ACTION" "$1"
                fi
                DRY_RUN=1
                explicit=1
                shift
                case ${1:-} in
                    install|update|uninstall|status)
                        ACTION=$1
                        shift
                        ;;
                    *)
                        ACTION='install'
                        ;;
                esac
                ;;
            help|--help|-h)
                ACTION='help'
                shift
                ;;
            version|--version)
                ACTION='version'
                shift
                ;;
            --update)
                if (( explicit )); then
                    die 2 bad.two_cmds "$ACTION" "$1"
                fi
                ACTION='update'
                explicit=1
                shift
                ;;
            --uninstall)
                if (( explicit )); then
                    die 2 bad.two_cmds "$ACTION" "$1"
                fi
                ACTION='uninstall'
                explicit=1
                shift
                ;;
            --preview)
                DRY_RUN=1
                shift
                ;;
            --yes|--auto)
                NONINTERACTIVE=1
                shift
                ;;
            --tui)
                SEL_MODE='tui'
                shift
                ;;
            --select)
                SEL_MODE='numeric'
                shift
                ;;
            --modules)
                if (( $# < 2 )); then
                    die 2 bad.no_value "$1"
                fi
                MODULES_SPEC=$2
                SEL_MODE='arg'
                shift 2
                ;;
            --modules=*)
                MODULES_SPEC=${1#--modules=}
                SEL_MODE='arg'
                shift
                ;;
            --no-backup)
                NO_BACKUP=1
                shift
                ;;
            --overwrite-modules)
                OVERWRITE_MODULES=1
                shift
                ;;
            --force)
                NO_BACKUP=1
                OVERWRITE_MODULES=1
                shift
                ;;
            --lang)
                if (( $# < 2 )); then
                    die 2 bad.no_value "$1"
                fi
                LANG_OVERRIDE=$2
                shift 2
                ;;
            --lang=*)
                LANG_OVERRIDE=${1#--lang=}
                shift
                ;;
            --)
                shift
                ;;
            -*)
                die 2 bad.unknown_opt "$1"
                ;;
            *)
                die 2 bad.unknown_subcmd "$1"
                ;;
        esac
    done
    return 0
}

preflight() {
    if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
        die 3 bad.source
    fi
    SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) || die 3 bad.missing_dir "$(dirname "${BASH_SOURCE[0]}")"
    if [[ ! -f $SCRIPT_DIR/$RC_NAME ]]; then
        die 3 bad.missing_main "$SCRIPT_DIR/$RC_NAME"
    fi
    return 0
}

main() {
    parse_args "$@"
    init_colors
    init_lang

    case $ACTION in
        help)
            show_help
            return 0
            ;;
        version)
            show_version
            return 0
            ;;
    esac

    preflight

    if [[ $DRY_RUN -eq 1 ]]; then
        say info preview.banner
    fi

    case $ACTION in
        install)
            action_install
            ;;
        update)
            action_update
            ;;
        uninstall)
            action_uninstall
            ;;
        status)
            action_status
            ;;
    esac

    if [[ $DRY_RUN -eq 1 ]]; then
        say info preview.done
    fi
    return 0
}

main "$@"
