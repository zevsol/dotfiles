# ===== env loader =====
# 加载 .env 文件中的环境变量
env() {
    local key=$1
    local file="$DOTFILES/Systems/wsl/.env"

    if [ ! -f "$file" ]; then
        echo ".env not found"
        return
    fi

    # 不带参数 → 列出所有变量名
    if [ -z "$key" ]; then
        cut -d= -f1 "$file"
        return
    fi

    # 指定变量名 → 导出
    export "$key=$(grep "^$key=" "$file" | cut -d= -f2-)"
}

# ===== fzf + rg 工具 =====

# 模糊查找文件
ff() {
    rg --files "${1:-.}" | fzf
}

# 精确查找文件名
ffe() {
    rg --files -g "*$1*" "${2:-.}" | fzf
}

# 搜索文件内容
fif() {
    rg --column --line-number --no-heading --color=always "$1" "${2:-.}" | fzf
}
