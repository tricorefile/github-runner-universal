# 🍎 macOS GitHub Runner 设置指南

## 概述

虽然 Runner 容器内运行的是 Linux，但可以在 macOS 主机上通过 Docker Desktop 运行。这个指南说明如何在 macOS 上设置和运行 GitHub Actions Runner。

## 系统要求

### 硬件要求
- **Intel Mac**: x86_64 架构
- **Apple Silicon (M1/M2/M3)**: ARM64 架构
- **内存**: 至少 8GB RAM（推荐 16GB）
- **存储**: 至少 20GB 可用空间

### 软件要求
- **macOS**: 12.0 (Monterey) 或更高版本
- **Docker Desktop for Mac**: 4.0 或更高版本
- **Git**: 已安装

## 安装步骤

### 1. 安装 Docker Desktop

```bash
# 使用 Homebrew 安装
brew install --cask docker

# 或从官网下载
# https://www.docker.com/products/docker-desktop/
```

### 2. 配置 Docker Desktop

1. 打开 Docker Desktop
2. 进入 **Preferences** → **Resources**
3. 调整资源分配：
   - CPUs: 至少 2 个（推荐 4 个）
   - Memory: 至少 4GB（推荐 8GB）
   - Swap: 1GB
   - Disk image size: 60GB

4. 进入 **Preferences** → **File Sharing**
5. 添加以下目录：
   - `/Users/Shared`
   - 你的项目目录

### 3. 创建工作目录

```bash
# 创建共享目录结构
sudo mkdir -p /Users/Shared/github-runner/{work,cache,tools,ssh}
sudo mkdir -p /Users/Shared/github-runner/cache/{cargo,npm,maven,gradle}

# 设置权限
sudo chown -R $(whoami):staff /Users/Shared/github-runner
chmod -R 755 /Users/Shared/github-runner
```

### 4. 克隆项目

```bash
# 克隆 Runner 项目
git clone https://github.com/tricorelife-labs/github-runner-universal.git
cd github-runner-universal
```

### 5. 配置 Runner

```bash
# 复制 macOS 配置模板
cp configs/macos-runner.env .env

# 编辑配置
nano .env
```

### 6. 重要配置项

#### 对于 Apple Silicon (M1/M2/M3)：
```bash
RUNNER_PLATFORM=linux/arm64
RUNNER_LABELS=self-hosted,linux,arm64,docker,macos-host,apple-silicon,org-runner
```

#### 对于 Intel Mac：
```bash
RUNNER_PLATFORM=linux/amd64
RUNNER_LABELS=self-hosted,linux,x64,docker,macos-host,intel,org-runner
```

### 7. 启动 Runner

```bash
# 拉取镜像（首次）
docker compose pull

# 启动 Runner
docker compose up -d

# 查看日志
docker compose logs -f
```

## macOS 特定配置

### Docker Socket 权限

macOS 上的 Docker Desktop 自动处理 socket 权限，通常不需要额外配置。

### 文件系统性能优化

编辑 `docker-compose.yml`，为 volumes 添加性能标记：

```yaml
volumes:
  - /Users/Shared/github-runner/work:/home/runner/_work:delegated
  - /Users/Shared/github-runner/cache/npm:/home/runner/.npm:cached
  - /Users/Shared/github-runner/cache/cargo:/home/runner/.cargo:cached
```

- `:delegated` - 容器内的写入操作优先（适合工作目录）
- `:cached` - 主机的读取操作优先（适合缓存目录）
- `:consistent` - 完全同步（默认，性能最差）

## 标签使用指南

### 推荐的标签组合

#### 基础标签
```yaml
runs-on: [self-hosted, macos-host]  # 任何 macOS 主机上的 Runner
```

#### 架构特定
```yaml
# Apple Silicon
runs-on: [self-hosted, arm64, apple-silicon]

# Intel Mac
runs-on: [self-hosted, x64, intel]
```

