# ============================================
# Verify Module
# ============================================
# 功能：3 层验证（文件存在性、内容正确性、功能验证）

function Test-DirectoryExists {
    <#
    .SYNOPSIS
    验证目录是否存在
    #>
    param([string]$Path)

    if (Test-Path $Path -PathType Container) {
        return @{ Status = "PASS"; Message = "目录存在: $Path" }
    } else {
        return @{ Status = "FAIL"; Message = "目录不存在: $Path" }
    }
}

function Test-FileExists {
    <#
    .SYNOPSIS
    验证文件是否存在
    #>
    param([string]$Path)

    if (Test-Path $Path -PathType Leaf) {
        $size = (Get-Item $Path).Length
        return @{ Status = "PASS"; Message = "文件存在: $Path ($size bytes)" }
    } else {
        return @{ Status = "FAIL"; Message = "文件不存在: $Path" }
    }
}

function Test-SymlinkValid {
    <#
    .SYNOPSIS
    验证符号链接是否有效
    #>
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return @{ Status = "FAIL"; Message = "符号链接不存在: $Path" }
    }

    $item = Get-Item $Path
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        return @{ Status = "FAIL"; Message = "不是符号链接: $Path" }
    }

    $target = $item.Target
    if (-not (Test-Path $target)) {
        return @{ Status = "FAIL"; Message = "符号链接目标不存在: $Path -> $target" }
    }

    return @{ Status = "PASS"; Message = "符号链接有效: $Path -> $target" }
}

function Test-EnvironmentVariable {
    <#
    .SYNOPSIS
    验证环境变量是否正确
    #>
    param(
        [string]$Name,
        [string]$ExpectedValue
    )

    $actualValue = [System.Environment]::GetEnvironmentVariable($Name, "User")

    if ($null -eq $actualValue) {
        return @{ Status = "FAIL"; Message = "环境变量不存在: $Name" }
    }

    if ($actualValue -eq $ExpectedValue) {
        return @{ Status = "PASS"; Message = "环境变量正确: $Name = $actualValue" }
    } else {
        return @{ Status = "WARN"; Message = "环境变量值不同: $Name (期望: $ExpectedValue, 实际: $actualValue)" }
    }
}

function Test-GitConfig {
    <#
    .SYNOPSIS
    验证 Git 配置
    #>
    param([string]$Platform)

    try {
        if ($Platform -eq "windows") {
            $autocrlf = git config --global core.autocrlf 2>$null
            if ($autocrlf -eq "true") {
                return @{ Status = "PASS"; Message = "Git autocrlf = true (Windows)" }
            } else {
                return @{ Status = "FAIL"; Message = "Git autocrlf 不正确: $autocrlf" }
            }
        } else {
            $autocrlf = git config --global core.autocrlf 2>$null
            if ($autocrlf -eq "input") {
                return @{ Status = "PASS"; Message = "Git autocrlf = input (WSL)" }
            } else {
                return @{ Status = "FAIL"; Message = "Git autocrlf 不正确: $autocrlf" }
            }
        }
    } catch {
        return @{ Status = "FAIL"; Message = "Git 配置验证失败: $_" }
    }
}

function Test-StarshipConfig {
    <#
    .SYNOPSIS
    验证 Starship 配置
    #>
    param([string]$ConfigPath)

    if (-not (Test-Path $ConfigPath)) {
        return @{ Status = "FAIL"; Message = "Starship 配置文件不存在: $ConfigPath" }
    }

    $content = Get-Content $ConfigPath -Raw
    if ($content -match "schema") {
        return @{ Status = "PASS"; Message = "Starship 配置有效: $ConfigPath" }
    } else {
        return @{ Status = "WARN"; Message = "Starship 配置可能无效: $ConfigPath" }
    }
}

function Test-ToolInstalled {
    <#
    .SYNOPSIS
    验证工具是否已安装
    #>
    param([string]$ToolName)

    try {
        $null = Get-Command $ToolName -ErrorAction Stop
        return @{ Status = "PASS"; Message = "工具已安装: $ToolName" }
    } catch {
        return @{ Status = "FAIL"; Message = "工具未安装: $ToolName" }
    }
}

