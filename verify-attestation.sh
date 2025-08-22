#!/bin/bash

# 验证 GitHub Actions Attestation 权限修复
# 此脚本用于验证 attestation 权限是否正确配置

set -e

echo "========================================="
echo "验证 Attestation 权限配置"
echo "========================================="

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. 检查工作流文件权限配置
echo -e "\n${YELLOW}1. 检查 GitHub Actions 工作流权限配置${NC}"

WORKFLOW_FILE=".github/workflows/docker-build-push.yml"

if [ -f "$WORKFLOW_FILE" ]; then
    echo "检查文件: $WORKFLOW_FILE"
    
    # 检查是否包含 attestations: write
    if grep -q "attestations: write" "$WORKFLOW_FILE"; then
        echo -e "${GREEN}✅ 找到 'attestations: write' 权限配置${NC}"
        
        # 显示权限配置上下文
        echo -e "\n权限配置:"
        grep -A 3 -B 1 "permissions:" "$WORKFLOW_FILE" | grep -E "permissions:|contents:|packages:|id-token:|attestations:" || true
    else
        echo -e "${RED}❌ 未找到 'attestations: write' 权限配置${NC}"
        echo "需要在 permissions 部分添加: attestations: write"
    fi
else
    echo -e "${RED}❌ 工作流文件不存在: $WORKFLOW_FILE${NC}"
fi

# 2. 检查 attest-build-provenance action 的使用
echo -e "\n${YELLOW}2. 检查 attestation action 配置${NC}"

if grep -q "actions/attest-build-provenance" "$WORKFLOW_FILE"; then
    echo -e "${GREEN}✅ 找到 attestation action${NC}"
    
    # 显示 attestation 配置
    echo -e "\nAttestation 步骤配置:"
    grep -A 5 "attest-build-provenance" "$WORKFLOW_FILE" || true
else
    echo -e "${YELLOW}⚠️  未使用 attestation action${NC}"
    echo "这是可选的，但建议添加以提供构建证明"
fi

# 3. 创建测试工作流验证权限
echo -e "\n${YELLOW}3. 创建测试工作流${NC}"

TEST_WORKFLOW=".github/workflows/test-attestation-local.yml"
mkdir -p .github/workflows

cat > "$TEST_WORKFLOW" << 'EOF'
name: Test Attestation Permissions
on:
  workflow_dispatch:
    inputs:
      test_mode:
        description: 'Test mode'
        required: false
        default: 'basic'
        type: choice
        options:
          - basic
          - full

jobs:
  test-permissions:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write
      attestations: write
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Check permissions
        run: |
          echo "Testing GitHub Actions permissions..."
          echo "GITHUB_TOKEN permissions check:"
          echo "- Repository: ${{ github.repository }}"
          echo "- Actor: ${{ github.actor }}"
          echo "- Event: ${{ github.event_name }}"
          
      - name: Create test artifact
        run: |
          echo "Creating test artifact..."
          echo "Build Date: $(date)" > build-info.txt
          echo "Commit: ${{ github.sha }}" >> build-info.txt
          tar -czf test-artifact.tar.gz build-info.txt
          
      - name: Generate attestation (test)
        if: github.event.inputs.test_mode == 'full'
        uses: actions/attest-build-provenance@v1
        with:
          subject-path: test-artifact.tar.gz
          
      - name: Verify result
        run: |
          echo "✅ Permission test completed successfully"
          if [ "${{ github.event.inputs.test_mode }}" == "full" ]; then
            echo "✅ Attestation generation tested"
          fi
EOF

echo -e "${GREEN}✅ 测试工作流已创建: $TEST_WORKFLOW${NC}"

# 4. 使用 GitHub CLI 验证（如果可用）
echo -e "\n${YELLOW}4. GitHub CLI 验证（可选）${NC}"

if command -v gh &> /dev/null; then
    echo "GitHub CLI 已安装"
    
    # 检查认证状态
    if gh auth status &> /dev/null; then
        echo -e "${GREEN}✅ GitHub CLI 已认证${NC}"
        
        # 获取仓库信息
        if [ -d .git ]; then
            REPO_NAME=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
            if [ -n "$REPO_NAME" ]; then
                echo "仓库: $REPO_NAME"
                
                # 检查最近的工作流运行
                echo -e "\n最近的工作流运行:"
                gh run list --limit 3 --workflow docker-build-push.yml 2>/dev/null || echo "暂无运行记录"
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  GitHub CLI 未认证${NC}"
        echo "运行 'gh auth login' 进行认证"
    fi
else
    echo -e "${YELLOW}⚠️  GitHub CLI 未安装${NC}"
    echo "安装命令: brew install gh (macOS) 或访问 https://cli.github.com"
fi

# 5. 生成验证报告
echo -e "\n${BLUE}=========================================${NC}"
echo -e "${BLUE}验证报告总结${NC}"
echo -e "${BLUE}=========================================${NC}"

# 检查关键配置
ISSUES_FOUND=0

# 检查 attestations 权限
if grep -q "attestations: write" "$WORKFLOW_FILE" 2>/dev/null; then
    echo -e "${GREEN}✅ Attestation 权限: 已配置${NC}"
else
    echo -e "${RED}❌ Attestation 权限: 未配置${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# 检查其他必要权限
for perm in "contents: read" "packages: write" "id-token: write"; do
    if grep -q "$perm" "$WORKFLOW_FILE" 2>/dev/null; then
        echo -e "${GREEN}✅ $perm: 已配置${NC}"
    else
        echo -e "${YELLOW}⚠️  $perm: 可能缺失${NC}"
    fi
done

# 最终建议
echo -e "\n${YELLOW}建议的验证步骤:${NC}"
echo "1. 推送代码到 GitHub 触发工作流"
echo "2. 查看 Actions 页面的运行日志"
echo "3. 特别关注 'Generate artifact attestation' 步骤"
echo "4. 使用 'gh run view' 查看详细日志"

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "\n${GREEN}✅ 配置验证通过！Attestation 权限已正确设置。${NC}"
else
    echo -e "\n${RED}⚠️  发现 $ISSUES_FOUND 个潜在问题，请检查配置。${NC}"
fi

# 清理提示
echo -e "\n${YELLOW}注意:${NC}"
echo "- 测试工作流文件 ($TEST_WORKFLOW) 可以在测试后删除"
echo "- 实际验证需要在 GitHub 上运行工作流"
echo "- 确保有有效的 GitHub Token 用于推送和运行"