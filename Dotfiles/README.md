# Dotfiles

> **Windows + WSL2 个人开发环境的控制层。**
> 管理 shell 初始化、环境变量、配置文件源和自动化脚本——不管理包。

---

## 架构总览

```
┌─────────────────────────────────────────────────┐
│                  Dotfiles (控制层)                │
│        bootstrap · env · PATH · 配置源 · 脚本     │
└────────────┬────────────────────┬───────────────┘
             │                    │
     ┌───────▼───────┐    ┌──────▼───────┐
     │  Windows 工具层 │    │  WSL 开发层   │
     │    Scoop 管理   │    │  Nix 管理     │
     │  PowerShell     │    │  zsh / bash   │
     │  Git / SSH      │    │  Git / SSH    │
     └─────────────────┘    └──────────────┘
```

```text
Windows = 工具层，由 Scoop 管理
WSL     = 主开发运行时，由 Nix 管理
Dotfiles = 控制层 / 编排层，不作为包管理器
```

---

## 设计原则

| 原则 | 说明 |
|------|------|
| **Dotfiles 不是包管理器** | 负责启动入口、shell 初始化、PATH 规则、配置源、脚本。不安装 node/python/git。 |
| **Windows 与 WSL 逻辑隔离** | 通过 `Systems/windows/` 和 `Systems/wsl/` 分离配置，共享逻辑在 `Bootstrap/shared/`。 |
| **WSL 是主开发环境** | 日常开发优先在 WSL 内完成，Windows 负责 GUI、编辑器和工具。 |
| **manifest.json 是唯一真相源** | 所有目录、环境变量、符号链接、工具列表由 manifest 驱动。 |
| **所有操作可回滚** | setup 脚本自动创建时间戳快照，支持 `-Rollback`。 |

---

## 目录结构

```
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
│   │   ├── git/.gitconfig            #   autocrlf=true
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
│   │   ├── ssh/known_hosts
│   │   └── scoop/config.json
│   └── wsl/                          # WSL 专用
│       ├── .env                      #   敏感环境变量（不入库）
│       ├── .wslconfig
│       ├── bash/bashrc
│       ├── git/.gitconfig            #   autocrlf=input
│       ├── nix/flake.nix
│       ├── starship/starship.toml
│       ├── zsh/zshrc
│       └── ssh/
│           ├── config
│           ├── known_hosts
│           └── wsl_known_hosts
│
├── Scripts/                          # 自动化脚本
│   ├── setup.ps1                     # Windows 一键构建
│   ├── setup.sh                      # WSL 一键构建
│   └── modules/                      # 脚本模块
│       ├── state.ps1
│       └── verify.ps1
│
├── Bin/                              # 私人 CLI 工具
├── Docs/                             # 项目文档
├── CLAUDE.md                         # Claude Code 指令
└── README.md
```

---

## 加载链

### WSL (zsh)

```
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
 └─> nix-daemon.sh (最后)
```

### Windows (PowerShell)

```
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

| 平台 | 要求 |
|------|------|
| Windows | Scoop 已安装，D 盘存在 |
| WSL | Ubuntu 22.04+，Nix 已安装 |

### Windows 安装

```powershell
# 完整安装
.\Scripts\setup.ps1

# 增量更新
.\Scripts\setup.ps1 -Update

# 预览变更（不执行）
.\Scripts\setup.ps1 -DryRun

# 验证状态
.\Scripts\setup.ps1 -Verify

# 回滚
.\Scripts\setup.ps1 -Rollback
```

### WSL 安装

```bash
# 完整安装
./Scripts/setup.sh

# 增量更新
./Scripts/setup.sh --update

# 预览变更
./Scripts/setup.sh --dry-run

# 验证状态
./Scripts/setup.sh --verify

# 回滚
./Scripts/setup.sh --rollback
```

---

## manifest.json

清单文件是整个系统的配置中心，定义 5 个维度：

| 字段 | 说明 | 示例 |
|------|------|------|
| `directories` | 需要创建的目录 | 缓存、数据、工作区路径 |
| `env` | 环境变量 | `DOTFILES`, `STARSHIP_CONFIG` 等 |
| `symlinks` | 符号链接映射 | `.wslconfig` → Dotfiles 源 |
| `tools` | 工具包列表 | Scoop / apt / nix 包 |
| `templates` | 配置文件源路径 | `.gitconfig`, `starship.toml` 等 |

---

## 配置文件映射

### Windows → Dotfiles

| 目标 | 源 |
|------|-----|
| `~/.wslconfig` | `Systems/wsl/.wslconfig` |
| `~/.claude.json` | `Systems/windows/claude/.claude.json` |
| `Windows Terminal settings.json` | `Systems/windows/WindowsTerminal/settings.json` |
| `~/.ssh` | `Systems/windows/ssh/` (Junction) |
| `$PROFILE` → loader | `Systems/windows/PowerShell/profile_currenthost.ps1` |

### WSL → Dotfiles

| 目标 | 源 |
|------|-----|
| `~/.zshrc` | `Systems/wsl/zsh/zshrc` |
| `~/.bashrc` | `Systems/wsl/bash/bashrc` |

---

## 敏感文件

以下文件包含 API Key / Token，**不应提交到 Git**：

```text
Systems/windows/.env
Systems/wsl/.env
```

建议在 `.gitignore` 中排除：

```gitignore
Systems/windows/.env
Systems/wsl/.env
.state/
```

---

## 高风险区域

| 区域 | 风险 | 规则 |
|------|------|------|
| `C:\Users\Zev` 下的 Junction/Symlink | 影响 AI 工具、VS Code、WSL | 禁止未经确认删除或重建 |
| SSH 私钥 | 安全 | 私钥不进 Dotfiles，不软链接到 D 盘 |
| PATH | 最高风险 | 禁止 `PATH="..."` 覆盖，只允许 prepend/append |
| Nix init hook | 会导致 nix 不可用 | 固定使用 `/etc/profile.d/nix-daemon.sh` |

---

## 当前状态

```text
Windows = 已建立，Scoop 工具层运行正常
WSL     = 已建立，zsh + Nix daemon 已接通
Dotfiles = 控制层已收敛，manifest 驱动
SSH     = Windows / WSL 分离，私钥不入 Dotfiles
```

**下一步：** 逐项验收 → 进入正式使用阶段。

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

## 常用命令

```powershell
# 验证 Windows 环境变量
[System.Environment]::GetEnvironmentVariable("GIT_CONFIG_GLOBAL", "User")

# 检查符号链接
Get-Item "$env:USERPROFILE\.wslconfig" | Select-Object Target

# 检查 PATH 中的 Dotfiles
[Environment]::GetEnvironmentVariable("PATH", "User")
```

```bash
# 验证 WSL 环境
echo $DOTFILES
which nix && nix --version
which zsh && zsh --version
git config --global --list
```

---

## License

Private — 仅供个人使用。
