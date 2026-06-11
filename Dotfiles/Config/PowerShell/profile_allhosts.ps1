
# ==============================================================================
# ZevSol PowerShell Profile (集中式配置)
# 生成时间: 2026-06-10 15:24:07
# 此文件由 Zev-Env-Setup.ps1 自动管理。
# 注意：-Update 模式下不会覆盖已存在的文件，但完整初始化会覆盖。
# ==============================================================================

# 确保自定义 PATH 优先级（会话级双保险）
$priorityPaths = @("D:\Dotfiles\Bin", "D:\Dotfiles\Scripts", "D:\Scoop\shims", "D:\Data\Npm_Global\bin")
foreach ($p in $priorityPaths) {
    if (Test-Path $p) {
        if ($env:PATH -notlike "*$p*") { $env:PATH = "$p;$env:PATH" }
    }
}

# 导航别名
function cd-vault { Set-Location "E:\Vault" }
function cd-e { Set-Location "E:\" }
function cd-code { Set-Location "D:\Workspace" }
function cd-media { Set-Location "D:\Media" }
function cd-lab { Set-Location "D:\Workspace\Lab" }
function cd-down { Set-Location "E:\Downloads" }
function cd-d { Set-Location "D:\" }
function cd-tools { Set-Location "E:\Portable" }
function cd-zevsol { Set-Location "D:\Workspace\ZevSol" }
function cd-dot { Set-Location "D:\Dotfiles" }
# ==============================================================================
# 加载用户自定义配置（可选，手动维护）
# 将你的个性化配置放入以下文件，不会被脚本自动覆盖。
# ==============================================================================
$customProfile = Join-Path $PSScriptRoot "profile_custom.ps1"
if (Test-Path $customProfile) {
    . $customProfile
}
