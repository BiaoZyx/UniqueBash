# =========================
#  _    _         _
# | |__(_)_ _  __| |
# | '_ \ | ' \/ _` |
# |_.__/_|_||_\__,_|
# (~/.bashrc.d/bind.bashrc)
# =========================

# 绑定 Alt+↑ 进行子串搜索（向后搜索）
bind '"\e[1;3A": history-substring-search-backward'
# 绑定 Alt+↓ 进行子串搜索（向前搜索）
bind '"\e[1;3B": history-substring-search-forward'
# --- Tab 补全优化 ---

# 1. 菜单循环补全
bind 'TAB:menu-complete'
bind '"\e[Z": menu-complete-backward'

# 2. 显示选项与智能补全
bind 'set show-all-if-ambiguous on'
bind 'set menu-complete-display-prefix on'

# 3. 不区分大小写
bind 'set completion-ignore-case on'

# 4. (可选) 为目录符号链接自动添加斜杠
bind 'set mark-symlinked-directories on'

# 5. (可选) 不自动补全隐藏文件，除非输入了 "."
bind 'set match-hidden-files off'