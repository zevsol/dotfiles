# ===== 代理函数 =====

proxy_on() {
    export http_proxy="http://127.0.0.1:7897"
    export https_proxy="http://127.0.0.1:7897"
    export all_proxy="socks5://127.0.0.1:7897"
    echo "proxy ON"
}

proxy_off() {
    unset http_proxy https_proxy all_proxy
    echo "proxy OFF"
}

codex_proxy_on() {
    local proxy="http://127.0.0.1:7897"

    export http_proxy="$proxy"
    export https_proxy="$proxy"
    export HTTP_PROXY="$proxy"
    export HTTPS_PROXY="$proxy"

    # Codex 暂时不要走 SOCKS
    unset all_proxy
    unset ALL_PROXY

    export no_proxy="localhost,127.0.0.1,::1"
    export NO_PROXY="$no_proxy"

    echo "proxy ON -> $proxy"
}

# proxy_on() {
#   local HTTP_PORT="${1:-10809}"
#   local SOCKS_PORT="${2:-7897}"

#   export http_proxy="http://127.0.0.1:${HTTP_PORT}"
#   export https_proxy="http://127.0.0.1:${HTTP_PORT}"
#   export HTTP_PROXY="$http_proxy"
#   export HTTPS_PROXY="$https_proxy"

#   export all_proxy="socks5h://127.0.0.1:${SOCKS_PORT}"
#   export ALL_PROXY="$all_proxy"

#   export no_proxy="localhost,127.0.0.1,::1"
#   export NO_PROXY="$no_proxy"

#   echo "proxy ON  http=${HTTP_PORT}  socks=${SOCKS_PORT}"
# }

# proxy_off() {
#   unset http_proxy https_proxy all_proxy no_proxy
#   unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
#   echo "proxy OFF"
# }
# 快捷别名
alias ep='proxy_on'
alias un='proxy_off'
