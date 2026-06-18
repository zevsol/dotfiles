#!/usr/bin/env bash

echo "[starship] loading..."

export STARSHIP_CONFIG="/mnt/d/Dotfiles/Systems/wsl/starship/starship.toml"

# 永远初始化（不管 nix）
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi