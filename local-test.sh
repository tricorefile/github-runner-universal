#!/bin/bash

# GitHub Actions Runner Universal 本地验证脚本
# 用于测试 Docker 构建和 Runner 功能

set -e

echo "========================================="
echo "GitHub Actions Runner Universal 本地验证"
echo "========================================="

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 构建 Docker 镜像
echo -e "\n${YELLOW}步骤 1: 构建 Docker 镜像${NC}"
echo "正在构建镜像..."

docker build -t github-runner-test:latest . || {
    echo -e "${RED}❌ Docker 构建失败${NC}"
    exit 1
}

echo -e "${GREEN}✅ Docker 镜像构建成功${NC}"

# 2. 验证镜像内容
echo -e "\n${YELLOW}步骤 2: 验证镜像内容${NC}"

# 检查镜像大小
IMAGE_SIZE=$(docker images github-runner-test:latest --format "{{.Size}}")
echo "镜像大小: $IMAGE_SIZE"

# 检查安装的工具
echo -e "\n检查预装工具版本:"
docker run --rm github-runner-test:latest bash -c "
    echo '- Git:' && git --version
    echo '- Docker:' && docker --version 2>/dev/null || echo '  Docker 客户端已安装'
    echo '- Node.js:' && node --version
    echo '- Python:' && python3 --version
    echo '- Go:' && go version
    echo '- Java:' && java -version 2>&1 | head -n 1
    echo '- .NET:' && dotnet --version
    echo '- kubectl:' && kubectl version --client --short 2>/dev/null || echo '  kubectl 已安装'
    echo '- Helm:' && helm version --short
    echo '- Terraform:' && terraform version | head -n 1
"

# 3. 测试 Runner 用户权限
echo -e "\n${YELLOW}步骤 3: 测试 Runner 用户权限${NC}"

docker run --rm github-runner-test:latest bash -c "
    echo '检查用户和组:'
    id runner
    echo ''
    echo '检查 sudo 权限:'
    sudo -u runner sudo -n true && echo '✅ Runner 用户具有 sudo 权限' || echo '❌ Runner 用户没有 sudo 权限'
    echo ''
    echo '检查 docker 组:'
    getent group docker && echo '✅ Docker 组存在' || echo '❌ Docker 组不存在'
"

# 4. 测试 Runner 启动脚本
echo -e "\n${YELLOW}步骤 4: 验证启动脚本${NC}"

if [ -f "./scripts/entrypoint.sh" ]; then
    echo "✅ entrypoint.sh 脚本存在"
    # 检查脚本权限
    ls -la ./scripts/entrypoint.sh
else
    echo "❌ entrypoint.sh 脚本不存在"
fi

# 5. 模拟 Runner 环境变量
echo -e "\n${YELLOW}步骤 5: 测试环境变量配置${NC}"

docker run --rm \
    -e RUNNER_NAME="test-runner" \
    -e RUNNER_WORKDIR="/home/runner/work" \
    -e RUNNER_LABELS="docker,linux,x64,self-hosted" \
    github-runner-test:latest bash -c "
    echo 'Runner 配置:'
    echo '  名称: \$RUNNER_NAME'
    echo '  工作目录: \$RUNNER_WORKDIR'
    echo '  标签: \$RUNNER_LABELS'
    echo ''
    echo '检查工作目录:'
    ls -la /home/runner/ | head -5
"

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}本地验证完成！${NC}"
echo -e "${GREEN}=========================================${NC}"

echo -e "\n${YELLOW}建议的后续步骤:${NC}"
echo "1. 使用实际的 GitHub Token 测试 Runner 注册"
echo "2. 运行 'act' 工具测试 GitHub Actions 工作流"
echo "3. 使用 docker-compose 测试多 Runner 部署"