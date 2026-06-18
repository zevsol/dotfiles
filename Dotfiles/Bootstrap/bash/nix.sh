#!/usr/bin/env bash

echo "[nix] loading..."

if command -v nix >/dev/null 2>&1; then
    echo "[nix] detected"

    # 进入 dev shell（关键）
    alias dev="nix develop /mnt/d/Dotfiles/Systems/wsl/nix"
else
    echo "[nix] not installed"
fi