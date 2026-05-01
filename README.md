# Linux Tool

中文名：Linux 工具集

让 Linux 折腾更简单。
Make Linux tinkering easier.

Linux Tool 是一个本地 Linux 终端工具中心。它使用 Bash + fzf 提供 TUI 交互，把仓库中的脚本工具统一放在 `tool/` 目录下，并在启动时自动扫描识别。新增工具只需要放入 `tool/` 目录，并添加 `LT_*` 元信息头，`linux-tool` 会自动出现在工具列表里，不需要修改主菜单。

## 彩色 Logo

启动 `linux-tool` 时会显示彩色 `linux-tool` Logo。程序会优先尝试使用 [oh-my-logo](https://github.com/helloskov/oh-my-logo) 生成动态彩色 Logo：

```bash
npx oh-my-logo@latest "linux-tool" fire --filled
```

如果系统没有 `node/npm/npx`，或 `oh-my-logo` 无法运行，会自动降级使用 `assets/logo.txt` 中的静态 ANSI Logo。Logo 灵感来自 oh-my-logo，但 Logo 生成失败不会影响主程序启动。

## 功能特点

- Bash + fzf TUI，本地运行，不依赖 root 权限。
- 自动扫描 `tool/*.sh`，不再维护固定菜单。
- fzf 左侧展示工具列表，右侧实时预览工具说明、版本、作者、依赖、危险等级和路径。
- 支持 `linux-tool` 与兼容命令 `linuxtool`。
- 支持 `--version`、`list`、`run`、`preview`、`update` 等 CLI 命令。
- 危险工具支持二次确认，避免误执行高风险脚本。
- 日志写入 `~/.local/state/linux-tool/logs/linux-tool.log`。
- 更新前自动备份，更新失败时回滚。
- 发行版检测兼容 apt / dnf / pacman / zypper。

## 安装方式

推荐从 GitHub 克隆后安装：

```bash
git clone https://github.com/Xynrin/linux-tool.git
cd linux-tool
bash install.sh
```

安装后路径：

```text
主程序：~/.local/bin/linux-tool
兼容命令：~/.local/bin/linuxtool
应用目录：~/.local/share/linux-tool/app
工具目录：~/.local/share/linux-tool/tool
日志目录：~/.local/state/linux-tool/logs
日志文件：~/.local/state/linux-tool/logs/linux-tool.log
```

如果 `~/.local/bin` 不在 `PATH`，安装脚本会给出提示。可以把下面内容加入 `~/.bashrc`、`~/.zshrc` 或你的 shell 配置：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

依赖建议：

```bash
# Debian / Ubuntu
sudo apt install fzf

# Fedora
sudo dnf install fzf

# Arch Linux
sudo pacman -S fzf

# openSUSE
sudo zypper install fzf
```

`npx` 仅用于动态 Logo，不是必需依赖。

## 卸载方式

```bash
bash uninstall.sh
```

卸载脚本会移除：

- `~/.local/bin/linux-tool`
- `~/.local/bin/linuxtool`
- `~/.local/share/linux-tool`

日志目录 `~/.local/state/linux-tool` 会询问后再删除。

## 使用方式

```bash
linux-tool
linux-tool --help
linux-tool --version
linux-tool update
linux-tool list
linux-tool run <tool-id>
linux-tool preview <tool-id>
linuxtool --version
```

启动 TUI：

```bash
linux-tool
```

fzf 常用操作：

```text
Enter：运行工具
Ctrl+R：刷新工具列表
Ctrl+I：查看工具信息
Ctrl+U：检查更新
Ctrl+L：查看日志
Esc：返回/退出
```

## fzf 交互截图占位

```text
┌ Linux Tool Center ───────────────────────────────────────────────────────┐
│ [安全防护] fuck_rm        防止误执行 rm/dd/mkfs 等危险命令                │
│ [云盘工具] cloundNAS      在线下载云盘 OS 系统                            │
│ [系统工具] tool           将 sh 文件打包成全局命令                         │
│                                                                         │
│ 右侧 preview：工具名称、工具 ID、分类、版本、作者、依赖、危险等级、路径      │
└─────────────────────────────────────────────────────────────────────────┘
```

## 工具元信息规范

每个工具脚本推荐在文件头添加 `LT_*` 元信息：

```bash
#!/usr/bin/env bash
# LT_ID=fuck_rm
# LT_NAME=危险命令防护
# LT_CATEGORY=安全防护
# LT_DESC=防止误执行 rm/dd/mkfs 等危险命令
# LT_VERSION=0.1.0
# LT_AUTHOR=Xynrin
# LT_DEPS=bash,coreutils
# LT_DANGEROUS=true
```

字段说明：

- `LT_ID`：工具唯一 ID，用于 `linux-tool run <tool-id>`。
- `LT_NAME`：工具显示名称。
- `LT_CATEGORY`：工具分类。
- `LT_DESC`：工具说明。
- `LT_VERSION`：工具自身版本，缺省显示 `unknown`。
- `LT_AUTHOR`：工具作者，缺省显示 `unknown`。
- `LT_DEPS`：工具依赖。
- `LT_DANGEROUS`：是否危险工具，`true` 时运行前必须输入工具 ID 二次确认。

如果脚本没有元信息头，Linux Tool 会自动使用文件名作为工具 ID 和名称。

## 如何添加新工具

1. 在 `tool/` 目录下新增一个 `.sh` 文件，例如 `tool/example.sh`。
2. 在文件头添加 `LT_*` 元信息。
3. 确保脚本可以通过 `bash tool/example.sh` 运行。
4. 重新执行 `linux-tool`，新工具会自动出现在 fzf 列表中。

示例：

```bash
cp tool/example.sh tool/my-tool.sh
vim tool/my-tool.sh
linux-tool
```

不需要修改 `bin/linux-tool`，也不需要手动改菜单。

## 更新方式

```bash
linux-tool update
```

更新逻辑：

- 如果 `~/.local/share/linux-tool/app` 是 git clone 安装，会优先使用 `git pull --ff-only`。
- 如果不是 git 仓库，会使用 `curl` 下载 GitHub `main` 分支压缩包并重新安装应用文件。
- 更新前会备份当前安装目录到 `~/.local/share/linux-tool/backups`。
- 更新失败会回滚到备份版本。

GitHub：

```bash
linux-tool update
```

Gitee 镜像：

```text
计划中：后续可通过 REPO_URL 或镜像配置切换到 Gitee。
```

国内网络环境可能需要代理，尤其是下载 GitHub 压缩包或使用 `npx oh-my-logo` 时。

## 项目结构

```text
linux-tool/
├── bin/
│   └── linux-tool
├── lib/
│   ├── common.sh
│   ├── ui.sh
│   ├── logo.sh
│   ├── tool_loader.sh
│   ├── preview.sh
│   ├── update.sh
│   ├── version.sh
│   ├── logger.sh
│   └── safety.sh
├── tool/
│   ├── cloundNAS.sh
│   ├── example.sh
│   ├── fuck_rm.sh
│   └── tool.sh
├── assets/
│   └── logo.txt
├── install.sh
├── uninstall.sh
├── VERSION
├── CHANGELOG.md
├── README.md
├── LICENSE
└── .gitignore
```

## Roadmap

- 提供更完整的工具分类和搜索标签。
- 增加工具依赖检测与安装建议。
- 增加 Gitee 镜像更新源。
- 增加更多安全审计和系统维护工具。
- 增加自动化测试和 shellcheck CI。

## 贡献方式

欢迎提交 Issue 和 Pull Request：

1. Fork 本仓库。
2. 在 `tool/` 下新增或改进工具。
3. 为工具添加完整 `LT_*` 元信息。
4. 确保脚本尽量兼容主流 Linux 发行版。
5. 提交 PR，并说明工具用途、依赖和风险等级。

## License

本项目使用 GPL-v3 许可证，详见 [LICENSE](./LICENSE)。

## 免责声明

本项目按“现状”提供，不做任何明示或暗示保证。部分工具可能修改系统配置、安装软件、写入系统目录或执行高风险命令。请在运行前阅读右侧预览信息和工具源码，理解风险后再执行。

使用本项目即表示你理解并同意：因使用、误用或修改本项目导致的数据丢失、系统损坏、安全风险或其他后果，由使用者自行承担。
