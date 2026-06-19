# ===== nix 检测 =====

if command -v nix >/dev/null 2>&1; then
    # 进入 dev shell
    # 用法: dev [shell_name]  例如 dev ai, dev web
    dev() {
        local flake="/mnt/d/Dotfiles/Systems/wsl/nix"
        if [ -n "$1" ]; then
            nix develop "$flake#$1"
        else
            nix develop "$flake"
        fi
    }
fi
