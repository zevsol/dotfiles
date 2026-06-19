# =========================
# DOTFILES BOOTSTRAP (ZSH)
# =========================
# 被 ~/.zshrc source，DOTFILES 变量由调用方设置

# ===== 共享工具层 =====
source "$DOTFILES/Bootstrap/shared/tools.sh"

# ===== zsh 专用模块 =====
# env.zsh 内部会 source shared/env.sh 并加载 nix daemon
source "$DOTFILES/Bootstrap/zsh/env.zsh"
source "$DOTFILES/Bootstrap/zsh/alias.zsh"
source "$DOTFILES/Bootstrap/zsh/history.zsh"
source "$DOTFILES/Bootstrap/zsh/completion.zsh"
source "$DOTFILES/Bootstrap/zsh/proxy.zsh"
source "$DOTFILES/Bootstrap/zsh/tools.zsh"
source "$DOTFILES/Bootstrap/zsh/starship.zsh"
source "$DOTFILES/Bootstrap/zsh/nix.zsh"
