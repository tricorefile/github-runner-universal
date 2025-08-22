#!/bin/bash

# 使用 act 工具本地测试 GitHub Actions 工作流
# 需要先安装 act: brew install act (macOS) 或 https://github.com/nektos/act

set -e

echo "========================================="
echo "GitHub Actions 本地测试 (使用 act)"
echo "========================================="

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查 act 是否安装
if ! command -v act &> /dev/null; then
    echo -e "${YELLOW}act 工具未安装，正在安装...${NC}"
    
    # 检测操作系统并安装
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install act
        else
            echo -e "${RED}请先安装 Homebrew 或手动安装 act${NC}"
            echo "访问: https://github.com/nektos/act"
            exit 1
        fi
    else
        # Linux
        curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
    fi
fi

echo -e "${GREEN}✅ act 工具已就绪${NC}"
act --version

# 创建 act 配置文件
echo -e "\n${YELLOW}创建 act 配置...${NC}"
cat > .actrc << 'EOF'
# act 配置文件
# 使用 Medium 尺寸的容器以获得更多工具
-P ubuntu-latest=catthehacker/ubuntu:act-latest
-P ubuntu-24.04=catthehacker/ubuntu:act-24.04
-P ubuntu-22.04=catthehacker/ubuntu:act-22.04
--container-architecture linux/amd64
EOF

echo -e "${GREEN}✅ act 配置创建完成${NC}"

# 创建测试用的 secrets 文件
echo -e "\n${YELLOW}创建测试 secrets...${NC}"
cat > .secrets << 'EOF'
# GitHub Actions Secrets (用于本地测试)
# 注意: 这些是模拟值，实际使用时需要替换
GITHUB_TOKEN=ghp_test_token_123456789
EOF

echo -e "${GREEN}✅ Secrets 文件创建完成${NC}"

# 测试选项菜单
echo -e "\n${BLUE}=========================================${NC}"
echo -e "${BLUE}选择要测试的内容:${NC}"
echo -e "${BLUE}=========================================${NC}"
echo "1) 列出所有可用的工作流"
echo "2) 测试 Docker 构建工作流 (干运行)"
echo "3) 测试 Docker 构建工作流 (完整运行)"
echo "4) 测试特定事件 (push)"
echo "5) 测试特定事件 (pull_request)"
echo "6) 运行工作流并查看详细日志"
echo "7) 测试 attestation 步骤"
echo "0) 退出"

read -p "请选择 (0-7): " choice

case $choice in
    1)
        echo -e "\n${YELLOW}列出所有工作流:${NC}"
        act -l
        ;;
    2)
        echo -e "\n${YELLOW}测试 Docker 构建工作流 (干运行):${NC}"
        act -n -W .github/workflows/docker-build-push.yml
        ;;
    3)
        echo -e "\n${YELLOW}测试 Docker 构建工作流 (完整运行):${NC}"
        echo -e "${RED}注意: 这将实际运行构建，可能需要较长时间${NC}"
        act -W .github/workflows/docker-build-push.yml --secret-file .secrets
        ;;
    4)
        echo -e "\n${YELLOW}测试 push 事件:${NC}"
        act push --secret-file .secrets
        ;;
    5)
        echo -e "\n${YELLOW}测试 pull_request 事件:${NC}"
        act pull_request --secret-file .secrets
        ;;
    6)
        echo -e "\n${YELLOW}运行工作流 (详细日志):${NC}"
        act -v -W .github/workflows/docker-build-push.yml --secret-file .secrets
        ;;
    7)
        echo -e "\n${YELLOW}测试 attestation 步骤:${NC}"
        # 创建测试工作流专门测试 attestation
        cat > .github/workflows/test-attestation.yml << 'EOFA'
name: Test Attestation
on: workflow_dispatch

jobs:
  test-attestation:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write
      attestations: write
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Create test artifact
        run: |
          echo "Test artifact" > test-artifact.txt
          tar -czf test-artifact.tar.gz test-artifact.txt
      
      - name: Generate attestation
        uses: actions/attest-build-provenance@v1
        with:
          subject-path: test-artifact.tar.gz
EOFA
        echo -e "${GREEN}✅ 测试工作流已创建${NC}"
        echo "运行测试..."
        act workflow_dispatch -W .github/workflows/test-attestation.yml --secret-file .secrets
        ;;
    0)
        echo -e "${GREEN}退出测试${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}无效选择${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}测试完成！${NC}"
echo -e "${GREEN}=========================================${NC}"

# 清理提示
echo -e "\n${YELLOW}提示:${NC}"
echo "- .secrets 文件包含敏感信息，请勿提交到 Git"
echo "- 使用 'act -h' 查看更多选项"
echo "- 访问 https://github.com/nektos/act 了解更多"