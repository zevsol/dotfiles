# ===== history 配置 =====
HISTSIZE=10000
SAVEHIST=10000

# 去重：忽略重复命令和空格开头的命令
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_space

# 共享历史：多终端实时同步
setopt share_history

# 追加写入而非覆盖
setopt append_history

# 展开历史而非直接执行
setopt hist_verify
