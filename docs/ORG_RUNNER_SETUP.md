# 🏢 组织级别 Runner 配置指南

## 概述

组织级别的 Runner 可以被组织内的所有仓库共享使用，提供了更灵活的资源管理和更高的利用率。

## 配置步骤

### 1. 创建 GitHub Token

组织级别 Runner 需要具有 `admin:org` 权限的 Token：

1. 访问 [GitHub Token 设置页面](https://github.com/settings/tokens)
2. 点击 "Generate new token (classic)"
3. 选择以下权限：
   - ✅ **admin:org** - Full control of orgs and teams, read and write org projects
   - ✅ **repo** - Full control of private repositories (可选，用于私有仓库)
4. 生成并保存 Token

### 2. 使用预设配置

```bash
# 复制组织级别配置模板
cp configs/org-runner.env .env

# 编辑配置文件
nano .env
```

### 3. 修改关键配置

编辑 `.env` 文件，设置以下必要参数：

```bash
# 设置你的 Token（需要 admin:org 权限）
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx

# 设置组织名称
GITHUB_OWNER=your-org-name

# 确保 RUNNER_SCOPE 设置为 org
RUNNER_SCOPE=org

# 不要设置 GITHUB_REPOSITORY（留空或删除）
# GITHUB_REPOSITORY=  # 此行应该删除或留空
```

### 4. 启动 Runner

```bash
# 拉取最新镜像
docker compose pull

# 启动 Runner
docker compose up -d

# 查看日志确认运行状态
docker compose logs -f
```

### 5. 验证 Runner

1. 访问组织设置页面：`https://github.com/organizations/YOUR_ORG/settings/actions/runners`
2. 你应该能看到新注册的 Runner
3. 状态应该显示为 "Idle"（空闲）或 "Active"（活动）

## 在仓库中使用组织 Runner

在任何组织仓库的 workflow 文件中，可以通过标签使用此 Runner：

```yaml
name: CI

on: [push, pull_request]

jobs:
  build:
    # 使用组织级别的 self-hosted runner
    runs-on: [self-hosted, linux, x64, org-runner]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Run build
        run: |
          echo "Running on organization runner"
          # 你的构建命令
```

## 多 Runner 管理

如果需要为组织运行多个 Runner：

### 方式一：不同配置文件

```bash
# 创建多个配置
cp configs/org-runner.env configs/org-runner-1.env
cp configs/org-runner.env configs/org-runner-2.env

# 修改每个配置中的：
# - RUNNER_NAME（必须唯一）
# - CONTAINER_NAME（必须唯一）
# - 可选：不同的 RUNNER_LABELS

# 使用不同配置启动
docker compose --env-file configs/org-runner-1.env up -d
docker compose --env-file configs/org-runner-2.env up -d
```

### 方式二：使用 run-multi.sh 脚本

```bash
# 配置多个组织 Runner
./run-multi.sh start org-runner-1
./run-multi.sh start org-runner-2

# 查看所有 Runner 状态
./run-multi.sh status
```

## 权限管理

### Runner 组管理

可以创建不同的 Runner 组来控制访问权限：

1. 在组织设置中创建 Runner 组
2. 设置哪些仓库可以访问该组
3. 在 `.env` 中设置 `RUNNER_GROUP=your-group-name`

### 示例配置

```bash
# 生产环境 Runner 组
RUNNER_GROUP=production
RUNNER_LABELS=self-hosted,linux,x64,production

# 开发环境 Runner 组  
RUNNER_GROUP=development
RUNNER_LABELS=self-hosted,linux,x64,development
```

## 最佳实践

### 1. 资源配置

组织级别 Runner 通常需要更多资源：

```bash
# 建议配置
CPU_LIMIT=8
MEMORY_LIMIT=16G
```

### 2. 缓存共享

利用共享缓存提高构建速度：

```bash
# 所有仓库共享缓存目录
CARGO_CACHE=/shared/cache/cargo
NPM_CACHE=/shared/cache/npm
MAVEN_CACHE=/shared/cache/maven
```

### 3. 标签策略

使用清晰的标签策略：

```bash
# 基础标签
RUNNER_LABELS=self-hosted,linux,x64

# 添加组织特定标签
RUNNER_LABELS=self-hosted,linux,x64,org-shared

# 添加能力标签
RUNNER_LABELS=self-hosted,linux,x64,docker,node18,python3
```

### 4. 监控和维护

```bash
# 查看 Runner 日志
docker compose logs -f

# 重启 Runner
docker compose restart

# 更新 Runner 镜像
docker compose pull
docker compose up -d
```

## 故障排查

### Runner 显示离线

1. 检查 Token 权限：
```bash
curl -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/orgs/YOUR_ORG
```

2. 查看容器日志：
```bash
docker compose logs --tail=50
```

### 权限错误

确保 Token 具有 `admin:org` 权限，而不仅仅是 `repo` 权限。

### Runner 未出现在组织设置中

1. 确认 `RUNNER_SCOPE=org`
2. 确认未设置 `GITHUB_REPOSITORY`
3. 确认 `GITHUB_OWNER` 是组织名称，不是用户名

## 安全建议

1. **Token 管理**：
   - 使用环境变量或密钥管理系统
   - 定期轮换 Token
   - 使用最小必要权限

2. **网络隔离**：
   - 考虑为 Runner 使用独立的网络
   - 限制出站访问

3. **资源限制**：
   - 始终设置 CPU 和内存限制
   - 监控资源使用情况

## 相关链接

- [GitHub 组织 Runner 文档](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#about-self-hosted-runners-for-organizations)
- [Runner 组管理](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/managing-access-to-self-hosted-runners-using-groups)