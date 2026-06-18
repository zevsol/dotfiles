#!/usr/bin/env zsh

# =========================
# DOTFILES BOOTSTRAP (ZSH)
# =========================

DOTFILES="/mnt/d/Dotfiles"

export DOTFILES

# ===== 共享环境层 =====
source "$DOTFILES/Bootstrap/shared/env.sh"
source "$DOTFILES/Bootstrap/shared/tools.sh"

# ===== zsh 专用模块 =====
source "$DOTFILES/Bootstrap/zsh/env.zsh"
source "$DOTFILES/Bootstrap/zsh/alias.zsh"
source "$DOTFILES/Bootstrap/zsh/history.zsh"
source "$DOTFILES/Bootstrap/zsh/completion.zsh"
source "$DOTFILES/Bootstrap/zsh/proxy.zsh"
source "$DOTFILES/Bootstrap/zsh/tools.zsh"
source "$DOTFILES/Bootstrap/zsh/starship.zsh"
source "$DOTFILES/Bootstrap/zsh/nix.zsh"
