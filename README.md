# Zev's Dotfiles

This is my personal Windows 11 development environment automated sync repository.
**Core philosophy:** Manage dependencies via package managers (Scoop/Winget) and sync configurations using PowerShell symlinks. Zero bloated software bundles, keeping the system absolutely clean.

## 🚀 One-Click Restore

Run the following command directly in PowerShell (Run as Administrator) on a new machine:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
irm [zevsol.com/env](https://zevsol.com/env) | iex
