# UniqueBash 使用文档

English: [README_en.md](README_en.md)

## 简介
UniqueBash 是一组面向通用 Linux 发行版的可扩展 Bash 配置集合，目标是提供开箱即用且易于定制的 Shell 体验。内含的模块包括：提示符（prompt）、别名（aliases）、环境变量（env）、自定义函数（func）等，配置文件位于 `bashrc.d` 目录。

本项目来源于作者在开发板（例如 Milk-V Duo S）上的个人 Bash 配置，现已模块化并整理为可复用的集合。欢迎反馈、改进建议与贡献。

## 目录（快速跳转）
- **安装**: 查看如何将配置应用到你的系统
- **使用**: 快速上手命令与示例
- **结构**: 仓库与模块说明
- **贡献**: 如何参与开发
- **许可**: 授权信息

## 快速开始
```sh
./setup.sh
```
> 注：有备份

## 结构说明
- `main.bashrc`: 主入口，等同于 `~/.bashrc` 的配置载入器，负责初始化提示符和加载 `bashrc.d` 中的模块。
- `bashrc.d/`: 模块目录，按功能拆分以便替换与扩展。默认文件：
  - `aliases.bashrc`：命令别名
  - `apps.bashrc`：应用启动或集成脚本（如 tmux、thefuck）
  - `env.bashrc`：环境变量（如 PATH、Homebrew 镜像设置）
  - `func.bashrc`：自定义函数集合
  - `memo.bashrc`：个人备忘/快捷笔记（可选）
  - `prompt.bashrc`：提示符样式与切换逻辑（TTY/Powerline）
  - `interactive.startup`：仅在交互式 shell 启动时加载的设置（快捷键绑定、history 行为等）。注意：快捷键绑定应仅放在交互 shell 的启动流程中，否则可能在脚本执行时导致警告或错误。

  ## 快捷键速览
  以下按键与设置在交互式 shell 中生效（详见 `bashrc.d/interactive.startup`）：

  - `Ctrl-p`：切换提示符样式（Powerline ↔ ASCII），由 `__prompt_toggle_style` 处理。
  - `Alt + ↑`：历史子串向后搜索（`history-substring-search-backward`）。
  - `Alt + ↓`：历史子串向前搜索（`history-substring-search-forward`）。
  - `Tab`：循环补全（`menu-complete`）。
  - `Shift + Tab`：反向循环补全（`menu-complete-backward`）。
  - 其他 readline 设置（影响补全与显示行为）：
    - `skip-completed-text on`（避免重复文本）
    - `colored-stats on`, `visible-stats on`（彩色与可见补全统计）
    - `completion-ignore-case on`（补全忽略大小写）
    - `show-all-if-ambiguous on`, `menu-complete-display-prefix on`
    - `mark-symlinked-directories on`, `match-hidden-files off`
    - `horizontal-scroll-mode on`（水平滚动，避免长命令换行）

  说明：上述快捷键与设置仅在交互式 Shell 生效。若需查看或修改按键，请编辑 `bashrc.d/interactive.startup`。

## 可扩展性建议
- 将个人改动放在 `bashrc.d` 中的新文件，避免直接修改仓库中的默认文件，便于通过版本控制合并上游更新。
- 使用类似 `XX.local.bashrc` 的命名约定来保存机器/用户特定配置，加入 `.gitignore` 防止提交。

## 贡献
- 欢迎提交 Issue 或 Pull Request。建议先在 Issue 中讨论大的设计变更。

## 许可
详见仓库根目录中的 `LICENSE` 文件。

---
如果你需要英文版，请点击顶部的链接： [README_en.md](README_en.md)