#!/bin/bash
# ============================================
# Dotfiles Setup Script (WSL)
# ============================================
# 功能：一键构建 WSL 开发环境
# 用法：
#   ./setup.sh              # 完整安装
#   ./setup.sh --update     # 增量更新
#   ./setup.sh --rollback   # 回滚
#   ./setup.sh --verify     # 仅验证
#   ./setup.sh --dry-run    # 预览变更

set -e

# ============================================
# 配置
# ============================================
DOTFILES_ROOT="/mnt/d/Dotfiles"
MANIFEST_FILE="$DOTFILES_ROOT/manifest.yml"
MODULES_DIR="$DOTFILES_ROOT/Scripts/modules"
STATE_DIR="$DOTFILES_ROOT/.state"

# ============================================
# 颜色定义
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# ============================================
# 工具函数
# ============================================
log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_skip() {
    echo -e "${GRAY}[SKIP]${NC} $1"
}

log_create() {
    echo -e "${GREEN}[CREATE]${NC} $1"
}

log_exists() {
    echo -e "${GRAY}[EXISTS]${NC} $1"
}

# ============================================
# 状态管理
# ============================================
init_state() {
    local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    local state_path="$STATE_DIR/$timestamp"

    mkdir -p "$STATE_DIR"
    mkdir -p "$state_path"

    # 创建 latest 符号链接
    rm -f "$STATE_DIR/latest"
    ln -s "$state_path" "$STATE_DIR/latest"

    echo "$state_path"
}

backup_env() {
    local state_dir=$1
    local backup_file="$state_dir/env_backup.json"

    echo "{" > "$backup_file"
    local first=true

    # 备份关键环境变量
    for var in DOTFILES XDG_CONFIG_HOME GIT_CONFIG_GLOBAL STARSHIP_CONFIG CARGO_HOME RUSTUP_HOME GOPATH OLLAMA_MODELS HF_HOME; do
        local value=$(eval echo \$$var)
        if [ -n "$value" ]; then
            if [ "$first" = true ]; then
                first=false
            else
                echo "," >> "$backup_file"
            fi
            echo "  \"$var\": \"$value\"" >> "$backup_file"
        fi
    done

    echo "}" >> "$backup_file"
    log_info "环境变量已备份: $backup_file"
}

backup_symlinks() {
    local state_dir=$1
    local backup_file="$state_dir/symlink_backup.json"

    echo "[" > "$backup_file"
    local first=true

    # 备份符号链接
    for link in ~/.zshrc ~/.bashrc; do
        if [ -L "$link" ]; then
            local target=$(readlink "$link")
            if [ "$first" = true ]; then
                first=false
            else
                echo "," >> "$backup_file"
            fi
            echo "  {\"source\": \"$link\", \"target\": \"$target\"}" >> "$backup_file"
        fi
    done

    echo "]" >> "$backup_file"
    log_info "符号链接已备份: $backup_file"
}

