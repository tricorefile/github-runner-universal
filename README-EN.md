# 🚀 GitHub Actions Universal Runner

A **universal, reusable** GitHub Actions self-hosted runner solution supporting:
- ✅ **Repository-level** runners (specific repositories)
- ✅ **Organization-level** runners (shared across all repositories)
- ✅ **Enterprise-level** runners (enterprise-wide)
- ✅ **Multi-runner management** (run multiple runners with different configurations simultaneously)
- ✅ **One-click switching** between different projects

## 🎯 Core Features

### Universality
- **One codebase, multiple uses** - Simply modify environment variables to use with any GitHub project
- **Three scopes** - Supports repository/organization/enterprise level runners
- **Pre-installed tools** - Includes mainstream development languages and toolchains

### Flexibility
- **Multi-configuration management** - Pre-configured files, switch anytime
- **Configurable resources** - Adjustable CPU/memory limits
- **Cache sharing** - Multiple runners can share dependency caches

### Tool Support
Pre-installed development tools:
- **Languages**: Node.js, Python, Go, Rust, Java, .NET
- **Tools**: Docker, Kubernetes, Terraform, Helm
- **Database clients**: PostgreSQL, MySQL, Redis
- **Version control**: Git, Git LFS, SVN

## 📦 Quick Start

### 1. Clone Configuration
```bash
# Clone or copy this directory to your project
cp -r github-runner-universal /path/to/your/project/
cd /path/to/your/project/github-runner-universal
```

### 2. Configure Token
```bash
# Copy environment variable template
cp .env.example .env

# Edit .env file
nano .env
```

### 3. Choose Configuration Type

#### Option A: Repository Runner (Most Common)
```bash
# Edit .env
GITHUB_TOKEN=your_token
GITHUB_OWNER=your_username
GITHUB_REPOSITORY=your_repo
RUNNER_SCOPE=repo
```

#### Option B: Organization Runner (Shared)
```bash
# Edit .env
GITHUB_TOKEN=your_token  # Requires admin:org permission
GITHUB_OWNER=your_org_name
RUNNER_SCOPE=org
# No need to set GITHUB_REPOSITORY
```

#### Option C: Use Preset Configuration
```bash
# Use preset configuration file
cp configs/repo-runner.env .env
# Edit and fill in your Token
```

### 4. Start Runner
```bash
# Build image
docker-compose build

# Start
docker-compose up -d

# View logs
docker-compose logs -f
```

## 🔄 Multi-Project Management

### Managing Multiple Runners

Use the `run-multi.sh` script to manage multiple runners:

```bash
# 1. Create multiple configurations in configs directory
cp configs/repo-runner.env configs/project1.env
cp configs/repo-runner.env configs/project2.env
# Edit each file to set different repositories

# 2. Start all runners
./run-multi.sh start

# 3. Check status
./run-multi.sh status

# 4. View specific runner logs
./run-multi.sh logs project1
```

### Example: Managing 3 Projects Simultaneously

1. **Create configuration files**:
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

