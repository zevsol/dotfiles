#!/usr/bin/env bash

echo "[env] loading..."

# ===== 基础路径 =====
export DOTFILES="/mnt/d/Dotfiles"

# ===== XDG 规范 =====
export XDG_CONFIG_HOME="$DOTFILES/Systems/wsl"
export XDG_DATA_HOME="/mnt/d/Data/XDG"
export XDG_CACHE_HOME="/mnt/d/Cache/XDG"

# ===== 工具配置 (WSL) =====
export GIT_CONFIG_GLOBAL="$DOTFILES/Systems/wsl/git/.gitconfig"
export NPM_CONFIG_USERCONFIG="$DOTFILES/Systems/wsl/npm/.npmrc"
export PIP_CONFIG_FILE="$DOTFILES/Systems/wsl/pip/pip.ini"

# ===== 运行时缓存 =====
export CARGO_HOME="/mnt/d/Cache/Cargo"
export RUSTUP_HOME="/mnt/d/Cache/Rustup"
export GOPATH="/mnt/d/Cache/Go"

# ===== AI 模型 =====
export OLLAMA_MODELS="/mnt/d/Data/AI/Ollama"
export HF_HOME="/mnt/d/Data/AI/HuggingFace"

# ===== starship (WSL) =====
export STARSHIP_CONFIG="$DOTFILES/Systems/wsl/starship/starship.toml"