# ===== 代理函数 =====

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

# 快捷别名
alias ep='proxy_on'
alias un='proxy_off'