function Invoke-FullVerification {
    <#
    .SYNOPSIS
    执行完整验证
    #>
    param([string]$Platform = "windows")

    $results = @()

    Write-Host "`n=== Layer 1: 文件存在性验证 ===" -ForegroundColor Cyan

    # 验证目录
    $directories = if ($Platform -eq "windows") {
        @(
            "D:\Dotfiles\Systems\windows",
            "D:\Dotfiles\Systems\windows\git",
            "D:\Dotfiles\Systems\windows\PowerShell",
            "D:\Dotfiles\Systems\windows\starship",
            "D:\Dotfiles\Systems\windows\ssh"
        )
    } else {
        @(
            "D:\Dotfiles\Systems\wsl",
            "D:\Dotfiles\Systems\wsl\git",
            "D:\Dotfiles\Systems\wsl\starship",
            "D:\Dotfiles\Systems\wsl\zsh",
            "D:\Dotfiles\Systems\wsl\ssh"
        )
    }

    foreach ($dir in $directories) {
        $result = Test-DirectoryExists -Path $dir
        $results += $result
        $color = if ($result.Status -eq "PASS") { "Green" } else { "Red" }
        Write-Host "  [$($result.Status)] $($result.Message)" -ForegroundColor $color
    }

    # 验证文件
    $files = if ($Platform -eq "windows") {
        @(
            "D:\Dotfiles\Systems\windows\git\.gitconfig",
            "D:\Dotfiles\Systems\windows\starship\starship.toml",
            "D:\Dotfiles\Systems\windows\PowerShell\profile_currenthost.ps1"
        )
    } else {
        @(
            "D:\Dotfiles\Systems\wsl\git\.gitconfig",
            "D:\Dotfiles\Systems\wsl\starship\starship.toml",
            "D:\Dotfiles\Systems\wsl\zsh\zshrc"
        )
    }

    foreach ($file in $files) {
        $result = Test-FileExists -Path $file
        $results += $result
        $color = if ($result.Status -eq "PASS") { "Green" } else { "Red" }
        Write-Host "  [$($result.Status)] $($result.Message)" -ForegroundColor $color
    }

    # 验证符号链接
    $symlinks = if ($Platform -eq "windows") {
        @(
            "$env:USERPROFILE\.wslconfig",
            "$env:USERPROFILE\.claude.json"
        )
    } else {
        @()
    }

    foreach ($link in $symlinks) {
        $result = Test-SymlinkValid -Path $link
        $results += $result
        $color = if ($result.Status -eq "PASS") { "Green" } else { "Red" }
        Write-Host "  [$($result.Status)] $($result.Message)" -ForegroundColor $color
    }

    Write-Host "`n=== Layer 2: 内容正确性验证 ===" -ForegroundColor Cyan

    # 验证环境变量
    $envVars = if ($Platform -eq "windows") {
        @(
            @{ Name = "GIT_CONFIG_GLOBAL"; Expected = "D:\Dotfiles\Systems\windows\git\.gitconfig" },
            @{ Name = "STARSHIP_CONFIG"; Expected = "D:\Dotfiles\Systems\windows\starship\starship.toml" }
        )
    } else {
        @()
    }

    foreach ($envVar in $envVars) {
        $result = Test-EnvironmentVariable -Name $envVar.Name -ExpectedValue $envVar.Expected
        $results += $result
        $color = if ($result.Status -eq "PASS") { "Green" } else { "Yellow" }
        Write-Host "  [$($result.Status)] $($result.Message)" -ForegroundColor $color
    }

    # 验证 Starship 配置
    $starshipPath = if ($Platform -eq "windows") {
        "D:\Dotfiles\Systems\windows\starship\starship.toml"
    } else {
        "D:\Dotfiles\Systems\wsl\starship\starship.toml"
    }

    $result = Test-StarshipConfig -ConfigPath $starshipPath
    $results += $result
    $color = if ($result.Status -eq "PASS") { "Green" } else { "Yellow" }
    Write-Host "  [$($result.Status)] $($result.Message)" -ForegroundColor $color

    Write-Host "`n=== Layer 3: 功能验证 ===" -ForegroundColor Cyan

    # 验证 Git
    $result = Test-GitConfig -Platform $Platform
    $results += $result
    $color = if ($result.Status -eq "PASS") { "Green" } else { "Red" }
    Write-Host "  [$($result.Status)] $($result.Message)" -ForegroundColor $color

    # 验证工具
    $tools = if ($Platform -eq "windows") {
        @("git", "starship", "node", "python")
    } else {
        @("git", "zsh")
    }

    foreach ($tool in $tools) {
        $result = Test-ToolInstalled -ToolName $tool
        $results += $result
        $color = if ($result.Status -eq "PASS") { "Green" } else { "Yellow" }
        Write-Host "  [$($result.Status)] $($result.Message)" -ForegroundColor $color
    }

    # 生成报告
    $passCount = ($results | Where-Object { $_.Status -eq "PASS" }).Count
    $failCount = ($results | Where-Object { $_.Status -eq "FAIL" }).Count
    $warnCount = ($results | Where-Object { $_.Status -eq "WARN" }).Count

    Write-Host "`n=== 验证总结 ===" -ForegroundColor Cyan
    Write-Host "  通过: $passCount" -ForegroundColor Green
    Write-Host "  失败: $failCount" -ForegroundColor Red
    Write-Host "  警告: $warnCount" -ForegroundColor Yellow

    $overallStatus = if ($failCount -eq 0) { "SUCCESS" } else { "FAILED" }
    Write-Host "  总体状态: $overallStatus" -ForegroundColor $(if ($overallStatus -eq "SUCCESS") { "Green" } else { "Red" })

    return @{
        Status = $overallStatus
        Results = $results
        PassCount = $passCount
        FailCount = $failCount
        WarnCount = $warnCount
    }
}

function Export-VerificationReport {
    <#
    .SYNOPSIS
    导出验证报告
    #>
    param(
        [string]$StateDir,
        [hashtable]$VerificationResult
    )

    $reportFile = Join-Path $StateDir "verification.yml"
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"

    $report = @"
# Verification Report
timestamp: $timestamp
status: $($VerificationResult.Status.ToLower())
summary:
  pass: $($VerificationResult.PassCount)
  fail: $($VerificationResult.FailCount)
  warn: $($VerificationResult.WarnCount)

results:
"@

    foreach ($result in $VerificationResult.Results) {
        $report += "`n  - status: $($result.Status.ToLower())"
        $report += "`n    message: `"$($result.Message)`""
    }

    $report | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Host "[REPORT] 验证报告已导出: $reportFile" -ForegroundColor Gray
}
