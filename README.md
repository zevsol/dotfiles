# dotfiles

我个人的 Windows 11 环境自动化与配置文件。

## 架构与逻辑

- **包管理:** 依赖 `scoop` (命令行及便携软件) 和 `winget` (系统级 GUI 应用) 驱动。拒绝传统安装包。
- **同步策略:** 所有配置统一存放在 `D:\Dotfiles\Config`。系统底层路径通过 PowerShell 符号链接 (Symlink) 映射接管。
- **安全隔离:** 敏感凭证与密钥（如 `.env`, `.ssh/`, `.claude.json`）通过 `.gitignore` 严格拦截，仅通过 Tailscale 内网进行端到端传输。

## 一键部署

在全新的 Windows 11 系统中，以**管理员身份**打开 PowerShell 并运行以下命令：

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
irm [zevsol.com/env](https://zevsol.com/env) | iex
```

该初始化脚本会自动配置 Scoop 环境、将本仓库克隆至本机的 `~/Dotfiles`，并自动建立所有的底层符号链接。

## 目录结构

```text
Dotfiles/
├── Config/
│   ├── git/                # 全局 .gitconfig 配置
│   ├── gh/                 # GitHub CLI 凭证配置
│   ├── PowerShell/         # $PROFILE 脚本及自定义函数 (如 Set-Symlink)
│   ├── scoop/              # Scoop 软件清单
│   ├── Starship/           # starship.toml 配置
│   ├── WindowsTerminal/    # settings.json 终端配置
│   └── claude/             # Claude CLI 全局配置及凭证
├── Scripts/
│   ├── Zev-Env-Setup.ps1   # 挂载于 [zevsol.com/env](https://zevsol.com/env) 的核心初始化脚本
│   └── winget-pkgs.json    # Winget 批量恢复清单
└── README.md
```


## 许可证

MIT
