#!/bin/bash
set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 打印彩色消息的函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 验证必需的环境变量
: ${GITHUB_TOKEN:?Need GITHUB_TOKEN environment variable}
: ${GITHUB_OWNER:?Need GITHUB_OWNER environment variable}
: ${RUNNER_SCOPE:=repo}

# 设置默认值
RUNNER_NAME=${RUNNER_NAME:-$(hostname)}
RUNNER_LABELS=${RUNNER_LABELS:-self-hosted,linux,x64}
RUNNER_WORKDIR=${RUNNER_WORKDIR:-_work}
RUNNER_GROUP=${RUNNER_GROUP:-default}
EPHEMERAL=${EPHEMERAL:-false}
DISABLE_AUTO_UPDATE=${DISABLE_AUTO_UPDATE:-true}

cd /home/runner/actions-runner

# 根据范围确定注册URL和API端点
case "$RUNNER_SCOPE" in
    "repo")
        if [ -z "$GITHUB_REPOSITORY" ]; then
            log_error "GITHUB_REPOSITORY is required for repo-scoped runners"
            exit 1
        fi
        REGISTRATION_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPOSITORY}"
        API_URL="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPOSITORY}/actions/runners/registration-token"
        log_info "Configuring repository-scoped runner for ${GITHUB_OWNER}/${GITHUB_REPOSITORY}"
        ;;
    "org")
        REGISTRATION_URL="https://github.com/${GITHUB_OWNER}"
        API_URL="https://api.github.com/orgs/${GITHUB_OWNER}/actions/runners/registration-token"
        log_info "Configuring organization-scoped runner for ${GITHUB_OWNER}"
        ;;
    "enterprise")
        REGISTRATION_URL="https://github.com/enterprises/${GITHUB_OWNER}"
        API_URL="https://api.github.com/enterprises/${GITHUB_OWNER}/actions/runners/registration-token"
        log_info "Configuring enterprise-scoped runner for ${GITHUB_OWNER}"
        ;;
    *)
        log_error "Invalid RUNNER_SCOPE: $RUNNER_SCOPE (must be repo, org, or enterprise)"
        exit 1
        ;;
esac

# 获取注册令牌的函数
get_registration_token() {
    local response=$(curl -sX POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        ${API_URL} 2>&1)
    
    local token=$(echo "$response" | jq -r .token 2>/dev/null)
    
    if [ -z "$token" ] || [ "$token" = "null" ]; then
        log_error "Failed to get registration token"
        log_error "Response: $response"
        log_error "Please check:"
        log_error "1. GITHUB_TOKEN has correct permissions (repo/admin:org)"
        log_error "2. The ${RUNNER_SCOPE} '${GITHUB_OWNER}' exists"
        if [ "$RUNNER_SCOPE" = "repo" ]; then
            log_error "3. Repository '${GITHUB_REPOSITORY}' exists"
        fi
        return 1
    fi
    
    echo "$token"
}

# 如果尚未配置，则配置Runner
if [ ! -f ".runner" ]; then
    log_info "Runner not configured, starting configuration..."
    log_info "Runner Name: ${RUNNER_NAME}"
    log_info "Labels: ${RUNNER_LABELS}"
    log_info "Work Directory: ${RUNNER_WORKDIR}"
    log_info "Runner Group: ${RUNNER_GROUP}"
    log_info "Ephemeral: ${EPHEMERAL}"
    
    # 获取注册令牌
    REG_TOKEN=$(get_registration_token)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    log_info "Successfully obtained registration token"
    
    # 构建配置命令
    CONFIG_CMD="./config.sh \
        --url ${REGISTRATION_URL} \
        --token ${REG_TOKEN} \
        --name ${RUNNER_NAME} \
        --labels ${RUNNER_LABELS} \
        --work ${RUNNER_WORKDIR} \
        --runnergroup ${RUNNER_GROUP} \
        --unattended \
        --replace"
    
    # 如果需要，添加临时标志
    if [ "$EPHEMERAL" = "true" ]; then
        CONFIG_CMD="$CONFIG_CMD --ephemeral"
        log_info "Runner will run in ephemeral mode"
    fi
    
    # 如果需要，添加禁用自动更新标志
    if [ "$DISABLE_AUTO_UPDATE" = "true" ]; then
        CONFIG_CMD="$CONFIG_CMD --disableupdate"
        log_info "Auto-update disabled"
    fi
    
    # 执行配置
    log_info "Configuring runner..."
    eval $CONFIG_CMD
    
    if [ $? -eq 0 ]; then
        log_info "Runner configured successfully"
    else
        log_error "Runner configuration failed"
        exit 1
    fi
else
    log_info "Runner already configured, skipping configuration"
fi

# 清理函数
cleanup() {
    log_info "Cleanup initiated..."
    
    if [ -f ".runner" ] && [ "$EPHEMERAL" != "true" ]; then
        log_info "Removing runner registration..."
        
        # 获取移除令牌
        REMOVE_TOKEN=$(curl -sX POST \
            -H "Authorization: token ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github.v3+json" \
            ${API_URL} 2>/dev/null | jq -r .token)
        
        if [ ! -z "$REMOVE_TOKEN" ] && [ "$REMOVE_TOKEN" != "null" ]; then
            ./config.sh remove --token ${REMOVE_TOKEN} || true
            log_info "Runner unregistered"
        else
            log_warn "Could not get removal token, runner may remain registered"
        fi
    fi
    
    log_info "Cleanup completed"
}

# 设置退出时清理的陷阱（临时Runner除外）
if [ "$EPHEMERAL" != "true" ]; then
    trap cleanup EXIT INT TERM
fi

# 启动Runner
log_info "Starting GitHub Actions Runner..."
log_info "Press Ctrl+C to stop"

# 运行Runner
if [ "$EPHEMERAL" = "true" ]; then
    log_info "Running in ephemeral mode (will exit after one job)"
    exec ./run.sh --once
else
    exec ./run.sh
fi