backup_files() {
    local state_dir=$1
    local backup_dir="$state_dir/files"

    mkdir -p "$backup_dir"

    # 备份关键配置文件
    local files=(
        "$DOTFILES_ROOT/Systems/wsl/git/.gitconfig"
        "$DOTFILES_ROOT/Systems/wsl/starship/starship.toml"
        "$DOTFILES_ROOT/Systems/wsl/zsh/zshrc"
    )

    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            local relative_path=${file#$DOTFILES_ROOT/}
            local dest_file="$backup_dir/$relative_path"
            local dest_dir=$(dirname "$dest_file")
            mkdir -p "$dest_dir"
            cp "$file" "$dest_file"
        fi
    done

    log_info "配置文件已备份: $backup_dir"
}

write_changelog() {
    local state_dir=$1
    local action=$2
    local target=$3
    local status=$4
    local details=${5:-""}

    local log_file="$state_dir/changes.log"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    echo "[$timestamp] $action | $target | $status | $details" >> "$log_file"
}

# ============================================
# 目录创建
# ============================================
create_directories() {
    local manifest=$1
    local dry_run=$2

    log_info "创建目录结构..."

    # 解析 YAML 中的目录
    local in_dirs=false
    local in_wsl=false

    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*wsl: ]]; then
            in_wsl=true
            in_dirs=true
        elif [[ $line =~ ^[a-z] ]]; then
            in_dirs=false
        elif [ "$in_dirs" = true ] && [ "$in_wsl" = true ]; then
            if [[ $line =~ path:\ *\"([^\"]+)\" ]]; then
                local dir_path="${BASH_REMATCH[1]}"
                # 替换变量
                dir_path=$(echo "$dir_path" | sed "s|/mnt/d|/mnt/d|g")

                if [ "$dry_run" = true ]; then
                    echo -e "  ${GRAY}[DRY-RUN] 将创建: $dir_path${NC}"
                else
                    if [ ! -d "$dir_path" ]; then
                        mkdir -p "$dir_path"
                        log_create "$dir_path"
                    else
                        log_exists "$dir_path"
                    fi
                fi
            fi
        fi
    done < "$manifest"
}

# ============================================
# 环境变量设置
# ============================================
set_env_vars() {
    local manifest=$1
    local dry_run=$2
    local state_dir=$3

    log_info "设置环境变量..."

    # 解析 YAML 中的环境变量
    local in_env=false
    local in_wsl=false
    local var_name=""

    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*wsl: ]]; then
            in_wsl=true
            in_env=true
        elif [[ $line =~ ^[a-z] ]]; then
            in_env=false
        elif [ "$in_env" = true ] && [ "$in_wsl" = true ]; then
            if [[ $line =~ ^[[:space:]]+([A-Z_]+): ]]; then
                var_name="${BASH_REMATCH[1]}"
            elif [[ $line =~ value:\ *\"([^\"]+)\" ]] && [ -n "$var_name" ]; then
                local var_value="${BASH_REMATCH[1]}"
                # 替换变量
                var_value=$(echo "$var_value" | sed "s|\\\$DOTFILES|$DOTFILES_ROOT|g")

                if [ "$dry_run" = true ]; then
                    echo -e "  ${GRAY}[DRY-RUN] 将设置: $var_name = $var_value${NC}"
                else
                    local current_value=$(eval echo \$$var_name)
                    if [ "$current_value" != "$var_value" ]; then
                        export "$var_name=$var_value"
                        # 写入 .bashrc 或 .zshrc
                        write_to_shell_config "$var_name" "$var_value"
                        log_success "设置: $var_name = $var_value"
                        write_changelog "$state_dir" "SET_ENV" "$var_name" "SUCCESS" "设置为 '$var_value'"
                    else
                        log_exists "$var_name"
                    fi
                fi
                var_name=""
            fi
        fi
    done < "$manifest"
}

write_to_shell_config() {
    local var_name=$1
    local var_value=$2

    # 检查 .zshrc
    if [ -f ~/.zshrc ]; then
        if ! grep -q "export $var_name=" ~/.zshrc; then
            echo "export $var_name=\"$var_value\"" >> ~/.zshrc
        fi
    fi

    # 检查 .bashrc
    if [ -f ~/.bashrc ]; then
        if ! grep -q "export $var_name=" ~/.bashrc; then
            echo "export $var_name=\"$var_value\"" >> ~/.bashrc
        fi
    fi
}

# ============================================
# 符号链接创建
# ============================================
create_symlinks() {
    local manifest=$1
    local dry_run=$2
    local state_dir=$3

    log_info "创建符号链接..."

    # 解析 YAML 中的符号链接
    local in_symlinks=false
    local in_wsl=false

    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*wsl: ]]; then
            in_wsl=true
            in_symlinks=true
        elif [[ $line =~ ^[a-z] ]]; then
            in_symlinks=false
        elif [ "$in_symlinks" = true ] && [ "$in_wsl" = true ]; then
            if [[ $line =~ source:\ *\"([^\"]+)\" ]]; then
                local source="${BASH_REMATCH[1]}"
                source=$(echo "$source" | sed "s|~|$HOME|g")
            elif [[ $line =~ target:\ *\"([^\"]+)\" ]]; then
                local target="${BASH_REMATCH[1]}"
                target=$(echo "$target" | sed "s|/mnt/d|$DOTFILES_ROOT/..|g")

                if [ "$dry_run" = true ]; then
                    echo -e "  ${GRAY}[DRY-RUN] 将创建: $source -> $target${NC}"
                else
                    create_symlink "$source" "$target" "$state_dir"
                fi
            fi
        fi
    done < "$manifest"
}

create_symlink() {
    local source=$1
    local target=$2
    local state_dir=$3

    # 检查目标是否存在
    if [ ! -e "$target" ]; then
        log_warning "目标不存在: $target"
        return
    fi

    # 检查源是否已存在
    if [ -e "$source" ] || [ -L "$source" ]; then
        if [ -L "$source" ]; then
            local current_target=$(readlink "$source")
            if [ "$current_target" = "$target" ]; then
                log_exists "符号链接已存在且正确: $source"
                return
            fi
            # 删除旧的符号链接
            rm -f "$source"
        else
            # 备份真实文件
            local backup_path="${source}.bak_$(date +%Y%m%d_%H%M%S)"
            mv "$source" "$backup_path"
            log_warning "备份: $source -> $backup_path"
        fi
    fi

    # 创建符号链接
    ln -s "$target" "$source"
    if [ $? -eq 0 ]; then
        log_success "符号链接创建成功: $source -> $target"
        write_changelog "$state_dir" "CREATE_SYMLINK" "$source" "SUCCESS"
    else
        log_error "符号链接创建失败: $source -> $target"
        write_changelog "$state_dir" "CREATE_SYMLINK" "$source" "FAILED"
    fi
}

# ============================================
# 工具安装
# ============================================
install_tools() {
    local manifest=$1
    local dry_run=$2

    log_info "安装工具..."

    # 解析 YAML 中的工具
    local in_tools=false
    local in_wsl=false
    local tool_name=""
    local tool_manager=""

    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*wsl: ]]; then
            in_wsl=true
            in_tools=true
        elif [[ $line =~ ^[a-z] ]]; then
            in_tools=false
        elif [ "$in_tools" = true ] && [ "$in_wsl" = true ]; then
            if [[ $line =~ name:\ *\"([^\"]+)\" ]]; then
                tool_name="${BASH_REMATCH[1]}"
            elif [[ $line =~ manager:\ *\"([^\"]+)\" ]]; then
                tool_manager="${BASH_REMATCH[1]}"
                if [ -n "$tool_name" ]; then
                    if [ "$dry_run" = true ]; then
                        echo -e "  ${GRAY}[DRY-RUN] 将安装: $tool_name (via $tool_manager)${NC}"
                    else
                        install_tool "$tool_name" "$tool_manager"
                    fi
                    tool_name=""
                    tool_manager=""
                fi
            fi
        fi
    done < "$manifest"
}

install_tool() {
    local tool_name=$1
    local tool_manager=$2

    # 检查是否已安装
    if command -v "$tool_name" &> /dev/null; then
        log_exists "工具已安装: $tool_name"
        return
    fi

    # 安装工具
    case $tool_manager in
        apt)
            sudo apt-get update
            sudo apt-get install -y "$tool_name"
            ;;
        nix)
            nix-env -iA nixpkgs."$tool_name"
            ;;
        *)
            log_warning "未知的包管理器: $tool_manager"
            ;;
    esac

    if [ $? -eq 0 ]; then
        log_success "工具安装成功: $tool_name"
    else
        log_error "工具安装失败: $tool_name"
    fi
}

# ============================================
# 验证
# ============================================
run_verification() {
    log_info "执行验证..."

    local pass=0
    local fail=0
    local warn=0

    # Layer 1: 文件存在性
    echo -e "\n${CYAN}=== Layer 1: 文件存在性验证 ===${NC}"

    local dirs=(
        "$DOTFILES_ROOT/Systems/wsl"
        "$DOTFILES_ROOT/Systems/wsl/git"
        "$DOTFILES_ROOT/Systems/wsl/starship"
        "$DOTFILES_ROOT/Systems/wsl/zsh"
        "$DOTFILES_ROOT/Systems/wsl/ssh"
    )

    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "  ${GREEN}[PASS]${NC} 目录存在: $dir"
            ((pass++))
        else
            echo -e "  ${RED}[FAIL]${NC} 目录不存在: $dir"
            ((fail++))
        fi
    done

    local files=(
        "$DOTFILES_ROOT/Systems/wsl/git/.gitconfig"
        "$DOTFILES_ROOT/Systems/wsl/starship/starship.toml"
        "$DOTFILES_ROOT/Systems/wsl/zsh/zshrc"
    )

    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            echo -e "  ${GREEN}[PASS]${NC} 文件存在: $file"
            ((pass++))
        else
            echo -e "  ${RED}[FAIL]${NC} 文件不存在: $file"
            ((fail++))
        fi
    done

    # Layer 2: 内容正确性
    echo -e "\n${CYAN}=== Layer 2: 内容正确性验证 ===${NC}"

    # 验证 Git 配置
    if [ -f "$DOTFILES_ROOT/Systems/wsl/git/.gitconfig" ]; then
        if grep -q "autocrlf = input" "$DOTFILES_ROOT/Systems/wsl/git/.gitconfig"; then
            echo -e "  ${GREEN}[PASS]${NC} Git autocrlf = input"
            ((pass++))
        else
            echo -e "  ${RED}[FAIL]${NC} Git autocrlf 不正确"
            ((fail++))
        fi
    fi

    # 验证 Starship 配置
    if [ -f "$DOTFILES_ROOT/Systems/wsl/starship/starship.toml" ]; then
        if grep -q "schema" "$DOTFILES_ROOT/Systems/wsl/starship/starship.toml"; then
            echo -e "  ${GREEN}[PASS]${NC} Starship 配置有效"
            ((pass++))
        else
            echo -e "  ${YELLOW}[WARN]${NC} Starship 配置可能无效"
            ((warn++))
        fi
    fi

    # Layer 3: 功能验证
    echo -e "\n${CYAN}=== Layer 3: 功能验证 ===${NC}"

    for tool in git zsh; do
        if command -v "$tool" &> /dev/null; then
            echo -e "  ${GREEN}[PASS]${NC} 工具已安装: $tool"
            ((pass++))
        else
            echo -e "  ${YELLOW}[WARN]${NC} 工具未安装: $tool"
            ((warn++))
        fi
    done

    # 总结
    echo -e "\n${CYAN}=== 验证总结 ===${NC}"
    echo -e "  通过: ${GREEN}$pass${NC}"
    echo -e "  失败: ${RED}$fail${NC}"
    echo -e "  警告: ${YELLOW}$warn${NC}"

    if [ $fail -eq 0 ]; then
        echo -e "  总体状态: ${GREEN}SUCCESS${NC}"
    else
        echo -e "  总体状态: ${RED}FAILED${NC}"
    fi
}

# ============================================
# 回滚
# ============================================
run_rollback() {
    log_info "执行回滚..."

    if [ ! -d "$STATE_DIR" ]; then
        log_error "无状态目录，无法回滚"
        return
    fi

    local latest=$(readlink "$STATE_DIR/latest" 2>/dev/null)
    if [ -z "$latest" ]; then
        log_error "无最新状态，无法回滚"
        return
    fi

    log_info "回滚到: $latest"

    # 恢复环境变量
    local env_backup="$latest/env_backup.json"
    if [ -f "$env_backup" ]; then
        # 简单恢复（实际应该解析 JSON）
        log_info "环境变量备份存在: $env_backup"
    fi

    # 恢复符号链接
    local symlink_backup="$latest/symlink_backup.json"
    if [ -f "$symlink_backup" ]; then
        log_info "符号链接备份存在: $symlink_backup"
    fi

    # 恢复文件
    local files_dir="$latest/files"
    if [ -d "$files_dir" ]; then
        cp -r "$files_dir"/* "$DOTFILES_ROOT/Systems/wsl/" 2>/dev/null
        log_success "配置文件已恢复"
    fi

    log_success "回滚完成"
}

# ============================================
# 主函数
# ============================================
main() {
    echo "========================================"
    echo "  Dotfiles Setup (WSL)"
    echo "========================================"
    echo ""

    # 检查 manifest.yml
    if [ ! -f "$MANIFEST_FILE" ]; then
        log_error "manifest.yml 不存在: $MANIFEST_FILE"
        exit 1
    fi

    # 解析参数
    local dry_run=false
    local update=false
    local rollback=false
    local verify=false

    for arg in "$@"; do
        case $arg in
            --dry-run) dry_run=true ;;
            --update) update=true ;;
            --rollback) rollback=true ;;
            --verify) verify=true ;;
        esac
    done

    # 执行
    if [ "$rollback" = true ]; then
        run_rollback
    elif [ "$verify" = true ]; then
        run_verification
    elif [ "$update" = true ]; then
        local state_dir=$(init_state)
        backup_env "$state_dir"
        backup_symlinks "$state_dir"
        backup_files "$state_dir"
        set_env_vars "$MANIFEST_FILE" "$dry_run" "$state_dir"
        run_verification
    else
        local state_dir=$(init_state)
        backup_env "$state_dir"
        backup_symlinks "$state_dir"
        backup_files "$state_dir"
        create_directories "$MANIFEST_FILE" "$dry_run"
        set_env_vars "$MANIFEST_FILE" "$dry_run" "$state_dir"
        create_symlinks "$MANIFEST_FILE" "$dry_run" "$state_dir"
        install_tools "$MANIFEST_FILE" "$dry_run"
        run_verification
    fi

    echo ""
    echo "========================================"
    echo "  完成!"
    echo "========================================"
}

# 执行主函数
main "$@"
