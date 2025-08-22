# 📝 GitHub Token 设置指南

## 🔧 设置Token到Runner容器的方法

### 方法1: 使用.env文件（推荐）

```bash
# 1. 进入runner目录
cd github-runner-universal

# 2. 创建.env文件
cp .env.example .env

# 3. 编辑.env文件
nano .env
# 或
vim .env
```

在.env文件中设置：
```bash
# 将你的token粘贴在这里
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GITHUB_OWNER=max1015070108
GITHUB_REPOSITORY=UserAgent
```

### 方法2: 直接在命令行设置（临时）

```bash
# 使用export设置环境变量
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 然后启动容器
docker-compose up -d
```

### 方法3: 在docker-compose命令中指定

```bash
# 直接在命令中传递环境变量
GITHUB_TOKEN=ghp_xxxxx GITHUB_OWNER=max1015070108 GITHUB_REPOSITORY=UserAgent \
docker-compose up -d
```

### 方法4: 使用Docker secrets（更安全）

创建文件 `docker-compose.secrets.yml`:
```yaml
version: '3.8'

secrets:
  github_token:
    file: ./secrets/github_token.txt

services:
  runner:
    secrets:
      - github_token
    environment:
      - GITHUB_TOKEN_FILE=/run/secrets/github_token
```

```bash
# 创建secrets目录
mkdir -p secrets

# 将token保存到文件
echo "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" > secrets/github_token.txt

# 使用secrets启动
docker-compose -f docker-compose.yml -f docker-compose.secrets.yml up -d
```

### 方法5: 使用系统环境变量文件

```bash
# 创建环境变量文件
cat > ~/runner.env << EOF
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
export GITHUB_OWNER=max1015070108
export GITHUB_REPOSITORY=UserAgent
EOF

# 加载环境变量
source ~/runner.env

# 启动容器
docker-compose up -d
```

## ⚠️ 安全最佳实践

### 1. 不要提交Token到Git

确保`.gitignore`包含：
```
.env
*.env
secrets/
```

### 2. 使用环境特定的配置

```bash
# 开发环境
cp .env.example .env.development
# 生产环境
cp .env.example .env.production

# 启动时指定
docker-compose --env-file .env.production up -d
```

### 3. Token权限最小化

- 仓库Runner只需要：`repo`权限
- 组织Runner需要：`admin:org`权限
- 不要给予不必要的权限

## 🔍 验证Token是否正确设置

### 检查方法1: 查看容器环境变量

```bash
# 查看运行中的容器环境变量
docker-compose exec runner env | grep GITHUB

# 应该看到：
# GITHUB_TOKEN=ghp_xxxx...
# GITHUB_OWNER=max1015070108
# GITHUB_REPOSITORY=UserAgent
```

### 检查方法2: 查看容器日志

```bash
# 查看启动日志
docker-compose logs -f

# 成功的话会看到：
# [INFO] Successfully obtained registration token
# [INFO] Runner configured successfully
```

### 检查方法3: 进入容器测试

```bash
# 进入容器
docker-compose exec runner bash

# 在容器内测试token
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user

# 应该返回你的用户信息
```

## 🚨 常见问题

### 问题1: Token无效

错误信息：
```
[ERROR] Failed to get registration token
```

解决方法：
```bash
# 1. 检查token是否过期
# 2. 检查token权限是否正确
# 3. 重新生成token
```

### 问题2: 环境变量未设置

错误信息：
```
Need GITHUB_TOKEN environment variable
```

解决方法：
```bash
# 确保.env文件存在且格式正确
cat .env

# 确保没有多余的空格或引号
GITHUB_TOKEN=ghp_xxxxx  # 正确
GITHUB_TOKEN="ghp_xxxxx"  # 错误（不要加引号）
GITHUB_TOKEN= ghp_xxxxx  # 错误（等号后不要有空格）
```

### 问题3: Docker Compose不读取.env

解决方法：
```bash
# 确保.env文件在docker-compose.yml同目录
ls -la | grep .env

# 或明确指定env文件
docker-compose --env-file .env up -d
```

## 📋 完整设置示例

```bash
# 1. 克隆或创建配置目录
mkdir my-runner && cd my-runner

# 2. 创建.env文件
cat > .env << EOF
# GitHub Configuration
GITHUB_TOKEN=ghp_your_actual_token_here
GITHUB_OWNER=max1015070108
GITHUB_REPOSITORY=UserAgent
RUNNER_SCOPE=repo
RUNNER_NAME=my-runner-1
RUNNER_LABELS=self-hosted,linux,x64,docker

# Container Configuration
CONTAINER_NAME=useragent-runner
CPU_LIMIT=4
MEMORY_LIMIT=8G
EOF

# 3. 启动容器
docker-compose up -d

# 4. 验证运行状态
docker-compose ps
docker-compose logs --tail=50

# 5. 检查GitHub网页
# 访问: https://github.com/max1015070108/UserAgent/settings/actions/runners
# 应该能看到runner在线（绿色圆点）
```

## 🔐 Token安全存储方案

### 使用密码管理器

```bash
# 使用1Password CLI
op read "op://vault/GitHub-Runner-Token/password" | \
  docker-compose run -e GITHUB_TOKEN runner

# 使用pass
pass show github/runner-token | \
  docker-compose run -e GITHUB_TOKEN runner
```

### 使用环境变量管理工具

```bash
# 使用direnv
echo 'export GITHUB_TOKEN=ghp_xxx' > .envrc
direnv allow

# 使用dotenv
npm install -g dotenv-cli
dotenv -e .env docker-compose up
```

## 📊 多Token管理（多项目）

如果管理多个项目的runner：

```bash
# 项目1的token
echo "GITHUB_TOKEN=ghp_project1_token" > configs/project1.env

# 项目2的token  
echo "GITHUB_TOKEN=ghp_project2_token" > configs/project2.env

# 使用不同配置启动
docker-compose --env-file configs/project1.env up -d
```

---

**记住**: Token是敏感信息，妥善保管，定期轮换！