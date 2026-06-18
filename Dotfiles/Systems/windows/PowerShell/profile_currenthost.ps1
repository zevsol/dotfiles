
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

# ==============================================================================
# 加载用户自定义配置（可选，手动维护）
# 将你的个性化配置放入以下文件，不会被脚本自动覆盖。
# ==============================================================================
$customProfile = Join-Path $PSScriptRoot "profile_custom.ps1"
if (Test-Path $customProfile) {
    . $customProfile
}




# ============================================
# starship
# ============================================
Invoke-Expression (&starship init powershell)


function dotfiles {
    git --git-dir=D:\.dotfiles-bare --work-tree=D:\ @args
}





# ============================================
# 代理函数
# ============================================
function eproxy {
    $env:http_proxy = "http://127.0.0.1:10808"
    $env:https_proxy = "http://127.0.0.1:10808"
    $env:all_proxy = "socks5://127.0.0.1:10808"
    Write-Host "✓ 代理已开启" -ForegroundColor Green
}

function unproxy {
    Remove-Item Env:http_proxy -ErrorAction SilentlyContinue
    Remove-Item Env:https_proxy -ErrorAction SilentlyContinue
    Remove-Item Env:all_proxy -ErrorAction SilentlyContinue
    Write-Host "✓ 代理已关闭" -ForegroundColor Green
}

# 查看当前代理（新增！）
function proxy {
    Write-Host "=== 当前终端代理配置 ===" -ForegroundColor Cyan
    Write-Host "http_proxy : $($env:http_proxy)"
    Write-Host "https_proxy: $($env:https_proxy)"
    Write-Host "all_proxy  : $($env:all_proxy)"
}

Set-Alias ep eproxy
Set-Alias un unproxy
Set-Alias p proxy


# ============================================
# env 环境变量加载
# ============================================
function env {
    param(
        [Parameter(Position = 0)]
        [string]$Key
    )

    # 读取 .env 文件
    $envFile = Join-Path "D:\Dotfiles\Config" ".env"
    $envData = @{}

    if (Test-Path $envFile) {
        Get-Content $envFile -Encoding UTF8 | ForEach-Object {
            $line = $_.Trim()
            if ($line -match "^([\w_-]+)=(.*)$") {
                $envData[$matches[1]] = $matches[2]
            }
        }
    }

    # 不带参数 → 显示所有可用变量
    if (-not $Key) {
        Write-Host "`n📋 可用环境变量：" -ForegroundColor Cyan
        if ($envData.Keys.Count -eq 0) {
            Write-Host "   .env 文件不存在或为空" -ForegroundColor Yellow
        }
        else {
            $envData.Keys | Sort-Object | ForEach-Object {
                Write-Host "   $_" -ForegroundColor Green
            }
        }
        return
    }

    # 参数 = all → 加载全部
    if ($Key -eq "all") {
        Write-Host "`n🚀 加载全部环境变量：" -ForegroundColor Cyan
        foreach ($k in $envData.Keys) {
            Set-Item "env:$k" $envData[$k]
            Write-Host " ✅ $k" -ForegroundColor Green
        }
        Write-Host "`n🎉 全部加载完成！`n" -ForegroundColor Cyan
        return
    }

    # 指定变量名 → 只加载这一个
    if ($envData.ContainsKey($Key)) {
        Set-Item "env:$Key" $envData[$Key]
        Write-Host "`n✅ 加载：$Key`n" -ForegroundColor Green
    }
    else {
        Write-Host "`n❌ 变量不存在：$Key`n" -ForegroundColor Red
    }
}


# ============================================
# Chrome 专用启动器（多 Profile 设计）
# ============================================

# Chrome 用户数据根目录（统一管理）
$ChromeProfileRoot = "D:\Data\Chrome_Instances"

# 确保根目录存在
if (-not (Test-Path $ChromeProfileRoot)) {
    New-Item -Path $ChromeProfileRoot -ItemType Directory -Force | Out-Null
}

# 1. 工作专用（Work）
function Chrome-Work {
    $profileDir = Join-Path $ChromeProfileRoot "Dev_Main"
    if (-not (Test-Path $profileDir)) {
        Write-Host "📁 首次启动，创建 Work 配置文件目录" -ForegroundColor Yellow
    }
    & "C:\Program Files\Google\Chrome\Application\chrome.exe" `
        --user-data-dir="$profileDir" `
        --lang=en-US
}

# 2. 测试专用（Test）
function Chrome-Test {
    $profileDir = Join-Path $ChromeProfileRoot "Dev_Test"
    if (-not (Test-Path $profileDir)) {
        Write-Host "📁 首次启动，创建 Test 配置文件目录" -ForegroundColor Yellow
    }
    & "C:\Program Files\Google\Chrome\Application\chrome.exe" `
        --user-data-dir="$profileDir" `
        --lang=en-US
}

