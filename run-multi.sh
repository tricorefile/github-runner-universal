#!/bin/bash

# 用于运行多个不同仓库/组织Runner的脚本
# 用法: ./run-multi.sh [start|stop|status|logs]

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Runner配置目录
CONFIGS_DIR="./configs"

# 打印彩色消息的函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_blue() { echo -e "${BLUE}$1${NC}"; }

# 使用特定配置启动Runner的函数
start_runner() {
    local config_file=$1
    local runner_name=$(basename "$config_file" .env)
    
    if [ ! -f "$config_file" ]; then
        log_error "Config file not found: $config_file"
        return 1
    fi
    
    log_info "Starting runner: $runner_name"
    
    # 为此Runner创建项目目录
    local project_dir="runners/$runner_name"
    mkdir -p "$project_dir"
    
    # 将docker-compose.yml复制到项目目录
    cp docker-compose.yml "$project_dir/"
    
    # 复制环境文件
    cp "$config_file" "$project_dir/.env"
    
    # 启动Runner
    (cd "$project_dir" && docker-compose up -d)
    
    if [ $? -eq 0 ]; then
        log_info "Runner $runner_name started successfully"
    else
        log_error "Failed to start runner $runner_name"
    fi
}

# 停止Runner的函数
stop_runner() {
    local runner_name=$1
    local project_dir="runners/$runner_name"
    
    if [ ! -d "$project_dir" ]; then
        log_warn "Runner directory not found: $project_dir"
        return 1
    fi
    
    log_info "Stopping runner: $runner_name"
    (cd "$project_dir" && docker-compose down)
}

# 获取Runner状态的函数
status_runner() {
    local runner_name=$1
    local project_dir="runners/$runner_name"
    
    if [ ! -d "$project_dir" ]; then
        echo -e "${RED}✗${NC} $runner_name: Not deployed"
        return
    fi
    
    local status=$(cd "$project_dir" && docker-compose ps --format json 2>/dev/null | jq -r '.[0].State' 2>/dev/null || echo "unknown")
    
    case "$status" in
        "running")
            echo -e "${GREEN}✓${NC} $runner_name: Running"
            ;;
        "exited"|"stopped")
            echo -e "${RED}✗${NC} $runner_name: Stopped"
            ;;
        *)
            echo -e "${YELLOW}?${NC} $runner_name: Unknown"
            ;;
    esac
}

# 显示Runner日志的函数
logs_runner() {
    local runner_name=$1
    local project_dir="runners/$runner_name"
    
    if [ ! -d "$project_dir" ]; then
        log_error "Runner directory not found: $project_dir"
        return 1
    fi
    
    (cd "$project_dir" && docker-compose logs -f)
}

# 主命令处理器
case "$1" in
    "start")
        if [ -z "$2" ]; then
            # 启动所有Runner
            log_info "Starting all configured runners..."
            for config in "$CONFIGS_DIR"/*.env; do
                if [ -f "$config" ]; then
                    start_runner "$config"
                fi
            done
        else
            # 启动特定Runner
            start_runner "$CONFIGS_DIR/$2.env"
        fi
        ;;
        
    "stop")
        if [ -z "$2" ]; then
            # 停止所有Runner
            log_info "Stopping all runners..."
            for dir in runners/*/; do
                if [ -d "$dir" ]; then
                    runner_name=$(basename "$dir")
                    stop_runner "$runner_name"
                fi
            done
        else
            # 停止特定Runner
            stop_runner "$2"
        fi
        ;;
        
    "status")
        log_blue "GitHub Runners Status:"
        log_blue "======================"
        
        # 检查所有已配置的Runner
        for config in "$CONFIGS_DIR"/*.env; do
            if [ -f "$config" ]; then
                runner_name=$(basename "$config" .env)
                status_runner "$runner_name"
            fi
        done
        ;;
        
    "logs")
        if [ -z "$2" ]; then
            log_error "Please specify a runner name"
            log_info "Usage: $0 logs <runner-name>"
            exit 1
        fi
        logs_runner "$2"
        ;;
        
    "list")
        log_blue "Available Runner Configurations:"
        log_blue "================================"
        for config in "$CONFIGS_DIR"/*.env; do
            if [ -f "$config" ]; then
                runner_name=$(basename "$config" .env)
                # 尝试从配置中提取一些信息
                source "$config" 2>/dev/null
                echo "  • $runner_name"
                echo "    - Scope: ${RUNNER_SCOPE:-repo}"
                echo "    - Owner: ${GITHUB_OWNER:-not set}"
                if [ "$RUNNER_SCOPE" = "repo" ]; then
                    echo "    - Repository: ${GITHUB_REPOSITORY:-not set}"
                fi
                echo ""
            fi
        done
        ;;
        
    "clean")
        log_warn "This will remove all stopped runners and their data"
        read -p "Are you sure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for dir in runners/*/; do
                if [ -d "$dir" ]; then
                    runner_name=$(basename "$dir")
                    log_info "Cleaning $runner_name..."
                    (cd "$dir" && docker-compose down -v)
                    rm -rf "$dir"
                fi
            done
            log_info "Cleanup complete"
        fi
        ;;
        
    *)
        log_blue "GitHub Actions Universal Runner Manager"
        log_blue "======================================="
        echo ""
        echo "Usage: $0 [command] [runner-name]"
        echo ""
        echo "Commands:"
        echo "  start [name]  - Start runner(s). If no name specified, starts all"
        echo "  stop [name]   - Stop runner(s). If no name specified, stops all"
        echo "  status        - Show status of all configured runners"
        echo "  logs <name>   - Show logs for specific runner"
        echo "  list          - List all available runner configurations"
        echo "  clean         - Remove all stopped runners and their data"
        echo ""
        echo "Examples:"
        echo "  $0 start                # Start all runners"
        echo "  $0 start repo-runner    # Start specific runner"
        echo "  $0 status               # Check all runners status"
        echo "  $0 logs repo-runner     # View logs for specific runner"
        echo ""
        echo "Configuration files are in: $CONFIGS_DIR/"
        ;;
esac