#### 完整示例
```yaml
name: macOS Runner Test

on: [push, pull_request]

jobs:
  test-on-macos-host:
    runs-on: [self-hosted, docker, macos-host]
    steps:
      - uses: actions/checkout@v4
      
      - name: System Info
        run: |
          echo "Runner OS: $(uname -s)"
          echo "Runner Arch: $(uname -m)"
          echo "Docker Version: $(docker --version)"
      
      - name: Build
        run: |
          npm install
          npm run build
```

## 性能优化建议

### 1. 使用本地缓存

在 `.env` 中配置本地缓存路径：

```bash
# 使用用户目录而不是 /Users/Shared（更快）
NPM_CACHE=~/Library/Caches/github-runner/npm
CARGO_CACHE=~/Library/Caches/github-runner/cargo
```

### 2. Docker 镜像缓存

```bash
# 定期清理未使用的镜像
docker system prune -a --volumes

# 保留常用镜像
docker image prune --filter "until=24h"
```

### 3. 并行 Runner

可以运行多个 Runner 实例：

```bash
# Runner 1
CONTAINER_NAME=macos-runner-1 RUNNER_NAME=mac-1 docker compose up -d

# Runner 2  
CONTAINER_NAME=macos-runner-2 RUNNER_NAME=mac-2 docker compose up -d
```

## 故障排查

### 常见问题

#### 1. Docker Desktop 未运行
```
Cannot connect to the Docker daemon
```
**解决**: 启动 Docker Desktop 应用

#### 2. 内存不足
```
Container killed due to memory limit
```
**解决**: 在 Docker Desktop 中增加内存分配

#### 3. 文件权限问题
```
Permission denied: /Users/Shared/github-runner
```
**解决**: 
```bash
sudo chown -R $(whoami):staff /Users/Shared/github-runner
```

#### 4. Apple Silicon 兼容性
```
WARNING: The requested image's platform (linux/amd64) does not match the detected host platform
```
**解决**: 设置 `RUNNER_PLATFORM=linux/arm64`

### 日志位置

- **Runner 日志**: `docker compose logs`
- **Docker Desktop 日志**: `~/Library/Containers/com.docker.docker/Data/log/`
- **工作目录日志**: `/Users/Shared/github-runner/work/_diag/`

## 监控和维护

### 健康检查

```bash
# 检查 Runner 状态
docker compose ps

# 检查资源使用
docker stats $(docker compose ps -q)

# 检查 Docker Desktop 资源
docker system df
```

### 定期维护

创建维护脚本 `maintain.sh`:

```bash
#!/bin/bash

# 清理旧的工作目录
find /Users/Shared/github-runner/work -type d -name "_temp" -mtime +7 -exec rm -rf {} \;

# 清理 Docker
docker system prune -f

# 更新 Runner 镜像
docker compose pull

# 重启 Runner
docker compose restart

echo "Maintenance completed"
```

### 自动启动

使用 launchd 自动启动 Runner：

1. 创建 `~/Library/LaunchAgents/com.github.runner.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.github.runner</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/docker</string>
        <string>compose</string>
        <string>-f</string>
        <string>/path/to/github-runner-universal/docker-compose.yml</string>
        <string>up</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/github-runner.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/github-runner-error.log</string>
</dict>
</plist>
```

2. 加载服务：
```bash
launchctl load ~/Library/LaunchAgents/com.github.runner.plist
```

## 安全建议

1. **使用专用用户账户**运行 Runner
2. **限制文件系统访问**只允许必要的目录
3. **定期更新** Docker Desktop 和 Runner 镜像
4. **使用只读挂载**对于不需要写入的目录
5. **启用 Docker Content Trust**验证镜像签名

## 相关资源

- [Docker Desktop for Mac 文档](https://docs.docker.com/desktop/mac/)
- [GitHub Actions Runner 文档](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Apple Silicon Docker 最佳实践](https://docs.docker.com/desktop/mac/apple-silicon/)