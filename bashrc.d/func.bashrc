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

    # 根据 LANG 选择语言（只取前两位，如 zh, en, es...）
    local lang="${LANG:0:2}"
    case "$lang" in
        zh)
            # 中文提示（ASCII 符号，无 Emoji）
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

    # 猜测命令
    local guess=$(history | awk '{print $2}' | grep -E "^.{0,2}${cmd}.{0,2}$" | tail -1)
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