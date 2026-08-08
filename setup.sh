#!/bin/env bash
#!/bin/bash
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
  --force    强制覆盖现有 ~/.bashrc（不备份）
  --help     显示此帮助信息
  --preview  预览将要执行的变更（不写盘）
  --tui      使用 TUI 选择界面（优先使用 dialog，其次 fzf）
  --version  显示版本号

默认行为:
  自动备份现有的 ~/.bashrc 到 ~/.bashrc.bak.YYYYMMDD_HHMMSS
  然后将 main.bashrc 软链接到 ~/.bashrc
  并确保仓库中的 bashrc.d 移动到 ~/.bashrc.d 并备份 ~/.bashrc.d 到 ~/.bashrc.d.bak.YYYYMMDD_HHMMSS/ 

示例:
  ./setup.sh            # 正常安装
  ./setup.sh --force    # 强制覆盖，不备份
  ./setup.sh --preview  # 预览将要执行的操作（不改动文件）
  ./setup.sh --tui      # 使用 TUI 界面选择模块（如果可用）

EOF
}

# ---------- 参数解析 ----------
FORCE=0
NONINTERACTIVE=0
PREVIEW=0
TUI_FORCE=0
while [[ $# -gt 0 ]]; do
    case $1 in
        --force) FORCE=1; shift ;;
        --help)  show_help; exit 0 ;;
        --version) echo "UniqueBash setup v3.2"; exit 0 ;;
        --yes|--auto) NONINTERACTIVE=1; shift ;;
        --preview) PREVIEW=1; shift ;;
        --tui) TUI_FORCE=1; shift ;;
        *) print_error "未知选项: $1"; show_help; exit 1 ;;
    esac
done

# ---------- 获取脚本所在目录 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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

# ---------- 链接 ~/.bashrc.d 到 bashrc.d ----------
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
                    if [[ $PREVIEW -eq 1 ]]; then
                        # preview: show list then exit
                        dialog --title "Preview: modules" --msgbox "将预览所选模块（仅显示，未执行）" 6 50
                    fi
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

        # 预览模式：仅显示将执行的操作
        if [[ $PREVIEW -eq 1 ]]; then
            echo "\nPreview mode: the following actions would be performed:" 
            for f in "${SELECTED_MODULES[@]}"; do
                name=$(basename "$f")
                dest="$HOME/.bashrc.d/$name"
                if [[ -f "$dest" ]]; then
                    echo "  BACKUP: $dest -> $dest.bak.YYYYMMDD_HHMMSS"
                fi
                echo "  COPY: $f -> $dest"
            done
            echo "\nPreview complete. No files were modified."
            exit 0
        fi

        # 执行安装（复制并备份目标已存在文件）
        for f in "${SELECTED_MODULES[@]}"; do
            dest="$HOME/.bashrc.d/$(basename "$f")"
            if [[ -f "$dest" ]]; then
                bak="$dest.bak.$(date +%Y%m%d_%H%M%S)"
                cp "$dest" "$bak"
                print_warn "已备份 $dest -> $bak"
            fi
            cp "$f" "$dest"
            print_success "已安装 $(basename "$f")"
        done
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
