#!/usr/bin/env bash

echo "[tools] loading..."

# =========================
# dotfiles git（WSL版）
# =========================
alias dot='git --git-dir=/mnt/d/.dotfiles-bare --work-tree=/mnt/d'

# =========================
# proxy（WSL版本）
# =========================
proxy_on() {
    export http_proxy="http://127.0.0.1:10808"
    export https_proxy="http://127.0.0.1:10808"
    export all_proxy="socks5://127.0.0.1:10808"
    echo "proxy ON"
}

proxy_off() {
    unset http_proxy https_proxy all_proxy
    echo "proxy OFF"
}

# =========================
# env loader（WSL版 .env）
# =========================
env() {
    local key=$1
    local file="/mnt/d/Dotfiles/Systems/wsl/.env"

    if [ ! -f "$file" ]; then
        echo ".env not found"
        return
    fi

    if [ -z "$key" ]; then
        cat "$file" | cut -d= -f1
        return
    fi

    export "$key=$(grep "^$key=" $file | cut -d= -f2-)"
}

# =========================
# fzf + rg（WSL版）
# =========================
ff() {
    rg --files "${1:-.}" | fzf
}

ffe() {
    rg --files -g "*$1*" "${2:-.}" | fzf
}

fif() {
    rg --column --line-number --no-heading --color=always "$1" "${2:-.}" | fzf
}

# =========================
# symlink（WSL版）
# =========================
lns() {
    ln -s "$1" "$2"
}