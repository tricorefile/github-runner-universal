# 本地验证指南

本文档提供了多种方法来本地验证 GitHub Actions Runner Universal 项目，特别是 attestation 权限修复。

## 快速开始

```bash
# 1. 验证 attestation 权限配置
./verify-attestation.sh

# 2. 测试 Docker 镜像构建
./local-test.sh

# 3. 测试 GitHub Actions 工作流
./test-github-actions.sh
```

## 验证方法详解

### 方法 1: 验证 Attestation 权限配置

**用途**: 快速检查工作流文件中的权限配置是否正确

```bash
./verify-attestation.sh
```

**验证内容**:
- ✅ 检查 `attestations: write` 权限
- ✅ 验证其他必要权限
- ✅ 检查 attestation action 配置
- ✅ 生成验证报告

### 方法 2: Docker 镜像本地构建测试

**用途**: 验证 Docker 镜像能否正常构建，包含所有必要工具

```bash
# 运行完整测试
./local-test.sh

# 或手动构建
docker build -t github-runner-test:latest .

# 验证镜像
docker run --rm github-runner-test:latest bash -c "git --version && docker --version"
```

**测试内容**:
- Docker 镜像构建
- 预装工具版本检查
- Runner 用户权限验证
- Docker 组配置验证

### 方法 3: 使用 act 工具测试 GitHub Actions

**用途**: 在本地模拟 GitHub Actions 环境运行工作流

```bash
# 安装 act (如果未安装)
brew install act  # macOS
# 或
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash  # Linux

# 运行测试脚本
./test-github-actions.sh
```

**测试选项**:
1. 列出所有工作流
2. 干运行测试（不实际执行）
3. 完整运行测试
4. 测试特定事件（push/pull_request）
5. 测试 attestation 步骤

### 方法 4: Docker Compose 集成测试

**用途**: 模拟生产环境的多服务部署

```bash
# 启动测试环境
docker-compose -f docker-compose.test.yml up -d

# 查看日志
docker-compose -f docker-compose.test.yml logs -f

# 停止测试
docker-compose -f docker-compose.test.yml down
```

**注意**: 需要配置实际的 GitHub Token 进行完整测试：
```yaml
environment:
  GITHUB_TOKEN: "your_github_pat_token"
  GITHUB_OWNER: "your_username_or_org"
  GITHUB_REPOSITORY: "your_repo_name"
```

### 方法 5: GitHub CLI 验证

**用途**: 使用 GitHub CLI 直接验证工作流运行状态

```bash
# 安装 GitHub CLI
brew install gh  # macOS

# 认证
gh auth login

# 查看工作流运行
gh run list --workflow docker-build-push.yml

# 查看特定运行的详细信息
gh run view <run-id>

# 手动触发工作流
gh workflow run docker-build-push.yml
```

## 验证检查清单

### ✅ 权限配置验证
- [ ] `attestations: write` 权限已添加
- [ ] `contents: read` 权限存在
- [ ] `packages: write` 权限存在
- [ ] `id-token: write` 权限存在

### ✅ Docker 构建验证
- [ ] Docker 镜像成功构建
- [ ] Runner 用户正确创建
- [ ] Docker 组正确配置
- [ ] 所有必要工具已安装

### ✅ GitHub Actions 验证
- [ ] 工作流语法正确
- [ ] act 工具可以运行工作流
- [ ] Attestation 步骤无错误

## 常见问题

### Q1: "Resource not accessible by integration" 错误
**解决方案**: 确保工作流包含 `attestations: write` 权限

### Q2: Docker 组不存在错误
**解决方案**: 确保 Dockerfile 包含 `groupadd -f docker` 命令

### Q3: act 工具运行失败
**解决方案**: 
- 确保 Docker 正在运行
- 使用 `.actrc` 配置文件指定正确的镜像
- 检查 `.secrets` 文件中的 token 配置

## 推送前检查

在推送代码到 GitHub 之前，运行以下命令确保一切正常：

```bash
# 1. 验证配置
./verify-attestation.sh

# 2. 构建测试
docker build -t test:latest .

# 3. 语法检查
act -n  # 干运行，仅检查语法
```

## 相关文件

- `local-test.sh` - Docker 构建测试脚本
- `test-github-actions.sh` - GitHub Actions 测试脚本
- `verify-attestation.sh` - Attestation 权限验证脚本
- `docker-compose.test.yml` - Docker Compose 测试配置
- `.github/workflows/test-attestation-local.yml` - 测试工作流

## 支持

如遇到问题，请：
1. 检查错误日志
2. 运行验证脚本
3. 查看 GitHub Actions 文档：https://docs.github.com/en/actions
4. 提交 Issue 到项目仓库