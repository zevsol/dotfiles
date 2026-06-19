#!/usr/bin/env bash

# =========================
# DOTFILES BOOTSTRAP (BASH)
# =========================
# 被 ~/.bashrc source，DOTFILES 变量由调用方设置

# ===== 共享环境层 =====
source "$DOTFILES/Bootstrap/shared/env.sh"
source "$DOTFILES/Bootstrap/shared/tools.sh"

# ===== bash 专用模块 =====
source "$DOTFILES/Bootstrap/bash/alias.sh"
source "$DOTFILES/Bootstrap/bash/history.sh"
source "$DOTFILES/Bootstrap/bash/starship.sh"

# ===== nix daemon（CRITICAL）=====
if [ -f /etc/profile.d/nix.sh ]; then
    . /etc/profile.d/nix.sh
fi

source "$DOTFILES/Bootstrap/bash/nix.sh"
