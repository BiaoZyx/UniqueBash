#!/usr/bin/env bash
# ============================================================
# UniqueBash Setup Script
# 一键安装 UniqueBash 配置到 ~/.bashrc
# ============================================================
# 使用方法：
#   ./setup.sh          # 正常安装（自动备份）
#   ./setup.sh --force  # 强制覆盖（不备份）
#   ./setup.sh --help   # 显示帮助
# ============================================================

set -e  # 遇到错误立即退出
shopt -s extglob

# ---------- 颜色输出 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info()  { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✔${NC} $1"; }
print_warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✘${NC} $1"; }

# ---------- 帮助信息 ----------
show_help() {
    cat << EOF
UniqueBash 安装脚本

用法:
  ./setup.sh [选项]

选项:
  --force      强制覆盖现有 ~/.bashrc（不备份）
  --help       显示此帮助信息
  --preview    预览将要执行的变更（不写盘）
  --tui        使用 TUI 选择界面（优先使用 dialog，其次 fzf）
  --update     用仓库默认模块更新 ~/.bashrc.d（自动备份，跳过 *.local.*）
  --uninstall  卸载：依据备份恢复 ~/.bashrc / ~/.bash_profile 并移除默认模块
  --version    显示版本号

 默认行为:
   自动备份现有的 ~/.bashrc 到 ~/.bashrc.bak.YYYYMMDD_HHMMSS
   然后将 main.bashrc 软链接到 ~/.bashrc
   并确保仓库中的 bashrc.d 移动到 ~/.bashrc.d 并备份 ~/.bashrc.d 到 ~/.bashrc.d.bak.YYYYMMDD_HHMMSS/

 示例:
   ./setup.sh            # 正常安装
   ./setup.sh --force    # 强制覆盖，不备份
   ./setup.sh --preview  # 预览将要执行的操作（不改动文件）
   ./setup.sh --tui      # 使用 TUI 界面选择模块（如果可用）
   ./setup.sh --update   # 更新已安装的默认模块
   ./setup.sh --uninstall # 卸载并恢复备份

EOF
}