# 3. 开发者专用（Sandbox）- 可选，预留
function Chrome-Sandbox {
    $profileDir = Join-Path $ChromeProfileRoot "Sandbox"
    if (-not (Test-Path $profileDir)) {
        Write-Host "📁 首次启动，创建 Dev 配置文件目录" -ForegroundColor Yellow
    }
    & "C:\Program Files\Google\Chrome\Application\chrome.exe" `
        --user-data-dir="$profileDir" `
        --lang=en-US
}

# 别名
Set-Alias ggc Chrome-Work
Set-Alias ggct Chrome-Test
Set-Alias ggcd Chrome-Sandbox

# ============================================
# 可选：Chrome 配置文件管理工具
# ============================================
function chrome-profiles {
    Write-Host "`n📁 Chrome 配置文件列表：" -ForegroundColor Cyan
    Get-ChildItem $ChromeProfileRoot -Directory | ForEach-Object {
        $size = [math]::Round((Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        Write-Host "  $($_.Name) - ${size} MB" -ForegroundColor White
    }
    Write-Host "`n"
}

function Set-Symlink {
    <#
    .SYNOPSIS
    Universal function to safely create symbolic links for files or directories.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Target,  # The real data path (e.g., D:\Dotfiles\Config\...)
        
        [Parameter(Mandatory = $true)]
        [string]$Link     # The shortcut path to be created (e.g., C:\Users\Zev\...)
    )

    # 1. Verify target exists to prevent dead links
    if (-not (Test-Path $Target)) {
        Write-Warning "[SKIP] Real target does not exist: $Target"
        return
    }

    # 2. Ensure parent directory of the link path exists
    $LinkDir = Split-Path $Link
    if (-not (Test-Path $LinkDir)) {
        New-Item -ItemType Directory -Path $LinkDir -Force | Out-Null
    }

    # 3. Handle existing files/folders at the link path
    if (Test-Path $Link) {
        $Item = Get-Item $Link -Force
        
        # If it's already a correct symlink, do nothing
        if ($Item.Attributes -match "ReparsePoint" -and $Item.Target -eq $Target) {
            Write-Host "[OK] Symlink already exists: $Link" -ForegroundColor DarkGray
            return
        }
        
        # If it's a real file/folder or wrong link, back it up
        $BackupPath = "$Link.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Rename-Item -Path $Link -NewName (Split-Path $BackupPath -Leaf) -Force
        Write-Host "[BACKUP] Occupied path renamed to: $BackupPath" -ForegroundColor Yellow
    }

    # 4. Create the symbolic link
    try {
        New-Item -ItemType SymbolicLink -Path $Link -Value $Target -Force | Out-Null
        Write-Host "[SUCCESS] $Link -> $Target" -ForegroundColor Green
    }
    catch {
        Write-Error "[FAILED] Could not create symlink: $_"
    }
}

# Add a convenient alias
Set-Alias ln Set-Symlink


# ==============================================================================
# rg + fzf Toolkit
# ==============================================================================

<#
1. Fuzzy Find File (ff)
Use this for broad searches when you only vaguely remember the file name.
Usage: 
  ff          -> Search in current directory
  ff D:\      -> Search in D drive
  code (ff)   -> Find a file and immediately open it in VSCode
#>
function ff {
    param([string]$TargetDir = ".")
    
    # Stream all files to fzf for fuzzy matching
    $file = rg --files "$TargetDir" 2>$null | fzf --prompt="🔍 Fuzzy File> " --border
    
    if ($file) {
        Write-Output $file
    }
}

<#
2. Find File Exact (ffe)
Use this for instant results when you know exactly what the file is called.
High performance: Let ripgrep filter the names before passing to fzf.
Usage: 
  ffe bashrc
  ffe json D:\
#>
function ffe {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        [string]$TargetDir = "."
    )
    
    # Pre-filter using rg's glob (-g) for maximum speed, then pipe to fzf
    $file = rg --files -g "*$FileName*" "$TargetDir" 2>$null | fzf --prompt="🎯 Exact File> " --border
    
    if ($file) {
        Write-Output $file
    }
}

<#
3. Find In Files (fif)
Interactive text search. Type to search file contents in real-time.
Usage: 
  fif          -> Search text in current directory
  fif D:\Code  -> Search text in specific directory
#>
function fif {
    param([string]$TargetDir = ".")
    
    # Note: fzf uses cmd.exe to run bindings on Windows, so we use '2>nul' instead of '2>$null'
    $reloadCmd = "rg --column --line-number --no-heading --color=always --smart-case -- {q} `"$TargetDir`" 2>nul"
    
    $selected = fzf --ansi --disabled `
        --prompt="📝 Content> " `
        --bind "start:reload($reloadCmd)" `
        --bind "change:reload($reloadCmd)" `
        --border

    if ($selected) {
        # The output format is FilePath:Line:Column:Text. We split by ':' and return just the path.
        $file = ($selected -split ':')[0]
        Write-Output $file
    }
}