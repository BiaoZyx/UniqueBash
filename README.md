# UniqueBash 使用文档

English: [README_en.md](README_en.md)

## 简介
UniqueBash 是一组面向通用 Linux 发行版的可扩展 Bash 配置集合，目标是提供开箱即用且易于定制的 Shell 体验。内置模块包括：提示符（prompt）、别名（aliases）、环境变量（env）、自定义函数（func）等，配置文件位于 `bashrc.d` 目录。

本项目来源于作者在开发板（例如 Milk-V Duo S）上的个人 Bash 配置，现已模块化并整理为可复用的集合。欢迎反馈、改进建议与贡献。

## 特性
- **模块化**：所有配置按功能拆分在 `bashrc.d/` 中，互不耦合，便于替换与扩展。
- **双风格提示符**：Powerline 风格（带配色箭头）与 8 色 ASCII 风格，可通过 `Ctrl-p` 实时切换；TTY 下默认使用 ASCII。
- **Git 状态**：在提示符中显示分支、暂存/未暂存/未跟踪数量、冲突、以及领先/落后（ahead/behind）提交数，并带 3 秒缓存（目录不变时跳过 `git` 调用）。
- **管道报错显示**：任意一段管道失败都会在提示符中标红，例如 `true | false | true` 会显示 `✕0|1|0`，而不只看最后一段的退出码。
- **智能补全**：Tab 轮询补全、子串历史搜索（`Alt+↑/↓`）、大小写不敏感、隐藏文件按需补全等。
- **目录栈 `cd`**：`cd +n` / `cd -n` 在目录栈中跳转；纯数字命令会自动尝试目录栈跳转。
- **命令未找到提示**：根据 `LANG` 给出多语言（中文/英文/西班牙文）的友好提示或“你是不是想输入 XXX”。
- **应用集成**：自动集成 `thefuck`、`memo` 等工具（若已安装）。

## 快速开始
```sh
./setup.sh
```
> 注：会自动备份已有的 `~/.bashrc` 与 `~/.bash_profile`；默认**全量安装、零提问**（需要挑选模块时用 `--tui` / `--select` / `--modules`）。

## 安装选项

`setup.sh` 采用**子命令**结构（缺省子命令为 `install`）；旧标志（`--update` / `--uninstall` / `--preview` / `--tui` / `--yes` / `--force` / `--help` / `--version`）全部保留为兼容别名。

```sh
./setup.sh [子命令] [选项]

子命令:
  install        安装：备份并软链 ~/.bashrc、~/.bash_profile，安装模块（缺省）
  update         更新：修复软链，三方融合升级模块（跳过 *.local.*）
  uninstall      卸载：按备份恢复 ~/.bashrc、~/.bash_profile，移除默认模块
  status         查看安装状态、软链指向、模块差异与待处理冲突
  preview [动作] 预演任意动作（install/update/uninstall），不写盘
  help / version 帮助 / 版本

选项:
  --yes, --auto          非交互（缺省即全装）
  --tui                  用 TUI（dialog / fzf）选择模块
  --select               用编号交互选择模块
  --modules=a,b,c        按模块名非交互选择
  --no-backup            不备份 ~/.bashrc / ~/.bash_profile
  --overwrite-modules    更新时直接以仓库版本覆盖你的模块修改
  --force                兼容别名 = --no-backup + --overwrite-modules
  --lang=zh|en           界面语言（缺省跟随系统 locale，全部消息中英双语）
  --preview              对当前动作做 dry-run（不写盘）
```

退出码：

| 码 | 含义 |
| --- | --- |
| 0 | 成功 |
| 1 | 致命错误（I/O、git 失败等） |
| 2 | 用法错误（未知子命令/选项） |
| 3 | 前置检查失败（缺 `main.bashrc`、被 source 运行等） |
| 4 | 动作完成但存在合并冲突（install/update） |
| — | `status` 子命令：0 正常 / 1 发现问题（软链损坏、待处理冲突） |

```sh
./setup.sh                      # 全量安装（零提问，自动备份）
./setup.sh --select             # 编号选择模块
./setup.sh update               # 日常更新
./setup.sh preview update       # 预演更新，不写盘
./setup.sh status               # 查看安装状态
./setup.sh uninstall --yes      # 非交互卸载
./setup.sh --lang=en help       # 英文帮助
```

默认行为：
1. 备份现有 `~/.bashrc` 到 `~/.bashrc.bak.<timestamp>`，并软链到本仓库的 `main.bashrc`（已正确链接时不重复备份）。
2. 备份现有 `~/.bash_profile` 到 `~/.bash_profile.bak.<timestamp>`，并软链到 `startup.bash_profile`。
3. 复制 `bashrc.d/*` 到 `~/.bashrc.d/`（已存在的文件会先打备份）。
4. 写入状态文件 `~/.bashrc.d/.install_state`（版本、时间、仓库 commit、已装模块、上次动作、待处理冲突），供 `status` 与 `ub-status` 读取；旧的 `.repo_root` / `.last_update` 仍然写入，`ub-*` 工具可继续使用。