# ---------- 卸载：依据备份恢复 ----------
do_uninstall() {
    print_info "开始卸载 UniqueBash..."

    # 恢复 ~/.bashrc
    local bak
    bak=$(ls -t "$HOME"/.bashrc.bak.* 2>/dev/null | head -1) || true
    if [[ -n "$bak" ]]; then
        rm -f "$HOME/.bashrc"
        cp "$bak" "$HOME/.bashrc"
        print_success "已恢复 ~/.bashrc <- $bak"
    else
        rm -f "$HOME/.bashrc"
        print_warn "未找到 ~/.bashrc 备份，已移除软链接。"
    fi

    # 恢复 ~/.bash_profile
    bak=$(ls -t "$HOME"/.bash_profile.bak.* 2>/dev/null | head -1) || true
    if [[ -n "$bak" ]]; then
        rm -f "$HOME/.bash_profile"
        cp "$bak" "$HOME/.bash_profile"
        print_success "已恢复 ~/.bash_profile <- $bak"
    else
        rm -f "$HOME/.bash_profile"
        print_warn "未找到 ~/.bash_profile 备份，已移除软链接。"
    fi

    # 移除由本仓库安装的默认模块，保留用户自定义文件（*.local.*）
    # 若用户曾修改过，则从 .backups 恢复其最后一个版本
    if [[ -d "$HOME/.bashrc.d" ]]; then
        local f name ubak
        for f in "$SCRIPT_DIR/bashrc.d"/*; do
            [[ -f "$f" ]] || continue
            name=$(basename "$f")
            [[ "$name" == *.local.* ]] && continue
            if [[ -f "$HOME/.bashrc.d/$name" ]]; then
                ubak=$(ls -t "$HOME/.bashrc.d/.backups/${name}.user."* 2>/dev/null | head -1) || true
                if [[ -n "$ubak" ]]; then
                    cp "$ubak" "$HOME/.bashrc.d/$name"
                    print_success "已恢复 ~/.bashrc.d/$name <- $ubak（你的修改版本）"
                else
                    rm -f "$HOME/.bashrc.d/$name"
                    print_info "已移除默认模块 ~/.bashrc.d/$name"
                fi
            fi
            # 清理本仓库生成的辅助文件
            rm -f "$HOME/.bashrc.d/.conflict_$name" "$HOME/.bashrc.d/.merged_$name"
        done
        rm -f "$HOME/.bashrc.d/.repo_root" "$HOME/.bashrc.d/.last_update"
        rm -rf "$HOME/.bashrc.d/.base"
    fi

    print_success "卸载完成。个人自定义文件（*.local.*）已保留。"
}

# ---------- 智能差异融合更新 ----------
# 三方合并：用户版本(user) / 基础版本(base) / 上游版本(upstream)
# 思想：base 记录“上次安装时的上游版本”，据此判断用户是否改过；
#       用户未改 -> 直接覆盖为上游；用户改过 -> git merge-file 融合；
#       冲突时保留可用版本，并生成带冲突标记的 .merged 文件供手动解决。
merge_module() {
    local upstream="$1"
    local user_file="$2"
    local name
    name=$(basename "$upstream")
    local base_dir="$HOME/.bashrc.d/.base"
    local backup_dir="$HOME/.bashrc.d/.backups"
    local base_file="$base_dir/$name"

    mkdir -p "$base_dir" "$backup_dir"

    # 新模块：直接安装
    if [[ ! -f "$user_file" ]]; then
        cp "$upstream" "$user_file"
        cp "$upstream" "$base_file"
        print_success "已安装 $name（新模块）"
        return 0
    fi

    # 与上游完全一致：已是最新
    if diff -q "$user_file" "$upstream" >/dev/null 2>&1; then
        cp "$upstream" "$base_file"
        print_info "$name 已是最新，无需改动"
        return 0
    fi

    # 首次跟踪：以当前上游作为基线
    if [[ ! -f "$base_file" ]]; then
        cp "$upstream" "$base_file"
    fi

    # 用户未修改（与基线相同）：直接更新
    if diff -q "$user_file" "$base_file" >/dev/null 2>&1; then
        cp "$upstream" "$user_file"
        cp "$upstream" "$base_file"
        print_success "已更新 $name"
        return 0
    fi

    # 用户有修改：尝试三方合并
    if ! command -v git >/dev/null 2>&1; then
        # 无 git：退化为“备份后覆盖”，旧版保留在 .backups 供手动恢复
        local bak="$backup_dir/${name}.user.$(date +%Y%m%d_%H%M%S)"
        cp "$user_file" "$bak"
        cp "$upstream" "$user_file"
        cp "$upstream" "$base_file"
        print_warn "$name 已更新（未检测到 git，无法三方合并；旧版备份于 $bak）"
        return 0
    fi

    local bak="$backup_dir/${name}.user.$(date +%Y%m%d_%H%M%S)"
    cp "$user_file" "$bak"
    if git merge-file -L "用户" -L "基础" -L "上游" "$user_file" "$base_file" "$upstream" >/dev/null 2>&1; then
        cp "$upstream" "$base_file"
        print_success "已合并 $name（你的修改已保留，备份: $bak）"
    else
        # 冲突：还原为用户原版以保证 shell 可用，合并结果供手动解决
        cp "$user_file" "$HOME/.bashrc.d/.merged_$name"
        cp "$bak" "$user_file"
        touch "$HOME/.bashrc.d/.conflict_$name"
        print_error "$name 合并冲突！已保留你的可用版本；冲突合并结果在 ~/.bashrc.d/.merged_$name"
        print_info "解决后执行：cp ~/.bashrc.d/.merged_$name ~/.bashrc.d/$name"
        diff -U 2 "$bak" "$upstream" | head -30
        return 1
    fi
}

# ---------- 参数解析 ----------
FORCE=0
NONINTERACTIVE=0
PREVIEW=0
TUI_FORCE=0
UPDATE=0
UNINSTALL=0
while [[ $# -gt 0 ]]; do
    case $1 in
        --force) FORCE=1; shift ;;
        --help)  show_help; exit 0 ;;
        --version) echo "UniqueBash setup v3.2"; exit 0 ;;
        --yes|--auto) NONINTERACTIVE=1; shift ;;
        --preview) PREVIEW=1; shift ;;
        --tui) TUI_FORCE=1; shift ;;
        --update) UPDATE=1; shift ;;
        --uninstall) UNINSTALL=1; shift ;;
        *) print_error "未知选项: $1"; show_help; exit 1 ;;
    esac
done

# ---------- 获取脚本所在目录 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------- 预览优先（不写盘） ----------
if [[ $PREVIEW -eq 1 ]]; then
    echo "Preview mode: the following actions would be performed:"
    if [[ -f "$HOME/.bashrc" && $FORCE -eq 0 ]]; then
        echo "  BACKUP: $HOME/.bashrc -> $HOME/.bashrc.bak.YYYYMMDD_HHMMSS"
    fi
    echo "  LINK: $SCRIPT_DIR/main.bashrc -> $HOME/.bashrc"
    if [[ -f "$HOME/.bash_profile" && $FORCE -eq 0 ]]; then
        echo "  BACKUP: $HOME/.bash_profile -> $HOME/.bash_profile.bak.YYYYMMDD_HHMMSS"
    fi
    echo "  LINK: $SCRIPT_DIR/startup.bash_profile -> $HOME/.bash_profile"
    if [[ -d "$SCRIPT_DIR/bashrc.d" ]]; then
        for f in "$SCRIPT_DIR/bashrc.d"/*; do
            [[ -f "$f" ]] || continue
            name=$(basename "$f"); dest="$HOME/.bashrc.d/$name"
            [[ -f "$dest" ]] && echo "  BACKUP: $dest -> $dest.bak.YYYYMMDD_HHMMSS"
            echo "  COPY: $f -> $dest"
        done
    fi
    echo "Preview complete. No files were modified."
    exit 0
fi

# ---------- 卸载优先 ----------
if [[ $UNINSTALL -eq 1 ]]; then
    do_uninstall
    exit 0
fi

print_info "UniqueBash 安装目录: $SCRIPT_DIR"

# ---------- 语言检测（中/英） ----------
LANG_SHORT=${LANG:-}
if [[ "$LANG_SHORT" == zh* || "$LC_ALL" == zh* || "$LC_MESSAGES" == zh* ]]; then
    MSG_YES="是"
    MSG_NO="否"
    MSG_RECOMMEND_ALL="首次安装建议选择全装（推荐）"
else
    MSG_YES="Yes"
    MSG_NO="No"
    MSG_RECOMMEND_ALL="For first-time installation it's recommended to install all modules (recommended)"
fi

# ---------- 检测 TUI 工具 ----------
DIALOG_BIN=$(command -v dialog 2>/dev/null || true)
FZF_BIN=$(command -v fzf 2>/dev/null || true)
if [[ -n "$DIALOG_BIN" ]]; then
    TUI_BACKEND=dialog
elif [[ -n "$FZF_BIN" ]]; then
    TUI_BACKEND=fzf
else
    TUI_BACKEND=none
fi

# ---------- 检查必要文件 ----------
if [[ ! -f "$SCRIPT_DIR/main.bashrc" ]]; then
    print_error "找不到 main.bashrc，请确认你在 UniqueBash 仓库根目录运行此脚本。"
    exit 1
fi

if [[ ! -d "$SCRIPT_DIR/bashrc.d" ]]; then
    print_warn "bashrc.d 目录不存在，跳过模块加载。"
fi

# ---------- 备份现有的 ~/.bashrc ----------
if [[ -f "$HOME/.bashrc" ]]; then
    if [[ $FORCE -eq 1 ]]; then
        print_warn "强制安装：将覆盖 ~/.bashrc（不备份）"
    else
        BACKUP_FILE="$HOME/.bashrc.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$HOME/.bashrc" "$BACKUP_FILE"
        print_success "已备份到: $BACKUP_FILE"
    fi
else
    print_info "~/.bashrc 不存在，将创建新文件。"
fi

# ---------- 链接 ~/.bashrc 到 main.bashrc ----------
# 使用软链接，方便更新
if [[ -L "$HOME/.bashrc" ]]; then
    rm "$HOME/.bashrc"
    print_info "移除旧的软链接 ~/.bashrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    rm "$HOME/.bashrc"
fi

ln -s "$SCRIPT_DIR/main.bashrc" "$HOME/.bashrc"
print_success "已链接 ~/.bashrc -> main.bashrc"

# ---------- 备份现有的 ~/.bash_profile ----------
if [[ -f "$HOME/.bash_profile" ]]; then
    if [[ $FORCE -eq 1 ]]; then
        print_warn "强制安装：将覆盖 ~/.bash_profile（不备份）"
    else
        BACKUP_FILE="$HOME/.bash_profile.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$HOME/.bash_profile" "$BACKUP_FILE"
        print_success "已备份到: $BACKUP_FILE"
    fi
else
    print_info "~/.bash_profile 不存在，将创建新文件。"
fi

# ---------- 链接 ~/.bash_profile 到 startup.bash_profile ----------
# 使用软链接，方便更新
if [[ -L "$HOME/.bash_profile" ]]; then
    rm "$HOME/.bash_profile"
    print_info "移除旧的软链接 ~/.bash_profile"
elif [[ -f "$HOME/.bash_profile" ]]; then
    rm "$HOME/.bash_profile"
fi

ln -s "$SCRIPT_DIR/startup.bash_profile" "$HOME/.bash_profile"
print_success "已链接 ~/.bash_profile -> startup.bash_profile"

# ---------- 复制 bashrc.d/* 到 ~/bashrc.d/ ----------
if [[ -d "$SCRIPT_DIR/bashrc.d" ]]; then
    # 交互选择安装哪些模块
    mkdir -p "$HOME/.bashrc.d"

    mapfile -t MODULES < <(ls -1 "$SCRIPT_DIR/bashrc.d"/* 2>/dev/null || true)
    if [[ ${#MODULES[@]} -eq 0 ]]; then
        print_warn "bashrc.d 目录为空，跳过模块安装。"
    else
        print_info "检测到以下模块："
        for i in "${!MODULES[@]}"; do
            f=${MODULES[$i]}
            name=$(basename "$f")
            printf "  %2d) %s\n" $((i+1)) "$name"
        done

        # --update：跳过交互选择，直接安装全部默认模块（保留 *.local.*）
        if [[ $UPDATE -eq 1 ]]; then
            SELECTED_MODULES=()
            for f in "${MODULES[@]}"; do
                name=$(basename "$f")
                [[ "$name" == *.local.* ]] && continue
                SELECTED_MODULES+=("$f")
            done
        else
            # 决定是否使用 TUI，优先尊重 --tui
            USE_TUI=0
            if [[ $TUI_FORCE -eq 1 ]]; then
                if [[ "$TUI_BACKEND" == "none" ]]; then
                    print_warn "未检测到 dialog/fzf，无法使用 TUI，回退到交互式输入。"
                else
                    USE_TUI=1
                fi
            else
                if [[ "$TUI_BACKEND" != "none" && $NONINTERACTIVE -eq 0 ]]; then
                    printf "是否使用交互式 TUI 选择模块？ [%s/%s] (默认 %s): " "$MSG_YES" "$MSG_NO" "$MSG_YES"
                    read -r use_tui_ans
                    use_tui_ans=${use_tui_ans:-Y}
                    if [[ "$use_tui_ans" =~ ^[YyY一] ]]; then
                        USE_TUI=1
                    fi
                fi
            fi

            # 如果非交互模式则默认全装
            if [[ $NONINTERACTIVE -eq 1 ]]; then
                SELECTED_MODULES=("${MODULES[@]}")
            else
                if [[ $USE_TUI -eq 1 ]]; then
                    # 使用 dialog 或 fzf
                    if [[ "$TUI_BACKEND" == "dialog" ]]; then
                        # 准备 checklist 参数：tag item status
                        tmpfile=$(mktemp)
                        dialog_args=()
                        for i in "${!MODULES[@]}"; do
                            tag=$((i+1))
                            name=$(basename "${MODULES[$i]}")
                            dialog_args+=("$tag" "$name" "off")
                        done
                        choices=$($DIALOG_BIN --checklist "选择要安装的模块（空格选择）" 0 0 0 "${dialog_args[@]}" 3>&1 1>&2 2>&3)
                        rm -f "$tmpfile" || true
                        # choices like "1 3 4"
                        read -ra sel_idx <<< "$choices"
                        SELECTED_MODULES=()
                        for si in "${sel_idx[@]}"; do
                            if [[ "$si" =~ ^[0-9]+$ ]]; then
                                SELECTED_MODULES+=("${MODULES[$((si-1))]}")
                            fi
                        done
                    elif [[ "$TUI_BACKEND" == "fzf" ]]; then
                        # 输出带编号的列表供 fzf 多选
                        list=$(for i in "${!MODULES[@]}"; do printf "%2d) %s\n" $((i+1)) "$(basename "${MODULES[$i]}")"; done)
                        selected_lines=$(printf "%s" "$list" | $FZF_BIN -m --header='Select modules (multiple)') || true
                        SELECTED_MODULES=()
                        while IFS= read -r line; do
                            idx=$(echo "$line" | awk -F')' '{print $1}' | tr -d ' ')
                            if [[ "$idx" =~ ^[0-9]+$ ]]; then
                                SELECTED_MODULES+=("${MODULES[$((idx-1))]}")
                            fi
                        done <<< "$selected_lines"
                    else
                        print_warn "未知的 TUI 后端，回退到数字选择。"
                    fi
                else
                    # 非 TUI 数字/全装选择
                    printf "\n%s [Y/n] (默认 Y): " "$MSG_RECOMMEND_ALL"
                    read -r ans
                    ans=${ans:-Y}
                    if [[ "$ans" =~ ^[YyY一] ]]; then
                        SELECTED_MODULES=("${MODULES[@]}")
                    else
                        while true; do
                            printf "输入要安装的模块编号（逗号分隔），或输入 all 完全安装，或空回车结束: "
                            read -r sel
                            sel=${sel// /}
                            if [[ -z "$sel" ]]; then
                                break
                            fi
                            if [[ "$sel" == "all" || "$sel" == "ALL" ]]; then
                                SELECTED_MODULES=("${MODULES[@]}")
                                break
                            fi
                            IFS=',' read -ra choices <<< "$sel"
                            for c in "${choices[@]}"; do
                                if [[ "$c" =~ ^[0-9]+$ ]] && (( c>=1 && c<=${#MODULES[@]} )); then
                                    SELECTED_MODULES+=("${MODULES[$((c-1))]}")
                                else
                                    print_warn "无效编号: $c"
                                fi
                            done
                        done
                    fi
                fi
            fi
        fi

        # 执行安装 / 更新（智能差异融合，保留用户修改）
        for f in "${SELECTED_MODULES[@]}"; do
            merge_module "$f" "$HOME/.bashrc.d/$(basename "$f")"
        done
        # 记录仓库路径与更新时间，供 ub-update / ub-status 使用
        echo "$SCRIPT_DIR" > "$HOME/.bashrc.d/.repo_root"
        date > "$HOME/.bashrc.d/.last_update"
    fi
else
    print_warn "bashrc.d 不存在，跳过模块目录链接。"
fi

# ---------- 加载新配置 ----------
print_info "正在加载新配置..."
# 尝试在当前 shell 加载，但这可能影响执行环境
if [[ $NONINTERACTIVE -eq 0 ]]; then
    # 仅在交互模式下尝试 source
    if [[ $- == *i* ]]; then
        # shell 是交互的，source main.bashrc
        # shellcheck source=/dev/null
        source "$HOME/.bashrc"
    else
        print_info "当前为非交互 shell，跳过即时加载。请打开新终端以应用配置。"
    fi
else
    print_info "非交互安装模式，不在当前 shell 中加载配置。"
fi

# ---------- 完成 ----------
echo ""
print_success "UniqueBash 安装完成！"
echo ""
echo "提示："
echo "  1. 新终端将自动加载新配置。"
echo "  2. 如果遇到问题，可恢复备份文件。"
echo "  3. 查看帮助: ./setup.sh --help"
echo ""
