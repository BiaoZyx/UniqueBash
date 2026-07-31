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
  --force   强制覆盖现有 ~/.bashrc（不备份）
  --help    显示此帮助信息
  --version 显示版本号

默认行为:
  自动备份现有的 ~/.bashrc 到 ~/.bashrc.bak.YYYYMMDD_HHMMSS
  然后将 main.bashrc 软链接到 ~/.bashrc
  并确保 ~/.bashrc.d 链接到仓库中的 bashrc.d/ 目录

示例:
  ./setup.sh          # 正常安装
  ./setup.sh --force  # 强制覆盖，不备份

EOF
}

# ---------- 参数解析 ----------
FORCE=0
while [[ $# -gt 0 ]]; do
    case $1 in
        --force) FORCE=1; shift ;;
        --help)  show_help; exit 0 ;;
        --version) echo "UniqueBash setup v3.2"; exit 0 ;;
        *) print_error "未知选项: $1"; show_help; exit 1 ;;
    esac
done

# ---------- 获取脚本所在目录 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

print_info "UniqueBash 安装目录: $SCRIPT_DIR"

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
    # 如果是软链接，先删除
    rm "$HOME/.bashrc"
    print_info "移除旧的软链接 ~/.bashrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    # 如果是普通文件，在非 force 模式下已经备份，这里覆盖
    rm "$HOME/.bashrc"
fi

ln -s "$SCRIPT_DIR/main.bashrc" "$HOME/.bashrc"
print_success "已链接 ~/.bashrc -> main.bashrc"

# ---------- 链接 ~/.bashrc.d 到 bashrc.d ----------
if [[ -d "$SCRIPT_DIR/bashrc.d" ]]; then
    if [[ -L "$HOME/.bashrc.d" ]]; then
        rm "$HOME/.bashrc.d"
    elif [[ -e "$HOME/.bashrc.d" ]]; then
        # 如果存在文件或目录，备份
        mv "$HOME/.bashrc.d" "$HOME/.bashrc.d.bak.$(date +%Y%m%d_%H%M%S)"
        print_warn "已备份原有的 ~/.bashrc.d"
    fi
    ln -s "$SCRIPT_DIR/bashrc.d" "$HOME/.bashrc.d"
    print_success "已链接 ~/.bashrc.d -> bashrc.d"
else
    print_warn "bashrc.d 不存在，跳过模块目录链接。"
fi

# ---------- 加载新配置 ----------
print_info "正在加载新配置..."
source "$HOME/.bashrc"

# ---------- 完成 ----------
echo ""
print_success "UniqueBash 安装完成！"
echo ""
echo "提示："
echo "  1. 新终端将自动加载新配置。"
echo "  2. 如果遇到问题，可恢复备份文件。"
echo "  3. 查看帮助: ./setup.sh --help"
echo ""