# configs/shared.env (organization level)
GITHUB_TOKEN=your_token
GITHUB_OWNER=mycompany
RUNNER_SCOPE=org
RUNNER_NAME=shared-runner
CONTAINER_NAME=shared-runner
```

2. **Batch management**:
```bash
./run-multi.sh start        # Start all
./run-multi.sh status       # Check status
./run-multi.sh stop backend # Stop specific runner
```

## 📁 Directory Structure

```
github-runner-universal/
├── docker-compose.yml       # Main configuration file
├── Dockerfile              # Runner image definition
├── scripts/
│   └── entrypoint.sh      # Smart startup script (auto-detects scope)
├── configs/               # Preset configuration collection
│   ├── repo-runner.env    # Repository runner template
│   ├── org-runner.env     # Organization runner template
│   └── ephemeral-runner.env # Ephemeral runner template
├── run-multi.sh          # Multi-runner management script
├── .env.example          # Environment variable template
├── work/                 # Work directory (auto-created)
├── cache/               # Cache directory (auto-created)
│   ├── cargo/
│   ├── npm/
│   ├── maven/
│   └── gradle/
└── runners/             # Multi-runner runtime directory (auto-created)
```

## 🔧 Advanced Configuration

### Environment Variable Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `RUNNER_SCOPE` | Runner scope | `repo`, `org`, `enterprise` |
| `GITHUB_REPOSITORY` | Repository name (repo mode only) | `my-project` |
| `EPHEMERAL` | Ephemeral runner (run once and exit) | `true`/`false` |
| `RUNNER_LABELS` | Custom labels | `self-hosted,gpu,ubuntu` |
| `CPU_LIMIT` | CPU limit | `4` |
| `MEMORY_LIMIT` | Memory limit | `8G` |

### Custom Toolchain

To slim down the image, edit the Dockerfile to comment out unnecessary tools:

```dockerfile
# For example, if Rust is not needed
# RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
```

### Shared Cache

Multiple runners can share cache to speed up builds:

```yaml
# docker-compose.yml
volumes:
  - /shared/cache/npm:/home/runner/.npm      # Share NPM cache
  - /shared/cache/cargo:/home/runner/.cargo  # Share Cargo cache
```

## 🛡️ Security Recommendations

1. **Token Permissions**
   - Repository runner: `repo` permission
   - Organization runner: `admin:org` permission
   - Use fine-grained tokens to limit permissions

2. **Network Isolation**
   - Use different Docker networks for different projects
   - Restrict outbound access for runners

3. **Regular Updates**
   ```bash
   # Update runner version
   docker-compose build --build-arg RUNNER_VERSION=2.329.0
   ```

## 📊 Use Cases

### Scenario 1: Individual Developer
```bash
# One configuration file for all personal projects
RUNNER_SCOPE=org
GITHUB_OWNER=my-username
```

### Scenario 2: Team Collaboration
```bash
# Create shared runner for team
RUNNER_SCOPE=org
GITHUB_OWNER=team-org
RUNNER_LABELS=self-hosted,shared,production
```

### Scenario 3: CI/CD Pipeline
```bash
# Ephemeral runner, disposable after use
EPHEMERAL=true
RESTART_POLICY=no
```

### Scenario 4: Multi-Environment Deployment
```bash
# Development environment runner
configs/dev-runner.env
RUNNER_LABELS=self-hosted,dev

# Production environment runner
configs/prod-runner.env
RUNNER_LABELS=self-hosted,prod
```

## 🔍 Troubleshooting

### View Detailed Logs
```bash
docker-compose logs -f --tail=100
```

### Verify Token Permissions
```bash
curl -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/user
```

### Clean and Re-register
```bash
docker-compose down
rm -rf work/*
docker-compose up -d
```

### Common Issues

**Q: Runner shows offline?**
- Check if token has expired
- Verify network connection
- Check container logs

**Q: How to upgrade runner version?**
```bash
# Modify RUNNER_VERSION in .env
RUNNER_VERSION=2.329.0
# Rebuild
docker-compose build
docker-compose up -d
```

**Q: How many runners can run on one machine?**
- Depends on machine resources
- Recommend 2-4GB memory per runner
- Use resource limits to avoid contention

## 🚀 Performance Optimization

### 1. Use Cache Volumes
```yaml
volumes:
  - runner-cache:/home/runner/.cache
```

### 2. Pre-build Base Image
```bash
docker build -t my-runner-base .
docker push my-registry/my-runner-base
```

### 3. Use Local Registry
```bash
docker run -d -p 5000:5000 registry:2
```

## 📝 License

MIT License - Free to use and modify

## 🤝 Contributing

Issues and Pull Requests are welcome!

---

**Note**: This is a universal solution. You can copy the entire `github-runner-universal` directory to any project and use it by simply modifying the `.env` file!