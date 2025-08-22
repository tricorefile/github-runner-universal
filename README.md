# 🚀 GitHub Actions Universal Runner

一个**通用的、可复用的**GitHub Actions自托管Runner解决方案，支持：
- ✅ **仓库级别**Runner（特定仓库）
- ✅ **组织级别**Runner（所有仓库共享）
- ✅ **企业级别**Runner（企业范围）
- ✅ **多Runner管理**（同时运行多个不同配置）
- ✅ **一键切换**不同项目

## 🎯 核心特性

### 通用性
- **一套代码，多处使用** - 只需修改环境变量即可用于任何GitHub项目
- **三种范围** - 支持仓库/组织/企业级别的Runner
- **预装工具** - 包含主流开发语言和工具链

### 灵活性
- **多配置管理** - 预设多个配置文件，随时切换
- **资源可配** - CPU/内存限制可调
- **缓存共享** - 多个Runner可共享依赖缓存

### 工具支持
预装以下开发工具：
- **语言**: Node.js, Python, Go, Rust, Java, .NET
- **工具**: Docker, Kubernetes, Terraform, Helm
- **数据库客户端**: PostgreSQL, MySQL, Redis
- **版本控制**: Git, Git LFS, SVN

## 📦 快速开始

### 1. 克隆配置
```bash
# 克隆或复制此目录到你的项目
cp -r github-runner-universal /path/to/your/project/
cd /path/to/your/project/github-runner-universal
```

### 2. 配置Token
```bash
# 复制环境变量模板
cp .env.example .env

# 编辑.env文件
nano .env
```

### 3. 选择配置类型

#### 方案A: 仓库Runner（最常用）
```bash
# 编辑.env
GITHUB_TOKEN=your_token
GITHUB_OWNER=your_username
GITHUB_REPOSITORY=your_repo
RUNNER_SCOPE=repo
```

#### 方案B: 组织Runner（共享）
```bash
# 编辑.env
GITHUB_TOKEN=your_token  # 需要admin:org权限
GITHUB_OWNER=your_org_name
RUNNER_SCOPE=org
# 不需要设置GITHUB_REPOSITORY
```

#### 方案C: 使用预设配置
```bash
# 使用预设的配置文件
cp configs/repo-runner.env .env
# 编辑并填入你的Token
```

### 4. 启动Runner
```bash
# 构建镜像
docker-compose build

# 启动
docker-compose up -d

# 查看日志
docker-compose logs -f
```

## 🔄 多项目管理

### 管理多个Runner

使用`run-multi.sh`脚本管理多个Runner：

```bash
# 1. 在configs目录创建多个配置
cp configs/repo-runner.env configs/project1.env
cp configs/repo-runner.env configs/project2.env
# 编辑每个文件，设置不同的仓库

# 2. 启动所有Runner
./run-multi.sh start

# 3. 查看状态
./run-multi.sh status

# 4. 查看特定Runner日志
./run-multi.sh logs project1
```

### 示例：同时管理3个项目

1. **创建配置文件**:
```bash
# configs/frontend.env
GITHUB_TOKEN=your_token
GITHUB_OWNER=mycompany
GITHUB_REPOSITORY=frontend-app
RUNNER_SCOPE=repo
RUNNER_NAME=frontend-runner
CONTAINER_NAME=frontend-runner

# configs/backend.env
GITHUB_TOKEN=your_token
GITHUB_OWNER=mycompany
GITHUB_REPOSITORY=backend-api
RUNNER_SCOPE=repo
RUNNER_NAME=backend-runner
CONTAINER_NAME=backend-runner

# configs/shared.env (组织级别)
GITHUB_TOKEN=your_token
GITHUB_OWNER=mycompany
RUNNER_SCOPE=org
RUNNER_NAME=shared-runner
CONTAINER_NAME=shared-runner
```

2. **批量管理**:
```bash
./run-multi.sh start        # 启动所有
./run-multi.sh status       # 查看状态
./run-multi.sh stop backend # 停止特定Runner
```

## 📁 目录结构

