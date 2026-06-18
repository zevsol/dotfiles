# ===== nix 检测 =====

if command -v nix >/dev/null 2>&1; then
    # 进入 dev shell
    alias dev="nix develop /mnt/d/Dotfiles/Systems/wsl/nix"
fi
