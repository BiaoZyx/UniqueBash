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

# --------------------
# Tab 补全优化
# --------------------
# 1. Tab 补全优化
bind 'TAB:menu-complete'
bind '"\e[Z": menu-complete-backward'   # Shift+Tab 反向轮询
# 关键优化：跳过已输入的重叠文本（避免出现 "foo/foo/" 这种冗余）
bind 'set skip-completed-text on'
# 给补全列表着色并显示类型标识（目录带 /，可执行文件带 *）
bind 'set colored-stats on'
bind 'set visible-stats on'

# 补全时不区分大小写（输入 ream 能匹配 ReadMe）
bind 'set completion-ignore-case on'

# 2. 显示选项与智能补全
bind 'set show-all-if-ambiguous on'
bind 'set menu-complete-display-prefix on'

# 3. 不区分大小写
bind 'set completion-ignore-case on'

# 4. (可选) 为目录符号链接自动添加斜杠
bind 'set mark-symlinked-directories on'

# 5. (可选) 不自动补全隐藏文件，除非输入了 "."
bind 'set match-hidden-files off'


bind 'set horizontal-scroll-mode on'    # 水平滚动模式（避免长命令换行）