<#
.SYNOPSIS
    一键初始化 / 清理 / 增量追加 Zev 开发的 Windows 环境。
.DESCRIPTION
    三种模式：
    1. 默认（无参数）：完整初始化。创建目录/文件、注入环境变量、同步 PATH、部署 Scoop 及工具链、配置 PowerShell Profile、
                       创建重解析点。
    2. -Clean：清理模式。删除所有脚本注入环境变量，并从 PATH 中移除自定义路径；从所有 PowerShell Profile 中移除脚本注入的引导块。
       可选参数 -ArchiveConfig 用于备份 D 盘 PowerShell 配置目录；
       可选参数 -Purge 用于删除白名单中的缓存目录（需用户确认）。
    3. -Update：增量追加模式。仅添加缺失的目录/文件、环境变量、工具和 Profile 配置，并确保重解析点存在。
       注意：-Update 模式下不会覆盖任何已存在的 D 盘配置文件。
       若检测到从未执行过完整初始化，-Update 将自动退化为完整初始化。
       网络问题：自动检测本地代理并设置环境变量，使网络检测 and Scoop 安装使用代理。
       软链接处理：若 D 盘目标文件已存在，则警告用户自行处理，不自动覆盖。

    所有模式均支持 -WhatIf 预览。
.PARAMETER WhatIf
    预览操作而不实际修改系统。
.PARAMETER Clean
    执行清理模式。
.PARAMETER Update
    执行增量追加模式。
.PARAMETER ArchiveConfig
    与 -Clean 配合使用，将 D 盘集中式 PowerShell 配置目录重命名为备份。
.PARAMETER Purge
    与 -Clean 配合使用，删除白名单中的缓存目录（需用户确认）。
.EXAMPLE
    .\Zev-Env-Setup.ps1 -WhatIf
.EXAMPLE
    .\Zev-Env-Setup.ps1
.EXAMPLE
    .\Zev-Env-Setup.ps1 -Update
.EXAMPLE
    .\Zev-Env-Setup.ps1 -Clean -WhatIf
.EXAMPLE
    .\Zev-Env-Setup.ps1 -Clean -ArchiveConfig -Purge

.NOTES
    Author: Zev
    Version: 5.32
    Last Modified: 2026-06-10
    - 修复权限瞒报 Bug：为重解析点创建逻辑强制注入 -ErrorAction Stop，确保捕获权限异常。
    - 增加熔断安全保障：当权限不足导致软链接失败时，自动触发回滚机制，将数据“原路退货”复制回 C 盘，防止配置挂空丢失。
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$Clean,
    [switch]$Update,
    [switch]$ArchiveConfig,
    [switch]$Purge
)

# ==============================================================================
# 1. 统一配置区域
# ==============================================================================

$WorkspaceConfig = @(
    @{ Path = "D:\Scoop";               Env = "SCOOP";              Desc = "Scoop 包管理器根目录"; ItemType = "Directory" }
    @{ Path = "D:\Dotfiles\Config";     Env = "XDG_CONFIG_HOME";    Desc = "跨平台配置 (XDG 标准)"; ItemType = "Directory" }
    @{ Path = "D:\Dotfiles\Scripts";    Env = $null;                Desc = "自动化脚本"; ItemType = "Directory" }
    @{ Path = "D:\Dotfiles\Bin";        Env = $null;                Desc = "私人 CLI 工具"; ItemType = "Directory" }
    @{ Path = "D:\Dotfiles\Config\PowerShell"; Env = $null;         Desc = "PowerShell 集中配置目录"; ItemType = "Directory" }
    @{ Path = "D:\Cache\Pip";           Env = "PIP_CACHE_DIR";      Desc = "Python pip 缓存"; ItemType = "Directory" }
    @{ Path = "D:\Cache\Npm";           Env = "NPM_CONFIG_CACHE";   Desc = "Node.js npm 缓存"; ItemType = "Directory" }
    @{ Path = "D:\Cache\Yarn";          Env = "YARN_CACHE_FOLDER";  Desc = "Yarn 缓存"; ItemType = "Directory" }
    @{ Path = "D:\Cache\Cargo";         Env = "CARGO_HOME";         Desc = "Rust Cargo 缓存"; ItemType = "Directory" }
    @{ Path = "D:\Cache\Rustup";        Env = "RUSTUP_HOME";        Desc = "Rustup 工具链"; ItemType = "Directory" }
    @{ Path = "D:\Cache\Go";            Env = "GOPATH";             Desc = "Go 工作区"; ItemType = "Directory" }
    @{ Path = "D:\Cache\Gradle";        Env = "GRADLE_USER_HOME";   Desc = "Gradle 缓存"; ItemType = "Directory" }
    @{ Path = "D:\Cache\XDG";           Env = "XDG_CACHE_HOME";     Desc = "XDG 缓存"; ItemType = "Directory" }
    @{ Path = "D:\Cache\JetBrains";     Env = $null;                Desc = "JetBrains 缓存"; ItemType = "Directory" }
    @{ Path = "D:\Data\AI\Ollama";      Env = "OLLAMA_MODELS";      Desc = "Ollama 模型"; ItemType = "Directory" }
    @{ Path = "D:\Data\AI\HuggingFace"; Env = "HF_HOME";            Desc = "HuggingFace 模型"; ItemType = "Directory" }
    @{ Path = "D:\Data\AI\Train";       Env = $null;                Desc = "AI 训练输出"; ItemType = "Directory" }
    @{ Path = "D:\Data\XDG";            Env = "XDG_DATA_HOME";      Desc = "XDG 用户数据"; ItemType = "Directory" }
    @{ Path = "D:\Data\Docker";         Env = "DOCKER_CONFIG";      Desc = "Docker 配置"; ItemType = "Directory" }
    @{ Path = "D:\Data\WSL";            Env = $null;                Desc = "WSL 虚拟磁盘"; ItemType = "Directory" }
    @{ Path = "D:\Data\Npm_Global";     Env = $null;                Desc = "NPM 全局模块"; ItemType = "Directory" }
    @{ Path = "D:\Data\Maven";          Env = $null;                Desc = "Maven 本地仓库"; ItemType = "Directory" }
    @{ Path = "D:\Data\VSCode\AppData"; Env = "VSCODE_APPDATA";     Desc = "VS Code 用户数据"; ItemType = "Directory" }
    @{ Path = "D:\Data\VSCode\Extensions"; Env = "VSCODE_EXTENSIONS"; Desc = "VS Code 扩展"; ItemType = "Directory" }
    @{ Path = "D:\Dotfiles\Config\gh\config.yml"; Env = "GH_CONFIG_DIR"; Desc = "GitHub CLI 配置"; ItemType = "File"; Content = "# GitHub CLI config`n# 使用 gh config set 命令配置" }
    @{ Path = "D:\Dotfiles\Config\npm\.npmrc";    Env = "NPM_CONFIG_USERCONFIG"; Desc = "NPM 全局配置"; ItemType = "File"; Content = "prefix=D:\\Data\\Npm_Global`nregistry=https://registry.npmmirror.com" }
    @{ Path = "D:\Dotfiles\Config\pip\pip.ini";   Env = "PIP_CONFIG_FILE"; Desc = "Pip 全局配置"; ItemType = "File"; Content = "[global]`nindex-url = https://pypi.tuna.tsinghua.edu.cn/simple`n[install]`nuser = yes" }
    @{ Path = "D:\Workspace\ZevSol";    Env = $null;                Desc = "主干项目"; ItemType = "Directory" }
    @{ Path = "D:\Workspace\Lab";       Env = $null;                Desc = "实验沙箱"; ItemType = "Directory" }
    @{ Path = "D:\Media\Brand";         Env = $null;                Desc = "品牌资产"; ItemType = "Directory" }
    @{ Path = "D:\Media\Photography";   Env = $null;                Desc = "摄影图库"; ItemType = "Directory" }
    @{ Path = "D:\Media\Projects";      Env = $null;                Desc = "多媒体工程"; ItemType = "Directory" }
    @{ Path = "E:\Downloads";           Env = $null;                Desc = "下载缓冲"; ItemType = "Directory" }
    @{ Path = "E:\Portable";            Env = $null;                Desc = "绿色软件"; ItemType = "Directory" }
    @{ Path = "E:\Software\Installers"; Env = $null;                Desc = "离线安装包"; ItemType = "Directory" }
    @{ Path = "E:\Software\OS_Images";  Env = $null;                Desc = "系统镜像"; ItemType = "Directory" }
    @{ Path = "E:\Vault\Backups";       Env = $null;                Desc = "备份归档"; ItemType = "Directory" }
    @{ Path = "E:\Vault\Photos";        Env = $null;                Desc = "私人照片"; ItemType = "Directory" }
)

