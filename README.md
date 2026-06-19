# Dotfiles

> Windows + WSL2 个人开发环境的控制层。管理 shell 初始化、环境变量、配置文件源和自动化脚本——不管理包。

```text
Windows = 工具层，由 Scoop 管理
WSL     = 主开发运行时，由 Nix 管理
Dotfiles = 控制层 / 编排层，不作为包管理器
```

---

## 目录

- [Dotfiles](#dotfiles)
  - [目录](#目录)
  - [设计原则](#设计原则)
  - [目录结构](#目录结构)
  - [加载链](#加载链)
    - [WSL (zsh)](#wsl-zsh)
    - [Windows (PowerShell)](#windows-powershell)
  - [快速开始](#快速开始)
    - [前置条件](#前置条件)
    - [Windows](#windows)
    - [WSL](#wsl)
  - [配置参考](#配置参考)
    - [manifest.json](#manifestjson)
    - [配置文件映射](#配置文件映射)
  - [常用命令](#常用命令)
    - [Windows (PowerShell)](#windows-powershell-1)
    - [WSL](#wsl-1)
  - [高风险区域](#高风险区域)
  - [验收清单](#验收清单)
  - [License](#license)

---

## 设计原则

| 原则                       | 说明                                                                            |
| -------------------------- | ------------------------------------------------------------------------------- |
| Dotfiles 不是包管理器      | 负责启动入口、shell 初始化、PATH 规则、配置源、脚本。不安装 node/python/git。   |
| Windows 与 WSL 逻辑隔离    | `Systems/windows/` 和 `Systems/wsl/` 分离配置，共享逻辑在 `Bootstrap/shared/`。 |
| WSL 是主开发环境           | 日常开发优先在 WSL 内完成，Windows 负责 GUI、编辑器和工具。                     |
| manifest.json 是唯一真相源 | 所有目录、环境变量、符号链接、工具列表由 manifest 驱动。                        |
| 所有操作可回滚             | setup 脚本自动创建时间戳快照，支持 `-Rollback`。                                |

---

## 目录结构

```text
D:\Dotfiles
├── manifest.json                     # 配置清单（唯一真相源）
│
├── Bootstrap/                        # Shell 初始化链
│   ├── bootstrap.sh                  # bash 入口
│   ├── bootstrap.zsh                 # zsh 入口
│   ├── shared/                       # 共享模块（bash + zsh 通用）
│   │   ├── env.sh                    #   环境变量（XDG / 工具路径）
│   │   └── tools.sh                  #   工具函数（proxy / fzf / dot）
│   ├── bash/                         # bash 专用模块
│   │   ├── alias.sh
│   │   ├── history.sh
│   │   ├── starship.sh
│   │   └── nix.sh
│   └── zsh/                          # zsh 专用模块
│       ├── env.zsh                   #   环境 + fpath + nix-daemon
│       ├── alias.zsh
│       ├── history.zsh
│       ├── completion.zsh
│       ├── proxy.zsh
│       ├── starship.zsh
│       ├── nix.zsh
│       └── tools.zsh
│
├── Systems/                          # 平台配置（按系统隔离）
│   ├── windows/                      # Windows 专用
│   │   ├── .env                      #   敏感环境变量（不入库）
│   │   ├── git/.gitconfig
│   │   ├── npm/.npmrc
│   │   ├── pip/pip.ini
│   │   ├── PowerShell/
│   │   │   ├── profile_allhosts.ps1
│   │   │   └── profile_currenthost.ps1
│   │   ├── starship/starship.toml
│   │   ├── gh/config.yml
│   │   ├── WindowsTerminal/settings.json
│   │   ├── claude/.claude.json
│   │   ├── ssh/config
│   │   └── scoop/config.json
│   └── wsl/                          # WSL 专用
│       ├── .env                      #   敏感环境变量（不入库）
│       ├── .wslconfig
│       ├── bash/bashrc
│       ├── git/.gitconfig
│       ├── nix/flake.nix
│       ├── starship/starship.toml
│       ├── zsh/zshrc
│       └── ssh/config
│
├── Scripts/                          # 自动化脚本
│   ├── setup.ps1                     # Windows 一键构建
│   ├── setup.sh                      # WSL 一键构建
│   └── modules/
│       ├── state.ps1
│       └── verify.ps1
│
├── Bin/                              # 私人 CLI 工具
└── Docs/                             # 项目文档
```

---

## 加载链

### WSL (zsh)

```text
~/.zshrc
 └─> source "$DOTFILES/Bootstrap/bootstrap.zsh"
      ├─> shared/env.sh         # XDG / 工具路径
      ├─> shared/tools.sh       # proxy / fzf / dot
      ├─> zsh/env.zsh           # fpath + env.sh 二次加载 + nix-daemon
      ├─> zsh/alias.zsh
      ├─> zsh/history.zsh
      ├─> zsh/completion.zsh
      ├─> zsh/proxy.zsh
      ├─> zsh/tools.zsh
      ├─> zsh/starship.zsh
      └─> zsh/nix.zsh
 └─> /etc/profile.d/nix-daemon.sh (最后)
```

### Windows (PowerShell)

```text
$PROFILE (Microsoft.PowerShell_profile.ps1)
 └─> source D:\Dotfiles\Systems\windows\PowerShell\profile_currenthost.ps1
      ├─> PATH 优先级设置
      ├─> Starship init
      ├─> Proxy / dotfiles / Chrome / fzf 函数
      └─> 工具初始化
```

---

## 快速开始

### 前置条件

| 平台    | 要求                      |
| ------- | ------------------------- |
| Windows | Scoop 已安装，D 盘存在    |
| WSL     | Ubuntu 22.04+，Nix 已安装 |

### Windows

```powershell
.\Scripts\setup.ps1              # 完整安装
.\Scripts\setup.ps1 -Update      # 增量更新
.\Scripts\setup.ps1 -DryRun      # 预览变更
.\Scripts\setup.ps1 -Verify      # 仅验证
.\Scripts\setup.ps1 -Rollback    # 回滚
```

### WSL

```bash
./Scripts/setup.sh              # 完整安装
./Scripts/setup.sh --update     # 增量更新
./Scripts/setup.sh --dry-run    # 预览变更
./Scripts/setup.sh --verify     # 仅验证
./Scripts/setup.sh --rollback   # 回滚
```

---

## 配置参考

### manifest.json

清单文件是整个系统的配置中心，定义 5 个维度：

| 字段          | 说明           | 示例                             |
| ------------- | -------------- | -------------------------------- |
| `directories` | 需要创建的目录 | 缓存、数据、工作区路径           |
| `env`         | 环境变量       | `DOTFILES`, `STARSHIP_CONFIG` 等 |
| `symlinks`    | 符号链接映射   | `.wslconfig` → Dotfiles 源       |
| `tools`       | 工具包列表     | Scoop / apt / nix 包             |
| `templates`   | 配置文件源路径 | `.gitconfig`, `starship.toml` 等 |

### 配置文件映射

| 目标                | 源                                                   | 平台    |
| ------------------- | ---------------------------------------------------- | ------- |
| `~/.wslconfig`      | `Systems/wsl/.wslconfig`                             | Windows |
| `~/.claude.json`    | `Systems/windows/claude/.claude.json`                | Windows |
| Windows Terminal    | `Systems/windows/WindowsTerminal/settings.json`      | Windows |
| `~/.ssh`            | `Systems/windows/ssh/`                               | Windows |
| `$PROFILE` → loader | `Systems/windows/PowerShell/profile_currenthost.ps1` | Windows |
| `~/.zshrc`          | `Systems/wsl/zsh/zshrc`                              | WSL     |
| `~/.bashrc`         | `Systems/wsl/bash/bashrc`                            | WSL     |

---

## 常用命令

### Windows (PowerShell)

```powershell
# 验证环境变量
[System.Environment]::GetEnvironmentVariable("GIT_CONFIG_GLOBAL", "User")

# 检查符号链接
Get-Item "$env:USERPROFILE\.wslconfig" | Select-Object Target

# 检查 PATH 中的 Dotfiles
[Environment]::GetEnvironmentVariable("PATH", "User")
```

### WSL

```bash
# 验证环境
echo $DOTFILES
which nix && nix --version
which zsh && zsh --version
git config --global --list
```

---

## 高风险区域

> [!WARNING]
> 以下区域不可随意修改。

| 区域                            | 风险                       | 规则                                          |
| ------------------------------- | -------------------------- | --------------------------------------------- |
| `C:\Users\Zev` Junction/Symlink | 影响 AI 工具、VS Code、WSL | 禁止未经确认删除或重建                        |
| SSH 私钥                        | 安全                       | 私钥不进 Dotfiles，不软链接到 D 盘            |
| PATH                            | 最高风险                   | 禁止 `PATH="..."` 覆盖，只允许 prepend/append |
| Nix init hook                   | 会导致 nix 不可用          | 固定使用 `/etc/profile.d/nix-daemon.sh`       |

---

## 验收清单

```text
[ ] WSL 默认 shell 是 zsh
[ ] ~/.zshrc 入口清晰，仅 source bootstrap
[ ] Bootstrap 可正常加载所有模块
[ ] env.sh 不硬覆盖 PATH
[ ] zsh/env.zsh 使用 nix-daemon.sh
[ ] nix --version 正常
[ ] WSL PATH 无 Windows/Scoop 泄露
[ ] Windows Git 由 Scoop 管理
[ ] WSL Git 为 /usr/bin/git
[ ] Windows .ssh 为普通目录（或 Junction）
[ ] WSL .ssh 为普通目录
[ ] .wslconfig symlink 正常
[ ] PowerShell Profile redirect 正常
[ ] profile_currenthost.ps1 无危险 override
```

---

## License

Private — 仅供个人使用。