> **更新（保留个人修改）**：`update` 子命令（或 `--update`）采用三方差异融合（用户版本 / 基础版本 / 上游版本）。规则如下：
> - **仓库新增了文件**：直接安装到你 `~/.bashrc.d/`，不影响你已有文件。
> - **你没改过某文件，但仓库改了**：直接更新为上游新版（判定依据：你的文件不含任何“上游所没有的独有行”，即它是上游的一个子集——这也覆盖了“你装的是旧版本、仓库后来演进过”的情况）。
> - **你和仓库改了同一文件的不同位置**：`git merge-file` 自动合并——**你的修改被保留，仓库的新增也一并合入**。
> - **你和仓库改了同一行（真正冲突）**：保留你当前可用的版本（保证 Shell 不报错），并把带 `<<<<<<<` 标记的合并结果写到 `~/.bashrc.d/.merged_<file>`，你手动解决后 `cp` 回去；同时你的旧版已备份到 `~/.bashrc.d/.backups/`。
> - **`*.local.*` 文件**：永远跳过，连合并都不会发生（属于你完全私有的配置）。
>
> 合并前会自动备份你的版本到 `~/.bashrc.d/.backups/`。日常更新可直接用 `ub-update`（见下方工具）。
> **卸载**：`uninstall` 子命令（或 `--uninstall`）会用安装时生成的备份还原 `~/.bashrc` / `~/.bash_profile`，并移除由本仓库安装的默认模块（若你改过，则还原为你的修改版本），保留 `*.local.*` 文件。
> **预览**：任意动作都可以先加 `preview` 演练（如 `./setup.sh preview update`），预览与真实执行走同一条代码路径，绝不写盘。

## 更新工具（交互式 Shell 中可用）
安装/更新后，`func.bashrc` 提供以下命令：
- `ub-update`：等价于 `./setup.sh update`（自动定位仓库路径）。
- `ub-status`：显示已加载模块数、安装版本/上次动作/仓库提交（读 `.install_state`）、最后更新时间、合并冲突与详细状态命令提示。
- `ub-diff`：逐文件对比 `~/.bashrc.d/` 与仓库上游的差异。
- 需要更完整的检查（软链是否指向本仓库、模块差异、待处理冲突）时，运行 `./setup.sh status`（有问题时退出码为 1，可脚本化）。

## 结构说明
- `main.bashrc`：主入口（等同于 `~/.bashrc` 的加载器），负责加载 `interactive.startup` 与 `bashrc.d` 中的模块。**提示符的具体实现（颜色、Git 解析、渲染）已迁移到 `bashrc.d/prompt.bashrc`**，便于维护。
- `startup.bash_profile`：登录 Shell 启动文件，串联 `/etc/profile`、`/etc/bashrc` 与本配置。
- `bashrc.d/`：模块目录，默认文件：
  - `aliases.bashrc`：命令别名（自动识别 `eza` / GNU `ls` / BSD `ls`）。
  - `apps.bashrc`：应用集成（如 `thefuck`）。
  - `env.bashrc`：环境变量（PATH、分页器、按 locale 设置语言）。
  - `func.bashrc`：自定义函数（`mkcd`、`command_not_found_handle` 等）。
  - `interactive.startup`：仅交互式 Shell 加载（历史、补全、按键绑定、`PROMPT_COMMAND`）。
  - `memo.bashrc`：个人备忘（若存在 `~/.memo`）。
  - `prompt.bashrc`：提示符核心（颜色、Git 状态解析、Powerline/ASCII 渲染与样式切换）。

## 快捷键速览
以下按键在交互式 Shell 中生效（定义于 `bashrc.d/interactive.startup`）：

| 按键 | 功能 |
| --- | --- |
| `Ctrl-p` | 切换提示符风格（Powerline ↔ ASCII） |
| `Alt + ↑` | 历史子串向后搜索 |
| `Alt + ↓` | 历史子串向前搜索 |
| `Tab` | 循环补全（menu-complete） |
| `Shift + Tab` | 反向循环补全 |
| `cd +n` / `cd -n` | 目录栈跳转 |

其他 readline 设置：`skip-completed-text`、`colored-stats`、`visible-stats`、`completion-ignore-case`、`show-all-if-ambiguous`、`menu-complete-display-prefix`、`mark-symlinked-directories`、`match-hidden-files off`、`horizontal-scroll-mode on`。

## 可扩展性建议
- 将个人改动放在 `bashrc.d` 中的新文件，避免直接修改仓库默认文件，便于通过版本控制合并上游更新。
- 使用 `XX.local.bashrc` 这类命名保存机器/用户特定配置，并加入 `.gitignore` 防止提交。
- 升级默认模块运行 `./setup.sh update`；完全移除运行 `./setup.sh uninstall`。

## 开发与质量检查
- 仓库根目录提供了 `.shellcheckrc`，可运行以下命令执行静态检查：
  ```sh
  shellcheck setup.sh main.bashrc bashrc.d/*.bashrc bashrc.d/interactive.startup
  ```
- 修改后请用 `bash -n <file>` 确认语法无误。

## 贡献
欢迎提交 Issue 或 Pull Request。建议先在 Issue 中讨论大的设计变更。

## 许可
详见仓库根目录中的 `LICENSE` 文件。
