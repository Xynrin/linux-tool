


# Linux Tool
![logo](assets/logo.jpg)
中文名：Linux 工具集

让 Linux 折腾更简单。

Make Linux tinkering easier.

Linux Tool 是一个本地 Linux 终端工具中心。它使用 Bash + fzf 组织脚本工具，启动后自动扫描工具目录，并在右侧预览中展示工具说明、版本、作者、依赖、危险等级和文件路径。

当前版本：`0.4.3`

## 彩色 Logo

Linux Tool 启动时会显示 `linux-tool` 彩色 Logo。程序会优先尝试使用 `npx oh-my-logo@latest "linux-tool" fire --filled` 生成效果；如果系统没有 `npx`、网络不可用或 oh-my-logo 执行失败，会自动降级到 `assets/logo.txt` 中的静态 ANSI Logo，不会影响程序启动。

Logo 灵感来自 [oh-my-logo](https://github.com/nekomeowww/oh-my-logo)。

## 功能特点

- Bash + fzf TUI，本地终端内运行。
- 自动扫描 `tool/*.sh`，新增工具不需要修改主菜单。
- 右侧预览展示工具元信息、危险等级和文件路径。
- 支持本地工具、云端工具索引、按需安装和本地移除。
- 云端工具下载前和危险工具运行前要求阅读并同意免责声明。
- 支持 `linux-tool` 与兼容命令 `linuxtool`。
- 支持版本显示、启动静默检查更新、手动更新和更新失败回滚。
- 日志写入 `~/.local/state/linux-tool/linux-tool.log`。
- 兼容 apt / dnf / pacman / zypper 的依赖提示，不绑定单一发行版。

## 安装方式

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
日志文件：~/.local/state/linux-tool/linux-tool.log
```

如果 `~/.local/bin` 不在 `PATH` 中，安装脚本会给出提示：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

安装脚本默认安装到当前用户目录，不需要 root。即使误用 `sudo bash install.sh`，脚本也会尽量识别真实的 `SUDO_USER`，避免安装到 `/root`。

## 卸载方式

```bash
bash uninstall.sh
```

卸载会删除：

```text
~/.local/bin/linux-tool
~/.local/bin/linuxtool
~/.local/share/linux-tool
```

卸载时会询问是否删除日志目录 `~/.local/state/linux-tool`。

## 使用方式

```bash
linux-tool
linux-tool --help
linux-tool --version
linux-tool update
linux-tool list
linux-tool list --local
linux-tool list --cloud
linux-tool run <tool-id>
linux-tool preview <tool-id>
linux-tool logs
```

兼容命令：

```bash
linuxtool
linuxtool --version
```

## fzf 交互截图占位

```text
┌──────────────────────────────────────────────────────────────────────┐
│ linux-tool                                                           │
│ Linux Tool Center 0.4.3 | Xynrin/linux-tool@main                    │
│ Enter 运行/安装  Ctrl+U 更新  Ctrl+R 刷新  Ctrl+I 信息  Esc 退出     │
├──────────────────────────────┬───────────────────────────────────────┤
│ [安全防护] fuck_rm           │ 工具名称：危险命令防护                │
│ [云盘工具] cloundNAS         │ 工具 ID：fuck_rm                      │
│ [系统工具] tool              │ 版本：0.1.0                           │
└──────────────────────────────┴───────────────────────────────────────┘
```

## 工具元信息规范

每个工具脚本建议使用统一注释头：

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

- `LT_ID`：工具唯一 ID，建议只使用字母、数字、点、下划线和短横线。
- `LT_NAME`：工具显示名称。
- `LT_CATEGORY`：工具分类。
- `LT_DESC`：工具描述。
- `LT_VERSION`：工具自身版本；缺失时显示 `unknown`。
- `LT_AUTHOR`：作者；缺失时显示 `unknown`。
- `LT_DEPS`：依赖列表。
- `LT_DANGEROUS`：是否危险操作，`true` 时运行前必须阅读并同意免责声明。

如果工具没有元信息头，Linux Tool 会自动使用文件名作为工具 ID 和名称。

## 如何添加新工具

把脚本放入工具目录即可：

```bash
cp example.sh ~/.local/share/linux-tool/tool/example.sh
chmod +x ~/.local/share/linux-tool/tool/example.sh
linux-tool
```

重点：新增工具只需要放入 `tool/` 目录，并添加 `LT_*` 元信息头，Linux Tool 会自动识别，不需要手动修改 Bash 菜单。

仓库内也提供了 `tool/example.sh` 作为示例。

## 更新方式

启动 `linux-tool` 时会静默检查远程 `VERSION`：

- 当前版本等于远程版本：不提示，只写入 INFO 日志。
- 网络失败：不阻断启动。
- 发现新版本：询问是否更新；更新成功后自动重新运行 `linux-tool`。

主动更新：

```bash
linux-tool update
```

如果已经是最新版本，会显示：

```text
当前已经是最新版本。
当前版本：0.4.3
最新版本：0.4.3
```

更新策略：

- 如果当前应用目录是 git clone 工作区，优先使用 `git pull --ff-only`。
- 普通安装会通过 GitHub main 分支压缩包下载并替换应用文件。
- 更新前会备份当前安装目录。
- 更新失败会回滚，不应破坏原安装目录。
- fzf 中按 `Ctrl+U` 更新成功后会用 `exec` 替换旧进程并重新启动，避免旧 Bash 进程继续使用旧 `lib/*.sh`。

Gitee 镜像更新方式：预留中。国内网络环境访问 GitHub 可能需要代理或镜像源。

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
│   ├── fuck_rm.sh
│   ├── tool.sh
│   └── example.sh
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

- 完善 Gitee 镜像更新通道。
- 为工具增加更细粒度的权限和依赖检查。
- 增加工具评分、标签和搜索增强。
- 增加导入/导出本地工具清单。
- 补充自动化测试和 shellcheck CI。

## 贡献方式

欢迎提交 Issue 和 Pull Request。新增工具时请尽量：

- 放入 `tool/` 目录。
- 添加 `LT_*` 元信息头。
- 避免强制 root，确实需要时清晰提示。
- 对危险操作设置 `LT_DANGEROUS=true`。
- 保持脚本可读，并尽量通过 `shellcheck`。

## License

本项目采用 GPL-v3 许可证，详见 [LICENSE](./LICENSE)。

## 免责声明

本项目按“现状”提供，不做任何明示或暗示保证。部分工具可能修改系统配置、安装软件、删除文件或执行高风险操作。请在运行前阅读工具说明和源码，并自行承担使用风险。

请不要在生产环境或关键系统上运行你不了解的工具。对于因使用本项目造成的数据丢失、系统故障、业务中断或其他损失，作者和贡献者不承担责任。

![Alt]( https://repobeats.axiom.co/api/embed/cebab1791784bcad5f5bd332a82d494350803c53.svg "Repobeats 分析图像")