$AliasConfig = @{
    "cd-d"       = "D:\"
    "cd-e"       = "E:\"
    "cd-dot"     = "D:\Dotfiles"
    "cd-code"    = "D:\Workspace"
    "cd-zevsol"  = "D:\Workspace\ZevSol"
    "cd-lab"     = "D:\Workspace\Lab"
    "cd-media"   = "D:\Media"
    "cd-down"    = "E:\Downloads"
    "cd-tools"   = "E:\Portable"
    "cd-vault"   = "E:\Vault"
}

$PriorityPaths = @(
    "D:\Dotfiles\Bin",
    "D:\Dotfiles\Scripts",
    "D:\Scoop\shims",
    "D:\Data\Npm_Global\bin"
)

$ScoopBuckets = @("extras", "java", "versions")
$AdditionalTools = @("sudo", "fzf", "ripgrep", "aria2", "gh")

$GitUserName = "Zev"
$GitUserEmail = "zev@example.com"
$AutoConfigGit = $false

$CentralPowerShellDir = "D:\Dotfiles\Config\PowerShell"
$ProfileFileNames = @{
    "CurrentUserAllHosts" = "profile_allhosts.ps1"
    "CurrentUserCurrentHost" = "profile_currenthost.ps1"
}

$PurgeDirectories = @(
    "D:\Cache",
    "D:\Data\Npm_Global",
    "D:\Data\XDG",
    "D:\Data\Docker"
)
$ArchiveTargetDir = $CentralPowerShellDir

$LinkMappings = @(
    @{
        Source  = "$HOME\.ssh"
        Target  = "D:\Dotfiles\Config\ssh"
        Type    = "Junction"
        Backup  = $true
        Desc    = "OpenSSH 配置目录"
        Dynamic = $false
    }
    @{
        Source      = $null
        Target      = "D:\Dotfiles\Config\WindowsTerminal\settings.json"
        Type        = "SymbolicLink"
        Backup      = $true
        Desc        = "Windows Terminal 配置文件"
        Dynamic     = $true
        ResolveFunc = "Resolve-WindowsTerminalSettings"
    }
)

function Resolve-WindowsTerminalSettings {
    $wtPackagePatterns = @(
        "Microsoft.WindowsTerminal_*",
        "Microsoft.WindowsTerminalPreview_*"
    )
    foreach ($pattern in $wtPackagePatterns) {
        $packageDir = Join-Path $env:LOCALAPPDATA "Packages\$pattern"
        $found = Get-ChildItem $packageDir -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $localState = Join-Path $found.FullName "LocalState"
            $settingsPath = Join-Path $localState "settings.json"
            if (Test-Path $localState) {
                return $settingsPath
            }
        }
    }
    return $null
}

$ScoopRoot = ($WorkspaceConfig | Where-Object { $_.Env -eq "SCOOP" }).Path
$NpmGlobalPrefix = ($WorkspaceConfig | Where-Object { $_.Path -like "*Npm_Global*" }).Path

# ------------------------------------------------------------------------------
# 2. 辅助函数
# ------------------------------------------------------------------------------

function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-DeveloperMode {
    $key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    if (Test-Path $key) {
        $value = Get-ItemProperty -Path $key -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
        if ($value -and $value.AllowDevelopmentWithoutDevLicense -eq 1) {
            return $true
        }
    }
    return $false
}

function Test-DriveExists {
    param([string]$Path)
    $drive = Split-Path -Qualifier $Path
    if ($drive -and -not (Test-Path $drive)) { return $false }
    return $true
}

function Test-ScoopAvailable {
    param([string]$ExePath)
    return (Test-Path $ExePath) -or (Get-Command scoop -ErrorAction SilentlyContinue -ne $null)
}

function Test-NoPathConflicts {
    $workspacePaths = $WorkspaceConfig | ForEach-Object { $_.Path }
    $linkTargets = $LinkMappings | ForEach-Object { $_.Target }
    $conflicts = $linkTargets | Where-Object { $workspacePaths -contains $_ }
    if ($conflicts) {
        Write-Warning "路径冲突检测: 以下链接目标同时也是 WorkspaceConfig 中的条目（正常，无需担心）: $($conflicts -join ', ')"
    }
}

function Test-WriteableD {
    if ($WhatIfPreference) {
        Write-Host "  [WhatIf] 跳过 D 盘可写性测试。" -ForegroundColor Gray
        return $true
    }
    $testFile = "D:\_writetest_$([System.Guid]::NewGuid().ToString()).tmp"
    try {
        New-Item -Path $testFile -ItemType File -Force -ErrorAction Stop | Out-Null
        Remove-Item -Path $testFile -Force
        return $true
    } catch {
        Write-Error "D 盘不可写！请检查权限或磁盘状态。"
        return $false
    }
}

