# =========================
#   __
#  / _|_  _ _ _  __
# |  _| || | ' \/ _|
# |_|  \_,_|_||_\__|
# (~/.bashrc.d/func.bashrc)
# =========================

# 处理命令未找到的情况
command_not_found_handle() {
    local cmd="$1"
    shift

    # 如果是纯数字，尝试目录栈跳转
    if [[ "$cmd" =~ ^[0-9]+$ ]]; then
        if builtin pushd "+$cmd" >/dev/null 2>/dev/null; then
            _build_prompt
            return 0
        else
            local lang="${LANG:0:2}"
            local errmsg
            case "$lang" in
                zh) errmsg="目录栈中没有编号 $cmd" ;;
                es) errmsg="No hay directorio con índice $cmd en la pila" ;;
                *)  errmsg="No directory with index $cmd in stack" ;;
            esac
            echo -e "\033[1;31m$errmsg\033[0m" >&2
            return 1
        fi
    fi

    # 根据 LANG 选择语言（只取前两位，如 zh, en, es...）
    local lang="${LANG:0:2}"
    case "$lang" in
        zh)
            # 中文提示
            local guess_msg="[?] 你是不是想输入 '%s'？"
            local insults=(
                "[!] '%s'？这玩意儿不存在。"
                "[;] 要是这命令能用，我当场吃键盘。"
                "[*] 你输入了 '%s'，但魔法书里没这页。"
                "[X] '%s': 命令未找到... 默哀。"
                "[o] 你是在召唤克苏鲁吗？'%s' 可不是咒语。"
                "[#] 不，'%s' 不在我的词典里。"
            )
            ;;
        es)
            # 西班牙语
            local guess_msg="[?] ¿Quisiste decir '%s'?"
            local insults=(
                "[!] '%s'? Eso no existe aquí."
                "[;] Si ese comando existiera, me comería el teclado."
                "[*] Escribiste '%s', pero el libro de hechizos no tiene esa página."
                "[X] '%s': comando no encontrado... RIP."
                "[o] ¿Estás invocando a Cthulhu? '%s' no es eso."
                "[#] No. '%s' no está en mi diccionario."
            )
            ;;
        *)
            # 默认英文（fallback）
            local guess_msg="[?] Did you mean '%s'?"
            local insults=(
                "[!] '%s'? That's not a thing here."
                "[;] If that command existed, I'd eat my keyboard."
                "[*] You typed '%s', but the spellbook has no such incantation."
                "[X] '%s': command not found... RIP."
                "[o] Are you trying to summon Cthulhu? Because '%s' ain't it."
                "[#] Nope. '%s' is not in my dictionary."
            )
            ;;
    esac

    # 猜测命令（基于可用命令名，避免扫描整个历史带来的开销）
    local guess
    guess=$(compgen -c 2>/dev/null | grep -E "^.{0,2}${cmd}.{0,2}$" | head -1)
    if [[ -n "$guess" && "$guess" != "$cmd" ]]; then
        printf "\033[1;33m${guess_msg}\033[0m\n" "$guess"
    else
        local idx=$(( RANDOM % ${#insults[@]} ))
        # 注意 insults 里用 %s 占位，这里要传入 cmd
        printf "\033[1;31m${insults[$idx]}\033[0m\n" "$cmd"
    fi
    return 127
}

mkcd() {    # 创建目录并进入该目录
  if [[ -z "$1" ]]; then
    echo "Usage: mkcd <dir>"
    return 1
  fi
  mkdir -p "$1" && cd "$1"
}

# ---------- UniqueBash 更新与状态工具 ----------
# 依赖 setup.sh 在安装/更新时写入的 ~/.bashrc.d/.repo_root 与 .install_state
ub-update() {
    local root
    root=$(cat "$HOME/.bashrc.d/.repo_root" 2>/dev/null)
    if [[ -z "$root" || ! -f "$root/setup.sh" ]]; then
        echo "无法确定 UniqueBash 仓库路径，请重新运行 ./setup.sh" >&2
        return 1
    fi
    bash "$root/setup.sh" update
}

ub-status() {
    local d="$HOME/.bashrc.d"
    local root line
    echo "UniqueBash 已加载模块数: $(ls -1 "$d"/*.bashrc 2>/dev/null | wc -l)"
    # 状态文件（setup.sh >= 3.4 写入）
    if [[ -f "$d/.install_state" ]]; then
        while IFS= read -r line; do
            case "$line" in
                version=*)     echo "安装版本: ${line#version=}" ;;
                last_action=*) echo "上次动作: ${line#last_action=}" ;;
                commit=*)      echo "仓库提交: ${line#commit=}" ;;
            esac
        done < "$d/.install_state"
    fi
    if [[ -f "$d/.last_update" ]]; then
        echo "最后更新: $(cat "$d/.last_update")"
    else
        echo "最后更新: 从未"
    fi
    if ls "$d"/.conflict_* >/dev/null 2>&1; then
        echo "存在合并冲突，请处理:"
        ls "$d"/.conflict_*
    fi
    # 详细状态（软链指向 / 模块差异 / 退出码）
    root=$(cat "$d/.repo_root" 2>/dev/null)
    if [[ -n "$root" && -f "$root/setup.sh" ]]; then
        echo "详细状态: bash $root/setup.sh status"
    fi
}

ub-diff() {
    local d="$HOME/.bashrc.d"
    local root
    root=$(cat "$d/.repo_root" 2>/dev/null)
    [[ -z "$root" ]] && { echo "无法确定仓库路径，请先运行 ./setup.sh" >&2; return 1; }
    for f in "$d"/*.bashrc "$d"/interactive.startup; do
        [[ -f "$f" ]] || continue
        local name
        name=$(basename "$f")
        [[ "$name" == *.local.* ]] && continue
        if diff -q "$f" "$root/bashrc.d/$name" >/dev/null 2>&1; then
            echo "[=] $name"
        else
            echo "[*] $name 有差异:"
            diff -u "$root/bashrc.d/$name" "$f" | sed -n '1,30p'
        fi
    done
}
