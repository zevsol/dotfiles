# ============================================
# State Management Module
# ============================================
# 功能：备份当前状态、记录变更、支持回滚

function Initialize-State {
    <#
    .SYNOPSIS
    初始化状态目录
    #>
    $stateRoot = "D:\Dotfiles\.state"
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $stateDir = Join-Path $stateRoot $timestamp

    if (-not (Test-Path $stateRoot)) {
        New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
    }

    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }

    # 创建 latest 符号链接
    $latestLink = Join-Path $stateRoot "latest"
    if (Test-Path $latestLink) {
        Remove-Item $latestLink -Force
    }
    New-Item -ItemType SymbolicLink -Path $latestLink -Target $stateDir -Force | Out-Null

    return $stateDir
}

function Backup-EnvironmentVariables {
    <#
    .SYNOPSIS
    备份当前环境变量
    #>
    param([string]$StateDir)

    $backupFile = Join-Path $StateDir "env_backup.json"
    $envVars = [System.Environment]::GetEnvironmentVariables("User")

    $backup = @{}
    foreach ($key in $envVars.Keys) {
        $backup[$key] = $envVars[$key]
    }

    $backup | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupFile -Encoding UTF8
    Write-Host "[STATE] 环境变量已备份: $backupFile" -ForegroundColor Gray
}

function Backup-Symlinks {
    <#
    .SYNOPSIS
    备份当前符号链接
    #>
    param([string]$StateDir)

    $backupFile = Join-Path $StateDir "symlink_backup.json"
    $symlinks = @()

    $linkPaths = @(
        "$env:USERPROFILE\.wslconfig",
        "$env:USERPROFILE\.claude.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    )

    foreach ($path in $linkPaths) {
        if (Test-Path $path) {
            $item = Get-Item $path
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $symlinks += @{
                    Source = $path
                    Target = $item.Target
                    LinkType = $item.LinkType
                }
            }
        }
    }

    $symlinks | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupFile -Encoding UTF8
    Write-Host "[STATE] 符号链接已备份: $backupFile" -ForegroundColor Gray
}

function Backup-Files {
    <#
    .SYNOPSIS
    备份关键配置文件
    #>
    param([string]$StateDir)

    $backupDir = Join-Path $StateDir "files"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    $filesToBackup = @(
        "D:\Dotfiles\Systems\windows\git\.gitconfig",
        "D:\Dotfiles\Systems\windows\starship\starship.toml",
        "D:\Dotfiles\Systems\windows\PowerShell\profile_currenthost.ps1",
        "D:\Dotfiles\Systems\wsl\git\.gitconfig",
        "D:\Dotfiles\Systems\wsl\starship\starship.toml",
        "D:\Dotfiles\Systems\wsl\zsh\zshrc"
    )

    foreach ($file in $filesToBackup) {
        if (Test-Path $file) {
            $relativePath = $file.Replace("D:\Dotfiles\", "")
            $destFile = Join-Path $backupDir $relativePath
            $destDir = Split-Path $destFile -Parent

            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }

            Copy-Item -Path $file -Destination $destFile -Force
        }
    }

    Write-Host "[STATE] 配置文件已备份: $backupDir" -ForegroundColor Gray
}

function Write-ChangeLog {
    <#
    .SYNOPSIS
    记录变更日志
    #>
    param(
        [string]$StateDir,
        [string]$Action,
        [string]$Target,
        [string]$Status,
        [string]$Details = ""
    )

    $logFile = Join-Path $StateDir "changes.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Action | $Target | $Status | $Details"

    Add-Content -Path $logFile -Value $logEntry
}

function Restore-State {
    <#
    .SYNOPSIS
    回滚到上一状态
    #>
    param([string]$StateDir)

    if (-not (Test-Path $StateDir)) {
        Write-Host "[ERROR] 状态目录不存在: $StateDir" -ForegroundColor Red
        return $false
    }

    # 恢复环境变量
    $envBackup = Join-Path $StateDir "env_backup.json"
    if (Test-Path $envBackup) {
        $backup = Get-Content $envBackup -Raw | ConvertFrom-Json
        foreach ($key in $backup.PSObject.Properties.Name) {
            [System.Environment]::SetEnvironmentVariable($key, $backup.$key, "User")
        }
        Write-Host "[RESTORE] 环境变量已恢复" -ForegroundColor Green
    }

    # 恢复符号链接
    $symlinkBackup = Join-Path $StateDir "symlink_backup.json"
    if (Test-Path $symlinkBackup) {
        $symlinks = Get-Content $symlinkBackup -Raw | ConvertFrom-Json
        foreach ($link in $symlinks) {
            if (Test-Path $link.Source) {
                Remove-Item $link.Source -Force
            }
            New-Item -ItemType SymbolicLink -Path $link.Source -Target $link.Target -Force | Out-Null
        }
        Write-Host "[RESTORE] 符号链接已恢复" -ForegroundColor Green
    }

    # 恢复文件
    $filesDir = Join-Path $StateDir "files"
    if (Test-Path $filesDir) {
        Copy-Item -Path "$filesDir\*" -Destination "D:\Dotfiles\Systems\" -Recurse -Force
        Write-Host "[RESTORE] 配置文件已恢复" -ForegroundColor Green
    }

    return $true
}

function Get-LatestState {
    <#
    .SYNOPSIS
    获取最新状态目录
    #>
    $stateRoot = "D:\Dotfiles\.state"
    $latestLink = Join-Path $stateRoot "latest"

    if (Test-Path $latestLink) {
        return (Get-Item $latestLink).Target
    }

    return $null
}

function Show-StateHistory {
    <#
    .SYNOPSIS
    显示状态历史
    #>
    $stateRoot = "D:\Dotfiles\.state"

    if (-not (Test-Path $stateRoot)) {
        Write-Host "[INFO] 无状态历史" -ForegroundColor Yellow
        return
    }

    $states = Get-ChildItem -Path $stateRoot -Directory | Sort-Object Name -Descending
    Write-Host "`n状态历史:" -ForegroundColor Cyan
    foreach ($state in $states) {
        $logFile = Join-Path $state.FullName "changes.log"
        $changes = if (Test-Path $logFile) { (Get-Content $logFile | Measure-Object).Count } else { 0 }
        Write-Host "  $($state.Name) - $changes 条变更" -ForegroundColor White
    }
}