function Test-SymbolicLinkPermission {
    $testDir = $env:TEMP
    $testLink = Join-Path $testDir "test_link_$([System.Guid]::NewGuid().ToString()).tmp"
    $testTarget = Join-Path $testDir "test_target_$([System.Guid]::NewGuid().ToString()).tmp"
    try {
        New-Item -Path $testTarget -ItemType File -Force | Out-Null
        New-Item -Path $testLink -ItemType SymbolicLink -Target $testTarget -Force | Out-Null
        Remove-Item $testLink -Force -ErrorAction SilentlyContinue
        Remove-Item $testTarget -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

function Test-ProxyPort {
    param([int]$Port)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $async = $tcp.BeginConnect("127.0.0.1", $Port, $null, $null)
        $wait = $async.AsyncWaitHandle.WaitOne(500)
        if ($wait) {
            $tcp.EndConnect($async)
            $tcp.Close()
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

function Test-GitProxyConfigured {
    $proxy = git config --global http.proxy 2>$null
    return (-not [string]::IsNullOrEmpty($proxy))
}

function Set-GitAndScoopProxy {
    param([string]$ProxyUrl)
    Write-Host ">>> 正在配置 Git 和 Scoop 使用代理: $ProxyUrl" -ForegroundColor Cyan
    git config --global http.proxy $ProxyUrl
    git config --global https.proxy $ProxyUrl
    scoop config proxy $ProxyUrl
    Write-Host "  [+] 代理配置完成。" -ForegroundColor Green
}

function Set-GitLowSpeedTimeout {
    Write-Host ">>> 设置 Git 低速超时（避免无限卡住）..." -ForegroundColor Cyan
    git config --global http.lowSpeedLimit 1000
    git config --global http.lowSpeedTime 10
    Write-Host "  [+] 已设置：10 秒内速度低于 1KB/s 则超时。" -ForegroundColor Green
}

function Invoke-ScoopCommandWithTimeout {
    param(
        [scriptblock]$ScriptBlock,
        [int]$TimeoutSeconds = 60
    )
    $job = Start-Job -ScriptBlock $ScriptBlock
    $completed = $job | Wait-Job -Timeout $TimeoutSeconds
    if ($completed) {
        $result = Receive-Job -Job $job
        Remove-Job -Job $job
        return $result
    } else {
        Write-Warning "操作超时（${TimeoutSeconds}秒），已中止。"
        Stop-Job -Job $job
        Remove-Job -Job $job
        return $null
    }
}

function Update-UserPath {
    param([string[]]$PathsToRegister)
    
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $currentParts = if ($userPath) { $userPath -split ';' | Where-Object { $_.Trim() -ne '' } } else { @() }
    $modified = $false
    
    for ($i = $PathsToRegister.Count - 1; $i -ge 0; $i--) {
        $p = $PathsToRegister[$i]
        if ($currentParts -notcontains $p) {
            if ($PSCmdlet.ShouldProcess("系统用户 PATH 注册表", "前置插入高优路径: $p")) {
                $currentParts = ,$p + $currentParts
                $modified = $true
            }
        }
    }
    
    if ($modified) {
        $combinedPath = $currentParts -join ';'
        [Environment]::SetEnvironmentVariable("PATH", $combinedPath, "User")
        Write-Host "  [+] 自定义环境路径已成功写入 Windows 注册表。" -ForegroundColor Green
    } else {
        Write-Host "  [-] Windows 注册表 PATH 已与优先级数组保持同步，无需修改。" -ForegroundColor Gray
    }
    
    foreach ($p in $PathsToRegister) {
        if ($env:PATH -notlike "*$p*") { $env:PATH = "$p;$env:PATH" }
    }
}

# ------------------------------------------------------------------------------
# 3. 清理模式
# ------------------------------------------------------------------------------

function Invoke-Cleanup {
    Write-Host ">>> 开始执行 environment 无痕清理 (WhatIf=$WhatIfPreference)..." -ForegroundColor Cyan

    $envVarsToRemove = $WorkspaceConfig | Where-Object { $_.Env -ne $null } | ForEach-Object { $_.Env } | Select-Object -Unique
    foreach ($var in $envVarsToRemove) {
        $val = [Environment]::GetEnvironmentVariable($var, 'User')
        if ($val -ne $null) {
            if ($PSCmdlet.ShouldProcess("用户环境变量: $var", "注销变量")) {
                [Environment]::SetEnvironmentVariable($var, $null, 'User')
                Write-Host "  [+] 已注销变量: $var" -ForegroundColor Green
            }
        } else {
            Write-Host "  [-] 环境变量 $var 不存在，跳过。" -ForegroundColor Gray
        }
    }

    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if (-not [string]::IsNullOrEmpty($userPath)) {
        $parts = $userPath -split ';' | Where-Object { $_.Trim() -ne '' }
        $cleanedParts = @()
        $purgedItems = @()
        foreach ($part in $parts) {
            if ($PriorityPaths -contains $part) {
                $purgedItems += $part
            } else {
                $cleanedParts += $part
            }
        }
        if ($purgedItems.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess("Windows 用户 PATH 注册表", "移除以下路径: [ $($purgedItems -join ', ') ]")) {
                [Environment]::SetEnvironmentVariable("PATH", ($cleanedParts -join ';'), "User")
                Write-Host "  [+] 已成功从注册表 PATH 中剥离自定义路径。" -ForegroundColor Green
            }
        }
    }

    $profilePaths = @()
    $allHostsPath = $PROFILE.CurrentUserAllHosts
    $currentHostPath = $PROFILE
    if ($allHostsPath -and $allHostsPath -ne $currentHostPath) { $profilePaths += $allHostsPath }
    if ($currentHostPath) { $profilePaths += $currentHostPath }
    $profilePaths = $profilePaths | Select-Object -Unique

    foreach ($profilePath in $profilePaths) {
        if (Test-Path $profilePath) {
            $content = Get-Content $profilePath -Raw
            
            $blockPattern = '(?s)\r?\n?# BEGIN ZevSol Managed Block.*?# END ZevSol Managed Block\r?\n?'
            $legacyErrPattern = '(?mi)^\s*\((?:CurrentUserAllHosts|CurrentUserCurrentHost)\)\s*\r?\n?'
            
            $isModified = $false

            if ($content -match $blockPattern) {
                $content = $content -replace $blockPattern, ''
                $isModified = $true
                Write-Host "  [+] 已从 $profilePath 中移除脚本注入的配置块。" -ForegroundColor Green
            }
            
            if ($content -match $legacyErrPattern) {
                $content = $content -replace $legacyErrPattern, ''
                $isModified = $true
                Write-Host "  [+] 已从 $profilePath 中移除遗留的无用标签文本。" -ForegroundColor Green
            }

            if ($isModified) {
                if ($PSCmdlet.ShouldProcess($profilePath, "更新文件内容以完成清理")) {
                    Set-Content -Path $profilePath -Value $content -Force
                }
            } else {
                Write-Host "  [-] 在 $profilePath 中未找到需要清理的内容。" -ForegroundColor Gray
            }
        } else {
            Write-Host "  [-] PowerShell Profile $profilePath 不存在，跳过。" -ForegroundColor Gray
        }
    }

    Write-Host ">>> 正在执行重解析点反向清理与原始配置还原..." -ForegroundColor Cyan
    foreach ($link in $LinkMappings) {
        if ($link.Dynamic) {
            if (-not $link.ResolveFunc) { continue }
            $sourcePath = & $link.ResolveFunc
            if (-not $sourcePath) { continue }
        } else {
            $sourcePath = $link.Source
            if (-not $sourcePath) { continue }
        }
        
        if (Test-Path $sourcePath) {
            $item = Get-Item $sourcePath -Force
            if (-not [string]::IsNullOrEmpty($item.LinkType)) {
                if ($PSCmdlet.ShouldProcess($sourcePath, "拆除软链接并恢复本地备份")) {
                    Remove-Item $sourcePath -Force
                    Write-Host "  [+] 已成功断开重解析点: $sourcePath" -ForegroundColor Green
                    
                    $backupPath = "$sourcePath.backup"
                    if (Test-Path $backupPath) {
                        Move-Item -Path $backupPath -Destination $sourcePath -Force
                        Write-Host "  [+] 已无痕还原原始本地备份配置。" -ForegroundColor Green
                    }
                }
            }
        }
    }

    if ($ArchiveConfig) {
        if (Test-Path $ArchiveTargetDir) {
            $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $backupName = "$(Split-Path $ArchiveTargetDir -Leaf).bak.$timestamp"
            $parentDir = Split-Path $ArchiveTargetDir -Parent
            $backupPath = Join-Path $parentDir $backupName
            if ($PSCmdlet.ShouldProcess($ArchiveTargetDir, "重命名为 $backupName")) {
                Rename-Item -Path $ArchiveTargetDir -NewName $backupName -Force
                Write-Host "  [+] 已归档 PowerShell 配置目录至: $backupPath" -ForegroundColor Green
                Write-Host "      原配置已安全保留，如需恢复请手动重命名回原名称。" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [-] 目录 $ArchiveTargetDir 不存在，跳过归档。" -ForegroundColor Gray
        }
    }

    if ($Purge) {
        $currentDir = Get-Location
        if ($currentDir.Path -like "D:\Cache*" -or $currentDir.Path -like "D:\Data\Npm_Global*") {
            Write-Host "  当前目录在待删除路径内，自动切换到 D:\" -ForegroundColor Yellow
            Set-Location D:\
        }

        Write-Host ">>> 准备删除以下白名单目录（将永久删除所有内容）：" -ForegroundColor Yellow
        $dirsToDelete = @()
        foreach ($dir in $PurgeDirectories) {
            if (Test-Path $dir) {
                $dirsToDelete += $dir
                Write-Host "    - $dir" -ForegroundColor Red
            }
        }
        if ($dirsToDelete.Count -gt 0) {
            if ($PSCmdlet.ShouldProcess("删除物理目录", "需要用户确认")) {
                $confirmation = Read-Host "确认删除以上目录？(y/n)"
                if ($confirmation -eq 'y') {
                    foreach ($dir in $dirsToDelete) {
                        if ($PSCmdlet.ShouldProcess($dir, "删除目录及所有内容")) {
                            Remove-Item -Path $dir -Recurse -Force
                            Write-Host "  [+] 已删除目录: $dir" -ForegroundColor Green
                        }
                    }
                } else {
                    Write-Host "  [-] 用户取消删除操作。" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "  [-] 未找到需要删除的白名单目录。" -ForegroundColor Gray
        }
    }

    Write-Host ">>> 环境配置清理完成。" -ForegroundColor Green
    Write-Host "提示：其他物理目录 (如 D:\Scoop, D:\Data\AI, D:\Workspace) 已安全保留，如需彻底销毁请手动删除。" -ForegroundColor Yellow
}

# ------------------------------------------------------------------------------
# 4. 核心功能：目录与文件创建
# ------------------------------------------------------------------------------

function Invoke-DirectoryAndVariableSetup {
    foreach ($Item in $WorkspaceConfig) {
        if (-not (Test-DriveExists -Path $Item.Path)) { continue }
        
        $itemType = if ($Item.ContainsKey('ItemType')) { $Item.ItemType } else { "Directory" }
        
        if ($itemType -eq "Directory") {
            if (-not (Test-Path $Item.Path)) {
                if ($PSCmdlet.ShouldProcess($Item.Path, "创建基座目录结构")) {
                    New-Item -Path $Item.Path -ItemType Directory -Force | Out-Null
                    Write-Host "  [+] 目录已建立: $($Item.Path)" -ForegroundColor Green
                }
            }
        } elseif ($itemType -eq "File") {
            $parentDir = Split-Path $Item.Path -Parent
            if (-not (Test-Path $parentDir)) {
                if ($PSCmdlet.ShouldProcess($parentDir, "创建文件父目录")) {
                    New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                    Write-Host "  [+] 父目录已创建: $parentDir" -ForegroundColor Green
                }
            }
            if (-not (Test-Path $Item.Path)) {
                if ($PSCmdlet.ShouldProcess($Item.Path, "创建配置文件")) {
                    $content = if ($Item.ContainsKey('Content')) { $Item.Content } else { "# 自动生成的文件`n" }
                    Set-Content -Path $Item.Path -Value $content -Encoding UTF8
                    Write-Host "  [+] 文件已创建: $($Item.Path)" -ForegroundColor Green
                }
            } else {
                if ($Update) {
                    Write-Host "  [-] 文件已存在，跳过（-Update 模式不覆盖）: $($Item.Path)" -ForegroundColor Gray
                } else {
                    Write-Host "  [-] 文件已存在，跳过: $($Item.Path)" -ForegroundColor Gray
                }
            }
        }
        
        if ($Item.Env) {
            $currentVal = [Environment]::GetEnvironmentVariable($Item.Env, 'User')
            if ($currentVal -ne $Item.Path) {
                if ($PSCmdlet.ShouldProcess("环境变量 [$($Item.Env)]", "永久映射至 -> $($Item.Path)")) {
                    [Environment]::SetEnvironmentVariable($Item.Env, $Item.Path, 'User')
                    Set-Item -Path "Env:$($Item.Env)" -Value $Item.Path -ErrorAction SilentlyContinue
                    Write-Host "  [+] 变量注入成功: $($Item.Env) -> $($Item.Path)" -ForegroundColor Cyan
                }
            } else {
                Write-Host "  [-] 变量 $($Item.Env) 已正确映射，跳过。" -ForegroundColor Gray
            }
        }
    }
}

# ------------------------------------------------------------------------------
# 5. Scoop 工具链安装
# ------------------------------------------------------------------------------

function Invoke-ScoopToolInstallation {
    if (-not (Test-ScoopAvailable -ExePath (Join-Path $ScoopRoot "shims\scoop.exe"))) {
        Write-Warning "Scoop 未安装或不可用，无法安装额外工具。请先运行完整初始化。"
        return
    }
    
    $aria2Enabled = scoop config aria2-enabled 2>$null
    if ($aria2Enabled -ne "false") {
        Write-Host ">>> 正在禁用 Scoop 的 aria2（避免网络连接问题）..." -ForegroundColor Cyan
        if ($PSCmdlet.ShouldProcess("Scoop 配置", "设置 aria2-enabled false")) {
            scoop config aria2-enabled false
            Write-Host "  [+] 已禁用 aria2。" -ForegroundColor Green
        }
    } else {
        Write-Host "  [-] aria2 已经禁用，跳过。" -ForegroundColor Gray
    }
    
    if (-not (Test-GitProxyConfigured)) {
        Write-Host ">>> 检测到 Git 未配置代理..." -ForegroundColor Yellow
        if ($env:HTTP_PROXY) {
            $response = Read-Host "  [?] 是否将当前代理 ($env:HTTP_PROXY) 自动写入 Git 和 Scoop 的全局配置？(y/n) [默认 y]"
            if ([string]::IsNullOrWhiteSpace($response) -or $response -eq 'y') {
                Set-GitAndScoopProxy -ProxyUrl $env:HTTP_PROXY
            }
        } else {
            $manualProxy = Read-Host "  [?] 请输入您的代理地址(如 http://127.0.0.1:10808)，直接回车则跳过配置"
            if (-not [string]::IsNullOrWhiteSpace($manualProxy)) {
                Set-GitAndScoopProxy -ProxyUrl $manualProxy
            } else {
                Write-Host "  [-] 跳过 Git 和 Scoop 的代理配置。" -ForegroundColor Gray
            }
        }
    } else {
        $currentProxy = git config --global http.proxy
        Write-Host "  [-] Git 已配置代理: $currentProxy" -ForegroundColor Gray
    }
    
    Set-GitLowSpeedTimeout
    
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host ">>> Git 未安装，正在通过 Scoop 安装 Git..." -ForegroundColor Cyan
        if ($PSCmdlet.ShouldProcess("Git", "安装 Git")) {
            & scoop install git
            $scoopShims = Join-Path $ScoopRoot "shims"
            if ($env:PATH -notlike "*$scoopShims*") {
                $env:PATH = "$scoopShims;$env:PATH"
            }
        } else {
            Write-Warning "跳过 Git 安装，后续添加 buckets 可能会失败。"
        }
    }
    
    $activeBuckets = & scoop bucket list 2>$null | ForEach-Object { ($_ -split '\s+')[0] } | Where-Object { $_ }
    foreach ($bucket in $ScoopBuckets) {
        if ($activeBuckets -notcontains $bucket) {
            Write-Host ">>> 添加软件桶: $bucket" -ForegroundColor Cyan
            $result = Invoke-ScoopCommandWithTimeout -ScriptBlock { param($b) scoop bucket add $b } -ArgumentList $bucket -TimeoutSeconds 60
            if ($result -ne $null) {
                Write-Host "  [+] 成功挂载软件源: $bucket" -ForegroundColor Green
            } else {
                Write-Warning "  添加桶 $bucket 超时或失败，跳过。" -ForegroundColor Red
            }
        }
    }
    
    if ($AdditionalTools.Count -gt 0) {
        Write-Host ">>> 校验高频 CLI 生产力工具..." -ForegroundColor Cyan
        foreach ($tool in $AdditionalTools) {
            if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
                if ($PSCmdlet.ShouldProcess("基础工具 [$tool]", "通过 Scoop 部署")) {
                    & scoop install $tool
                }
            } else {
                Write-Host "  [-] 工具已存在于当前 environment，跳过: $tool" -ForegroundColor Gray
            }
        }
    }
}

# ------------------------------------------------------------------------------
# 6. PowerShell Profile 配置
# ------------------------------------------------------------------------------

function Invoke-ProfileSetup {
    if (-not (Test-Path $CentralPowerShellDir)) {
        if ($PSCmdlet.ShouldProcess($CentralPowerShellDir, "创建集中式 PowerShell 配置目录")) {
            New-Item -Path $CentralPowerShellDir -ItemType Directory -Force | Out-Null
            Write-Host "  [+] 已创建目录: $CentralPowerShellDir" -ForegroundColor Green
        }
    }
    
    $priorityPathsLiteral = '@(' + (($PriorityPaths | ForEach-Object { '"' + $_ + '"' }) -join ', ') + ')'
    
    $commonContent = @"

# ==============================================================================
# ZevSol PowerShell Profile (集中式配置)
# 生成时间: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# 此文件由 Zev-Env-Setup.ps1 自动管理。
# 注意：-Update 模式下不会覆盖已存在的文件，但完整初始化会覆盖。
# ==============================================================================

# 确保自定义 PATH 优先级（会话级双保险）
`$priorityPaths = $priorityPathsLiteral
foreach (`$p in `$priorityPaths) {
    if (Test-Path `$p) {
        if (`$env:PATH -notlike "*`$p*") { `$env:PATH = "`$p;`$env:PATH" }
    }
}

# 导航别名
"@
    foreach ($shortcut in $AliasConfig.Keys) {
        $commonContent += "`nfunction $shortcut { Set-Location `"$($AliasConfig[$shortcut])`" }"
    }
    
    $commonContent += @"

# ==============================================================================
# 加载用户自定义配置（可选，手动维护）
# 将你的个性化配置放入以下文件，不会被脚本自动覆盖。
# ==============================================================================
`$customProfile = Join-Path `$PSScriptRoot "profile_custom.ps1"
if (Test-Path `$customProfile) {
    . `$customProfile
}
"@
    
    foreach ($scope in $ProfileFileNames.Keys) {
        $fileName = $ProfileFileNames[$scope]
        $centralFile = Join-Path $CentralPowerShellDir $fileName
        
        if ($Update -and (Test-Path $centralFile)) {
            Write-Host "  [-] 配置文件已存在，跳过（-Update 模式不覆盖）: $centralFile" -ForegroundColor Gray
            continue
        }
        
        if ($PSCmdlet.ShouldProcess($centralFile, "写入集中式配置文件 ($scope)")) {
            Set-Content -Path $centralFile -Value $commonContent -Force -Encoding UTF8
            Write-Host "  [+] 已写入配置文件: $centralFile" -ForegroundColor Green
        }
    }
    
    $profileMapping = @{
        "CurrentUserAllHosts" = $PROFILE.CurrentUserAllHosts
        "CurrentUserCurrentHost" = $PROFILE
    }
    foreach ($scope in $profileMapping.Keys) {
        $cProfilePath = $profileMapping[$scope]
        if (-not $cProfilePath) { continue }
        $cProfileDir = Split-Path $cProfilePath -Parent
        if (-not (Test-Path $cProfileDir)) {
            if ($PSCmdlet.ShouldProcess($cProfileDir, "创建 PowerShell Profile 目录")) {
                New-Item -Path $cProfileDir -ItemType Directory -Force | Out-Null
            }
        }
        
        $centralFile = Join-Path $CentralPowerShellDir $ProfileFileNames[$scope]
        $blockStart = "# BEGIN ZevSol Managed Block ($scope)"
        $blockEnd   = "# END ZevSol Managed Block ($scope)"
        $guardBlock = @"
$blockStart
# 加载集中式配置文件（如果存在）
if (Test-Path "$centralFile") {
    . "$centralFile"
}
$blockEnd
"@
        $existingContent = if (Test-Path $cProfilePath) { Get-Content $cProfilePath -Raw } else { "" }
        if ($null -eq $existingContent) { $existingContent = "" }
        
        $legacyErrPattern = '(?mi)^\s*\((?:CurrentUserAllHosts|CurrentUserCurrentHost)\)\s*\r?\n?'
        if ($existingContent -match $legacyErrPattern) {
            Write-Host "  [!] 检测到 $cProfilePath 中存在遗留错误行，正在自动清理..." -ForegroundColor Yellow
            $existingContent = $existingContent -replace $legacyErrPattern, ''
            if ($PSCmdlet.ShouldProcess($cProfilePath, "清理遗留错误文本")) {
                Set-Content -Path $cProfilePath -Value $existingContent -Force
                Write-Host "  [+] 已清理遗留错误文本。" -ForegroundColor Green
            }
        }
        
        $pattern = '(?s)' + [regex]::Escape($blockStart) + '.*?' + [regex]::Escape($blockEnd)
        if ($existingContent -match $pattern) {
            Write-Host "  [-] $cProfilePath 已包含引导块，跳过追加。" -ForegroundColor Gray
        } else {
            $newContent = if ($existingContent -and $existingContent.Trim()) {
                $existingContent.TrimEnd() + "`n`n" + $guardBlock
            } else {
                $guardBlock
            }
            if ($PSCmdlet.ShouldProcess($cProfilePath, "追加引导块 ($scope)")) {
                Set-Content -Path $cProfilePath -Value $newContent -Force -Encoding UTF8
                Write-Host "  [+] 已向 $cProfilePath 追加引导块。" -ForegroundColor Green
            }
        }
    }
}

# ------------------------------------------------------------------------------
# 7. 重解析点创建
# ------------------------------------------------------------------------------

function Invoke-SymlinkSetup {
    Write-Host ">>> 正在创建系统配置重解析点..." -ForegroundColor Cyan
    
    $hasSymlink = $LinkMappings | Where-Object { $_.Type -eq "SymbolicLink" }
    $canCreateSymlink = $true
    if ($hasSymlink) {
        $canCreateSymlink = Test-SymbolicLinkPermission
        if (-not $canCreateSymlink) {
            Write-Warning "当前用户无法创建 SymbolicLink。"
            $isAdmin = Test-Admin
            $devMode = Test-DeveloperMode
            if (-not $devMode) {
                Write-Host "      解决方法：开启 Windows 开发者模式（设置 → 更新和安全 → 开发者选项 → 开启'开发者模式'）。" -ForegroundColor Yellow
                Write-Host "      或使用管理员身份运行 PowerShell（但仍需开发者模式才能可靠创建软链接）。" -ForegroundColor Yellow
            } elseif (-not $isAdmin) {
                Write-Host "      解决方法：以管理员身份运行 PowerShell。" -ForegroundColor Yellow
            } else {
                Write-Host "      未知权限错误。请手动创建软链接。" -ForegroundColor Yellow
            }
            Write-Host "      软链接将被跳过，但其他操作（如 Junction、目录创建）仍会继续。" -ForegroundColor Yellow
        } else {
            Write-Host "  [+] SymbolicLink 权限检测通过。" -ForegroundColor Green
        }
    }
    
    foreach ($link in $LinkMappings) {
        if ($link.Dynamic) {
            if (-not $link.ResolveFunc) {
                Write-Warning "  动态链接缺少 ResolveFunc，跳过: $($link.Desc)"
                continue
            }
            $sourcePath = & $link.ResolveFunc
            if (-not $sourcePath) {
                Write-Warning "  无法解析动态源路径，跳过: $($link.Desc)。可能软件未安装或路径已变更。" -ForegroundColor Red
                continue
            }
        } else {
            $sourcePath = $link.Source
            if (-not $sourcePath) {
                Write-Warning "  静态链接缺少 Source 路径，跳过: $($link.Desc)"
                continue
            }
        }
        
        $targetPath = $link.Target
        $linkType   = $link.Type
        $backup     = $link.Backup
        $desc       = $link.Desc
        
        Write-Host "  >>> 处理重解析点: $desc" -ForegroundColor Cyan
        Write-Host "      源: $sourcePath" -ForegroundColor Gray
        Write-Host "      目标: $targetPath" -ForegroundColor Gray
        
        # 确保目标路径的父目录存在
        if ($linkType -eq "Junction" -or (Test-Path $targetPath -PathType Container)) {
            if (-not (Test-Path $targetPath)) {
                if ($PSCmdlet.ShouldProcess($targetPath, "创建目标目录")) {
                    New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
                    Write-Host "  [+] 已创建目标目录: $targetPath" -ForegroundColor Green
                }
            }
        } elseif ($linkType -eq "SymbolicLink") {
            $parentDir = Split-Path $targetPath -Parent
            if (-not (Test-Path $parentDir)) {
                if ($PSCmdlet.ShouldProcess($parentDir, "创建目标文件父目录")) {
                    New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                    Write-Host "  [+] 已创建父目录: $parentDir" -ForegroundColor Green
                }
            }
        }
        
        # 处理源路径
        if (Test-Path $sourcePath) {
            $item = Get-Item $sourcePath -Force
            # 如果已经是正确的链接，跳过
            if ($item.LinkType -eq $linkType -or ($linkType -eq "Junction" -and $item.LinkType -eq "Junction")) {
                if ($item.Target -eq $targetPath) {
                    
                    if (-not (Test-Path $targetPath)) {
                        Write-Warning "  [!] 检测到死链：C 盘软链接存在，但 D 盘目标文件已丢失！"
                        $backupPath = "$sourcePath.backup"
                        if (Test-Path $backupPath) {
                            Write-Host "  [+] 发现 C 盘历史备份，正在自动抢救恢复至 D 盘..." -ForegroundColor Yellow
                            Copy-Item -Path $backupPath -Destination $targetPath -Force
                            Write-Host "  [+] 恢复成功！终端配置已找回。" -ForegroundColor Green
                        } else {
                            Write-Warning "  [!] 无备份可恢复。已自动清理无效死链，请重启软件让其生成默认配置。"
                            Remove-Item $sourcePath -Force
                        }
                    } else {
                        Write-Host "  [-] 链接已存在且指向正确，跳过。" -ForegroundColor Gray
                    }
                    continue
                } else {
                    Write-Warning "  检测到已有链接但指向不同目标，将先移除再创建新链接。"
                    if ($PSCmdlet.ShouldProcess($sourcePath, "移除现有链接")) {
                        Remove-Item $sourcePath -Force
                        Write-Host "  [+] 已移除旧的链接。" -ForegroundColor Green
                    }
                }
            }
            # 不是链接，或类型不匹配
            else {
                # 针对 SymbolicLink 的严格处理：v5.31 升级为智能交互式冲突解决
                if ($linkType -eq "SymbolicLink") {
                    $targetExists = Test-Path $targetPath
                    if ($targetExists) {
                        Write-Warning "  冲突拦截：C 盘与 D 盘同时存在同名普通文件！"
                        Write-Host "      C 盘源路径: $sourcePath (修改时间: $((Get-Item $sourcePath).LastWriteTime))" -ForegroundColor Yellow
                        Write-Host "      D 盘目标路径: $targetPath (修改时间: $((Get-Item $targetPath).LastWriteTime))" -ForegroundColor Yellow
                        
                        if (-not $WhatIfPreference) {
                            $choice = Read-Host "  [?] 请选择决议: [1] C 盘强行覆盖 D 盘 [2] D 盘保留并直接连接 [3] 跳过不处理 (输入 1/2/3)"
                            if ($choice -eq '1') {
                                Copy-Item -Path $targetPath -Destination "$targetPath.backup" -Force
                                Copy-Item -Path $sourcePath -Destination "$sourcePath.backup" -Force
                                Copy-Item -Path $sourcePath -Destination $targetPath -Force
                                Remove-Item $sourcePath -Force
                                Write-Host "  [+] 已强推 C 盘数据至 D 盘，原 D 盘文件已安全备份为 .backup。" -ForegroundColor Green
                            } elseif ($choice -eq '2') {
                                Copy-Item -Path $sourcePath -Destination "$sourcePath.backup" -Force
                                Remove-Item $sourcePath -Force
                                Write-Host "  [+] 已安全剥离 C 盘文件，改用 D 盘历史配置文件连接。" -ForegroundColor Green
                            } else {
                                Write-Host "  [-] 安全挂起，跳过本轮链接生成。" -ForegroundColor Gray
                                continue
                            }
                        } else {
                            continue
                        }
                    } else {
                        # 目标文件不存在，可以安全迁移
                        Write-Host "  [迁移] 检测到已有内容且不是链接，将内容迁移到 D 盘后建立软链接。" -ForegroundColor Yellow
                        if ($PSCmdlet.ShouldProcess($sourcePath, "迁移内容到 $targetPath")) {
                            Copy-Item -Path $sourcePath -Destination "$sourcePath.backup" -Force
                            Copy-Item -Path $sourcePath -Destination $targetPath -Force
                            Write-Host "  [+] 已迁移内容到: $targetPath (并在 C 盘保留了 .backup 备份)" -ForegroundColor Green
                            try {
                                Remove-Item $sourcePath -Force
                                Write-Host "  [+] 已删除原文件: $sourcePath" -ForegroundColor Green
                            } catch {
                                Write-Error "  删除源文件失败: $($_.Exception.Message)"
                                Write-Host "      请手动删除 $sourcePath 后重新运行脚本。" -ForegroundColor Red
                                continue
                            }
                        }
                    }
                }
                # Junction 的处理
                elseif ($linkType -eq "Junction") {
                    if ($backup) {
                        $backupPath = "$sourcePath.backup"
                        Write-Warning "  检测到已有内容且不是链接，将备份到 $backupPath 后替换。"
                        if ($PSCmdlet.ShouldProcess($sourcePath, "备份到 $backupPath 并删除原内容")) {
                            if (Test-Path $sourcePath -PathType Container) {
                                Copy-Item -Path $sourcePath -Destination $backupPath -Recurse -Force
                                Remove-Item $sourcePath -Recurse -Force
                            } else {
                                Copy-Item -Path $sourcePath -Destination $backupPath -Force
                                Remove-Item $sourcePath -Force
                            }
                            Write-Host "  [+] 已备份原内容。" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Warning "  源路径已存在且不是链接，但备份未启用，将直接覆盖。"
                        if ($PSCmdlet.ShouldProcess($sourcePath, "强制删除现有内容")) {
                            if (Test-Path $sourcePath -PathType Container) {
                                Remove-Item $sourcePath -Recurse -Force
                            } else {
                                Remove-Item $sourcePath -Force
                            }
                        }
                    }
                }
            }
        }
        
        # 创建链接（如果源路径现在不存在）
        if (-not (Test-Path $sourcePath)) {
            if ($linkType -eq "SymbolicLink" -and -not $canCreateSymlink) {
                Write-Warning "  跳过创建 SymbolicLink（权限不足）。请开启开发者模式或以管理员身份运行。" -ForegroundColor Red
                continue
            }
            if ($PSCmdlet.ShouldProcess($sourcePath, "创建 $linkType 指向 $targetPath")) {
                try {
                    # v5.32 修复：强制加入 -ErrorAction Stop，击穿非终止错误伪绿假象
                    New-Item -Path $sourcePath -ItemType $linkType -Target $targetPath -Force -ErrorAction Stop | Out-Null
                    Write-Host "  [+] 已创建 $linkType : $sourcePath -> $targetPath" -ForegroundColor Green
                } catch {
                    Write-Error "  [!] 遭遇特权异常，断链创设失败: $($_.Exception.Message)"
                    
                    # v5.32 安全回滚机制：发生意外立刻“退货”，拒绝死链，拯救原始资产
                    if (Test-Path "$sourcePath.backup") {
                        Copy-Item -Path "$sourcePath.backup" -Destination $sourcePath -Force
                        Write-Host "  [+] 熔断保护生效：已原子化拉回原始本地配置 (.backup) 并完全复位 C 盘。" -ForegroundColor Yellow
                    } elseif (Test-Path $targetPath) {
                        Copy-Item -Path $targetPath -Destination $sourcePath -Force
                        Write-Host "  [+] 熔断保护生效：已将迁移至 D 盘的数据紧急退货拷贝回 C 盘，防止配置死锁挂起。" -ForegroundColor Yellow
                    }
                    
                    if ($linkType -eq "SymbolicLink") {
                        Write-Host "      致命原因：必须以管理员身份运行 PowerShell，或前往系统设置开启 Windows'开发者模式'。" -ForegroundColor Red
                    }
                }
            }
        }
    }
}

# ------------------------------------------------------------------------------
# 8. 自动检测代理并设置环境变量
# ------------------------------------------------------------------------------

function Set-ProxyFromLocalPort {
    $commonPorts = @(7890, 10809, 10808)
    $proxyUrl = $null
    
    foreach ($port in $commonPorts) {
        if (Test-ProxyPort -Port $port) {
            $detectedUrl = "http://127.0.0.1:$port"
            $useDetected = Read-Host "  [?] 检测到可能的本地代理 ($detectedUrl)，是否使用？(y/n) [默认 y]"
            if ([string]::IsNullOrWhiteSpace($useDetected) -or $useDetected -eq 'y') {
                $proxyUrl = $detectedUrl
                break
            }
        }
    }
    
    if (-not $proxyUrl) {
        $manualProxy = Read-Host "  [?] 请输入您的代理地址 (例如 http://127.0.0.1:10808)，直接回车则不使用代理"
        if (-not [string]::IsNullOrWhiteSpace($manualProxy)) {
            $proxyUrl = $manualProxy
        }
    }

    if ($proxyUrl) {
        Write-Host "  [+] 将自动设置环境变量 HTTP_PROXY/HTTPS_PROXY = $proxyUrl" -ForegroundColor Green
        $env:HTTP_PROXY = $proxyUrl
        $env:HTTPS_PROXY = $proxyUrl
        
        try {
            [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($proxyUrl)
            Write-Host "  [+] PowerShell 底层网络组件已强制导流至该代理。" -ForegroundColor Green
        } catch {
            Write-Warning "  [!] 无法配置底层网络组件代理，部分请求可能依然走直连。"
        }
        return $true
    }
    
    Write-Host "  [-] 已跳过代理配置，将尝试直连网络。" -ForegroundColor Gray
    return $false
}

# ------------------------------------------------------------------------------
# 9. 主路由
# ------------------------------------------------------------------------------

if ($Clean -and $Update) {
    Write-Error "参数 -Clean 和 -Update 不能同时使用。"
    exit 1
}
if ($ArchiveConfig -and (-not $Clean)) {
    Write-Warning "参数 -ArchiveConfig 仅在与 -Clean 一起使用时有效。将自动启用 -Clean。"
    $Clean = $true
}
if ($Purge -and (-not $Clean)) {
    Write-Warning "参数 -Purge 仅在与 -Clean 一起使用时有效。将自动启用 -Clean。"
    $Clean = $true
}

if (-not (Test-WriteableD)) { exit 1 }
Test-NoPathConflicts

if ($Clean) {
    Invoke-Cleanup
    exit 0
}

if ($Update) {
    $scoopExePath = Join-Path $ScoopRoot "shims\scoop.exe"
    $scoopInstalled = Test-Path $scoopExePath
    $profileDirExists = Test-Path $CentralPowerShellDir
    $initialized = $scoopInstalled -and $profileDirExists
    if (-not $initialized) {
        Write-Host ">>> 检测到 Scoop 未完整安装或配置目录缺失，将自动转为完整初始化模式。" -ForegroundColor Yellow
        $Update = $false
    }
}

if ($Update) {
    Write-Host ">>> 增量追加模式：仅添加缺失的目录/文件、变量、工具和 Profile 配置。" -ForegroundColor Cyan
    Write-Host ">>> 注意：此模式不会覆盖任何已存在的 D 盘配置文件。" -ForegroundColor Yellow
    Write-Host ">>> 对于 SymbolicLink，若 D 盘目标已存在将提示用户手动处理，不会自动覆盖。" -ForegroundColor Yellow
    
    Invoke-DirectoryAndVariableSetup
    Update-UserPath -PathsToRegister $PriorityPaths
    Invoke-ScoopToolInstallation
    Invoke-ProfileSetup
    Invoke-SymlinkSetup
    
    Write-Host ">>> 增量追加完成。" -ForegroundColor Green
    exit 0
}

# 完整初始化模式
try {
    Write-Host ">>> 正在启动 Windows 开发基座完整初始化 (WhatIf=$WhatIfPreference)..." -ForegroundColor Cyan

    # ---- 管理员身份检查（破解 Scoop 与 软链接 的权限死锁） ----
    $isAdmin = Test-Admin
    $scoopExePath = Join-Path $ScoopRoot "shims\scoop.exe"
    $scoopAlreadyInstalled = Test-Path $scoopExePath
    if ($isAdmin -and (-not $scoopAlreadyInstalled)) {
        Write-Warning "检测到您正在以管理员身份运行，且 Scoop 尚未安装。"
        Write-Host "为打破软链接创建与 Scoop 安装的权限死锁，脚本将启用 -RunAsAdmin 参数强制执行底层部署。" -ForegroundColor Yellow
    } elseif ($isAdmin -and $scoopAlreadyInstalled) {
        Write-Warning "当前以管理员身份运行，但 Scoop 已存在。后续操作仍可能因权限问题失败，建议日常开发以普通用户身份运行。"
    }

    # ---- 自动检测并设置代理 ----
    Write-Host ">>> 初始化网络环境..." -ForegroundColor Cyan
    Set-ProxyFromLocalPort

    # ---- 目录与变量创建 ----
    Invoke-DirectoryAndVariableSetup

    # ---- PATH 注册表同步 ----
    Write-Host ">>> 正在校验并写入全局 PATH 优先级..." -ForegroundColor Cyan
    Update-UserPath -PathsToRegister $PriorityPaths

    # ---- 网络连通性测试（已通过环境变量使用代理） ----
    Write-Host ">>> 检查上游网络连通状态..." -ForegroundColor Cyan
    $networkOk = $false
    try {
        Invoke-WebRequest -Uri "https://github.com" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop | Out-Null
        Write-Host "  [+] GitHub 连通性测试通过，网络就绪。" -ForegroundColor Green
        $networkOk = $true
    } catch {
        Write-Warning "  GitHub 连接受阻。请检查代理设置或网络环境。"
        Write-Host "    已配置的代理参数: HTTP_PROXY=$($env:HTTP_PROXY)" -ForegroundColor Yellow
        
        if (-not $WhatIfPreference) {
            $forceDeploy = Read-Host "  [?] 是否无视网络警告，强制尝试部署 Scoop？(y/n)"
            if ($forceDeploy -eq 'y') {
                $networkOk = $true
                Write-Host "  [!] 已强制解除网络阻断，继续执行部署进程。" -ForegroundColor Magenta
            }
        }
    }
    
    # ---- 设置 SCOOP 环境变量 ----
    if ($PSCmdlet.ShouldProcess("系统全局 SCOOP 变量", "注册到用户作用域 -> $ScoopRoot")) {
        [Environment]::SetEnvironmentVariable("SCOOP", $ScoopRoot, "User")
        $env:SCOOP = $ScoopRoot
    }
    
    $scoopExe = Join-Path $ScoopRoot "shims\scoop.exe"
    $scoopInstalled = Test-Path $scoopExe
    
    # ---- Scoop 底层核心部署 ----
    if (-not $scoopInstalled) {
        if ($PSCmdlet.ShouldProcess("Scoop 系统框架", "下载并部署底层运行库")) {
            Write-Host ">>> 正在部署 Scoop 核心基座..." -ForegroundColor Cyan
            if ($networkOk) {
                if ($isAdmin) {
                    # 管理员模式下，利用 Scoop 支持的 -RunAsAdmin 参数强制越权安装
                    Invoke-Expression "& {$(Invoke-RestMethod -Uri https://get.scoop.sh)} -RunAsAdmin"
                } else {
                    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
                }
                $scoopInstalled = $true
            } else {
                Write-Error "严重错误：网络无法抵达目标阵列，Scoop 部署中止。"
                exit 1
            }
        } else {
            $scoopInstalled = $true
        }
    }
    
    # ---- Scoop 工具链安装 ----
    if ($scoopInstalled -and (Test-ScoopAvailable -ExePath $scoopExe)) {
        Write-Host ">>> 同步本地软件索引库..." -ForegroundColor Cyan
        if ($PSCmdlet.ShouldProcess("Scoop 应用索引", "执行 update 同步")) { & scoop update }
        
        Write-Host ">>> 校验 Git 底层版本控制引擎..." -ForegroundColor Cyan
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            if ($PSCmdlet.ShouldProcess("Git 核心引擎", "通过 Scoop 生态安装")) { & scoop install git }
        }
        
        Invoke-ScoopToolInstallation
    } else {
        if (-not $WhatIfPreference) {
            Write-Warning "未在磁盘检测到 Scoop 二进制核心，跳过工具链部署逻辑。"
        }
    }
    
    # ---- Git 自动配置 ----
    if ($AutoConfigGit -and (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host ">>> 正在写入 Git 全局签名..." -ForegroundColor Cyan
        if ($PSCmdlet.ShouldProcess("Git 全局配置", "写入用户名与邮箱")) {
            git config --global user.name "$GitUserName"
            git config --global user.email "$GitUserEmail"
            Write-Host "  [+] 已应用开发者身份: $GitUserName" -ForegroundColor Green
        }
    }
    
    # ---- Node.js NPM 劫持 ----
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host ">>> 正在劫持 Node.js 全局安装路径..." -ForegroundColor Cyan
        if (-not (Test-Path $NpmGlobalPrefix)) {
            if ($PSCmdlet.ShouldProcess($NpmGlobalPrefix, "创建 NPM 专属全局目录")) {
                New-Item -Path $NpmGlobalPrefix -ItemType Directory -Force | Out-Null
            }
        }
        $activePrefix = npm config get prefix
        if ($activePrefix -ne $NpmGlobalPrefix) {
            if ($PSCmdlet.ShouldProcess("NPM Prefix 参数", "将其强行重定向至 -> $NpmGlobalPrefix")) {
                npm config set prefix "$NpmGlobalPrefix"
                Write-Host "  [+] Node 全局安装已成功导流至目标数据区。" -ForegroundColor Green
            }
        }
    }
    
    # ---- PowerShell Profile 配置 ----
    Invoke-ProfileSetup
    
    # ---- 重解析点创建 ----
    Invoke-SymlinkSetup
    
    # ---- 审计报告 ----
    if ($WhatIfPreference) {
        Write-Host "`n=========================================================================" -ForegroundColor Cyan
        Write-Host " [WhatIf 沙盒模式] 预览评估完成。系统底层未发生任何物理或注册表更改。" -ForegroundColor Yellow
        Write-Host "=========================================================================" -ForegroundColor Cyan
    } else {
        Write-Host "`n=========================================================================" -ForegroundColor Cyan
        Write-Host " 基座构建完成。当前环境映射拓扑图：" -ForegroundColor Green
        Write-Host "=========================================================================" -ForegroundColor Cyan
        foreach ($entry in $WorkspaceConfig) {
            $statusFlag = if ($entry.Env) { "[$($entry.Env)]" } else { "[物理路径]" }
            $typeFlag = if ($entry.ItemType -eq "File") { "(文件)" } else { "(目录)" }
            # QA1 修复：彻底放开颜色限制，完美支持所有终端主题皮肤
            Write-Host "  $statusFlag $typeFlag -> $($entry.Path)"
            Write-Host "              $($entry.Desc)" -ForegroundColor Gray
        }
        Write-Host "=========================================================================" -ForegroundColor Cyan
        Write-Host ">>> 终端环境已更新。请重启当前 PowerShell 以加载最终态映射配置。" -ForegroundColor Yellow
    }

} catch {
    Write-Error ">>> 部署进程遭遇致命异常: $($_.Exception.Message)"
    Write-Host ">>> 崩溃堆栈追踪: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}