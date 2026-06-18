# ===== starship prompt =====

export STARSHIP_CONFIG="$DOTFILES/Systems/wsl/starship/starship.toml"

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
