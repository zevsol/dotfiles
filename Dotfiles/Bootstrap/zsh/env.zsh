# =========================================================
# ZSH ENV (CLEAN FINAL VERSION)
# =========================================================

# ===== History =====
HISTFILE="$HOME/.zsh_history"

# ===== fpath (WSL) =====
fpath=($DOTFILES/Systems/wsl/zsh/completions $fpath)

# =========================================================
# DOTFILES CORE ENV
# =========================================================
source /mnt/d/Dotfiles/Bootstrap/shared/env.sh

# =========================================================
# NIX (CRITICAL - MUST BE LAST)
# =========================================================
if [ -f /etc/profile.d/nix-daemon.sh ]; then
  . /etc/profile.d/nix-daemon.sh
fi