```
github-runner-universal/
├── docker-compose.yml       # 主配置文件
├── Dockerfile              # Runner镜像定义
├── scripts/
│   └── entrypoint.sh      # 智能启动脚本（自动识别scope）
├── configs/               # 预设配置集合
│   ├── repo-runner.env    # 仓库Runner模板
│   ├── org-runner.env     # 组织Runner模板
│   └── ephemeral-runner.env # 临时Runner模板
├── run-multi.sh          # 多Runner管理脚本
├── .env.example          # 环境变量模板
├── work/                 # 工作目录（自动创建）
├── cache/               # 缓存目录（自动创建）
│   ├── cargo/
│   ├── npm/
│   ├── maven/
│   └── gradle/
└── runners/             # 多Runner运行目录（自动创建）
```

## 🔧 高级配置

### 环境变量说明

| 变量 | 说明 | 示例 |
|------|------|------|
| `RUNNER_SCOPE` | Runner范围 | `repo`, `org`, `enterprise` |
| `GITHUB_REPOSITORY` | 仓库名(仅repo模式) | `my-project` |
| `EPHEMERAL` | 临时Runner(运行一次退出) | `true`/`false` |
| `RUNNER_LABELS` | 自定义标签 | `self-hosted,gpu,ubuntu` |
| `CPU_LIMIT` | CPU限制 | `4` |
| `MEMORY_LIMIT` | 内存限制 | `8G` |

### 自定义工具链

如果需要精简镜像，可以编辑Dockerfile注释掉不需要的工具：

```dockerfile
# 例如，如果不需要Rust
# RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
```

### 共享缓存

多个Runner可以共享缓存以加速构建：

```yaml
# docker-compose.yml
volumes:
  - /shared/cache/npm:/home/runner/.npm      # 共享NPM缓存
  - /shared/cache/cargo:/home/runner/.cargo  # 共享Cargo缓存
```

## 🛡️ 安全建议

1. **Token权限**
   - 仓库Runner: `repo`权限
   - 组织Runner: `admin:org`权限
   - 使用细粒度Token限制权限

2. **网络隔离**
   - 为不同项目使用不同的Docker网络
   - 限制Runner的出站访问

3. **定期更新**
   ```bash
   # 更新Runner版本
   docker-compose build --build-arg RUNNER_VERSION=2.329.0
   ```

## 📊 使用场景

### 场景1: 个人开发者
```bash
# 一个配置文件，用于所有个人项目
RUNNER_SCOPE=org
GITHUB_OWNER=my-username
```

### 场景2: 团队协作
```bash
# 为团队创建共享Runner
RUNNER_SCOPE=org
GITHUB_OWNER=team-org
RUNNER_LABELS=self-hosted,shared,production
```

### 场景3: CI/CD管道
```bash
# 临时Runner，用完即删
EPHEMERAL=true
RESTART_POLICY=no
```

### 场景4: 多环境部署
```bash
# 开发环境Runner
configs/dev-runner.env
RUNNER_LABELS=self-hosted,dev

# 生产环境Runner
configs/prod-runner.env
RUNNER_LABELS=self-hosted,prod
```

## 🔍 故障排查

### 查看详细日志
```bash
docker-compose logs -f --tail=100
```

### 验证Token权限
```bash
curl -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/user
```

### 清理并重新注册
```bash
docker-compose down
rm -rf work/*
docker-compose up -d
```

### 常见问题

**Q: Runner显示离线？**
- 检查Token是否过期
- 验证网络连接
- 查看容器日志

**Q: 如何升级Runner版本？**
```bash
# 修改.env中的RUNNER_VERSION
RUNNER_VERSION=2.329.0
# 重新构建
docker-compose build
docker-compose up -d
```

**Q: 可以在一台机器上运行多少个Runner？**
- 取决于机器资源
- 建议每个Runner分配2-4GB内存
- 使用资源限制避免竞争

## 🚀 性能优化

### 1. 使用缓存卷
```yaml
volumes:
  - runner-cache:/home/runner/.cache
```

### 2. 预构建基础镜像
```bash
docker build -t my-runner-base .
docker push my-registry/my-runner-base
```

### 3. 使用本地镜像仓库
```bash
docker run -d -p 5000:5000 registry:2
```

## 📝 许可证

MIT License - 自由使用和修改

## 🤝 贡献

欢迎提交Issue和Pull Request！

---

**提示**: 这是一个通用解决方案，你可以将整个`github-runner-universal`目录复制到任何项目中使用，只需修改`.env`文件即可！