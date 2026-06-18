# ============================================
# Dotfiles Setup Script (Windows)
# ============================================
# 功能：一键构建 Windows 开发环境
# 用法：
#   .\setup.ps1              # 完整安装
#   .\setup.ps1 -Update      # 增量更新
#   .\setup.ps1 -Rollback    # 回滚
#   .\setup.ps1 -Verify      # 仅验证
#   .\setup.ps1 -DryRun      # 预览变更

param(
    [switch]$Update,
    [switch]$Rollback,
    [switch]$Verify,
    [switch]$DryRun
)

# ============================================
# 配置
# ============================================
$DotfilesRoot = "D:\Dotfiles"
$ManifestFile = Join-Path $DotfilesRoot "manifest.json"
$ModulesDir = Join-Path $DotfilesRoot "Scripts\modules"

# ============================================
# 加载模块
# ============================================
. (Join-Path $ModulesDir "state.ps1")
. (Join-Path $ModulesDir "verify.ps1")

# ============================================
# 主函数
# ============================================
function Main {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Dotfiles Setup (Windows)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # 检查 manifest.yml
    if (-not (Test-Path $ManifestFile)) {
        Write-Host "[ERROR] manifest.yml 不存在: $ManifestFile" -ForegroundColor Red
        return
    }

    # 加载 manifest
    $manifest = Get-Content $ManifestFile -Raw | ConvertFrom-Json

    # 根据参数执行
    if ($Rollback) {
        Invoke-Rollback
    } elseif ($Verify) {
        Invoke-Verification
    } elseif ($Update) {
        Invoke-Update -Manifest $manifest -DryRun:$DryRun
    } else {
        Invoke-Install -Manifest $manifest -DryRun:$DryRun
    }
}

# ============================================
# 完整安装
# ============================================
function Invoke-Install {
    param(
        [Parameter(Mandatory=$true)]
        $Manifest,
        [bool]$DryRun = $false
    )

    Write-Host "`n[Phase 1] 初始化状态" -ForegroundColor Yellow
    $stateDir = Initialize-State
    Backup-EnvironmentVariables -StateDir $stateDir
    Backup-Symlinks -StateDir $stateDir
    Backup-Files -StateDir $stateDir

    Write-Host "`n[Phase 2] 创建目录结构" -ForegroundColor Yellow
    foreach ($dir in $Manifest.directories.windows) {
        if ($DryRun) {
            Write-Host "  [DRY-RUN] 将创建: $($dir.path)" -ForegroundColor Gray
        } else {
            if (-not (Test-Path $dir.path)) {
                New-Item -ItemType Directory -Path $dir.path -Force | Out-Null
                Write-Host "  [CREATE] $($dir.path)" -ForegroundColor Green
                Write-ChangeLog -StateDir $stateDir -Action "CREATE_DIR" -Target $dir.path -Status "SUCCESS"
            } else {
                Write-Host "  [EXISTS] $($dir.path)" -ForegroundColor Gray
            }
        }
    }

    Write-Host "`n[Phase 3] 设置环境变量" -ForegroundColor Yellow
    foreach ($envVar in $Manifest.env.windows.PSObject.Properties) {
        $name = $envVar.Name
        $value = $envVar.Value.value

        if ($DryRun) {
            Write-Host "  [DRY-RUN] 将设置: $name = $value" -ForegroundColor Gray
        } else {
            $currentValue = [System.Environment]::GetEnvironmentVariable($name, "User")
            if ($currentValue -ne $value) {
                [System.Environment]::SetEnvironmentVariable($name, $value, "User")
                Write-Host "  [SET] $name = $value" -ForegroundColor Green
                Write-ChangeLog -StateDir $stateDir -Action "SET_ENV" -Target $name -Status "SUCCESS" -Details "从 '$currentValue' 改为 '$value'"
            } else {
                Write-Host "  [EXISTS] $name" -ForegroundColor Gray
            }
        }
    }

    Write-Host "`n[Phase 4] 创建符号链接" -ForegroundColor Yellow
    foreach ($symlink in $Manifest.symlinks.windows) {
        $source = $symlink.source -replace '\$HOME', $env:USERPROFILE
        $source = $source -replace '\$LOCALAPPDATA', $env:LOCALAPPDATA
        $target = $symlink.target

        if ($DryRun) {
            Write-Host "  [DRY-RUN] 将创建: $source -> $target" -ForegroundColor Gray
        } else {
            $result = New-Symlink -Source $source -Target $target -Type $symlink.type
            Write-Host "  [$($result.Status)] $source -> $target" -ForegroundColor $(if ($result.Status -eq "SUCCESS") { "Green" } else { "Yellow" })
            Write-ChangeLog -StateDir $stateDir -Action "CREATE_SYMLINK" -Target $source -Status $result.Status -Details $result.Message
        }
    }

    Write-Host "`n[Phase 5] 验证配置" -ForegroundColor Yellow
    $verificationResult = Invoke-FullVerification -Platform "windows"
    Export-VerificationReport -StateDir $stateDir -VerificationResult $verificationResult

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  安装完成!" -ForegroundColor Green
    Write-Host "  状态目录: $stateDir" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Cyan
}

