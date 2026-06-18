#!/usr/bin/env bash

# =========================
# DOTFILES BOOTSTRAP (BASH)
# =========================

DOTFILES="/mnt/d/Dotfiles"

export DOTFILES

# ===== 共享环境层 =====
source "$DOTFILES/Bootstrap/shared/env.sh"
source "$DOTFILES/Bootstrap/shared/tools.sh"

# ===== bash 专用模块 =====
source "$DOTFILES/Bootstrap/bash/alias.sh"
source "$DOTFILES/Bootstrap/bash/history.sh"
source "$DOTFILES/Bootstrap/bash/starship.sh"
source "$DOTFILES/Bootstrap/bash/nix.sh"