# ============================================
# 增量更新
# ============================================
function Invoke-Update {
    param(
        [Parameter(Mandatory=$true)]
        $Manifest,
        [bool]$DryRun = $false
    )

    Write-Host "`n[Phase 1] 初始化状态" -ForegroundColor Yellow
    $stateDir = Initialize-State
    Backup-EnvironmentVariables -StateDir $stateDir
    Backup-Symlinks -StateDir $stateDir
    Backup-Files -StateDir $stateDir

    Write-Host "`n[Phase 2] 更新环境变量" -ForegroundColor Yellow
    foreach ($envVar in $Manifest.env.windows.PSObject.Properties) {
        $name = $envVar.Name
        $value = $envVar.Value.value

        if ($DryRun) {
            Write-Host "  [DRY-RUN] 将更新: $name = $value" -ForegroundColor Gray
        } else {
            $currentValue = [System.Environment]::GetEnvironmentVariable($name, "User")
            if ($currentValue -ne $value) {
                [System.Environment]::SetEnvironmentVariable($name, $value, "User")
                Write-Host "  [UPDATE] $name = $value" -ForegroundColor Green
                Write-ChangeLog -StateDir $stateDir -Action "UPDATE_ENV" -Target $name -Status "SUCCESS" -Details "从 '$currentValue' 改为 '$value'"
            } else {
                Write-Host "  [EXISTS] $name" -ForegroundColor Gray
            }
        }
    }

    Write-Host "`n[Phase 3] 验证配置" -ForegroundColor Yellow
    $verificationResult = Invoke-FullVerification -Platform "windows"
    Export-VerificationReport -StateDir $stateDir -VerificationResult $verificationResult

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  更新完成!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
}

# ============================================
# 回滚
# ============================================
function Invoke-Rollback {
    Write-Host "`n[Phase 1] 查找最新状态" -ForegroundColor Yellow
    $latestState = Get-LatestState

    if ($null -eq $latestState) {
        Write-Host "[ERROR] 无可用状态进行回滚" -ForegroundColor Red
        return
    }

    Write-Host "  最新状态: $latestState" -ForegroundColor Gray

    Write-Host "`n[Phase 2] 执行回滚" -ForegroundColor Yellow
    $result = Restore-State -StateDir $latestState

    if ($result) {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "  回滚完成!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
    } else {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "  回滚失败!" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Cyan
    }
}

# ============================================
# 验证
# ============================================
function Invoke-Verification {
    Write-Host "`n[Phase 1] 执行验证" -ForegroundColor Yellow
    $verificationResult = Invoke-FullVerification -Platform "windows"

    # 导出报告
    $stateDir = Initialize-State
    Export-VerificationReport -StateDir $stateDir -VerificationResult $verificationResult
}

# ============================================
# 创建符号链接
# ============================================
function New-Symlink {
    param(
        [string]$Source,
        [string]$Target,
        [string]$Type = "SymbolicLink"
    )

    # 检查目标是否存在
    if (-not (Test-Path $Target)) {
        return @{ Status = "SKIP"; Message = "目标不存在: $Target" }
    }

    # 检查源是否已存在
    if (Test-Path $Source) {
        $item = Get-Item $Source
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            if ($item.Target -eq $Target) {
                return @{ Status = "EXISTS"; Message = "符号链接已存在且正确" }
            }
            # 删除旧的符号链接
            Remove-Item $Source -Force
        } else {
            # 备份真实文件
            $backupPath = "$Source.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Rename-Item -Path $Source -NewName (Split-Path $backupPath -Leaf) -Force
            Write-Host "  [BACKUP] $Source -> $backupPath" -ForegroundColor Yellow
        }
    }

    # 创建符号链接
    try {
        if ($Type -eq "Junction") {
            New-Item -ItemType Junction -Path $Source -Target $Target -Force | Out-Null
        } else {
            New-Item -ItemType SymbolicLink -Path $Source -Target $Target -Force | Out-Null
        }
        return @{ Status = "SUCCESS"; Message = "符号链接创建成功" }
    } catch {
        return @{ Status = "ERROR"; Message = "创建失败: $_" }
    }
}

# ============================================
# 执行
# ============================================
Main
