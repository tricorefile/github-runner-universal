FROM ubuntu:24.04

ARG RUNNER_VERSION=2.328.0
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETPLATFORM=linux/amd64

# 安装基础依赖
RUN apt-get update && apt-get install -y \
    curl \
    tar \
    git \
    sudo \
    jq \
    zip \
    unzip \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3 \
    python3-venv \
    python3-dev \
    python3-pip \
    # 网络工具
    iputils-ping \
    dnsutils \
    netcat-openbsd \
    # 进程管理
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# 安装Docker CLI
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-buildx-plugin docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# 根据平台需求安装常见开发工具
RUN apt-get update && apt-get install -y \
    # 版本控制
    git-lfs \
    subversion \
    mercurial \
    # C/C++开发
    gcc \
    g++ \
    make \
    cmake \
    autoconf \
    automake \
    libtool \
    # 数据库客户端
    postgresql-client \
    mysql-client \
    redis-tools \
    # 云CLI工具占位符（根据需要稍后安装）
    && rm -rf /var/lib/apt/lists/*

# 安装Node.js (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn pnpm && \
    rm -rf /var/lib/apt/lists/*

# 安装Go
RUN wget -q https://go.dev/dl/go1.22.0.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz && \
    rm go1.22.0.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# Rust将在切换到runner用户后安装

# 安装Python工具 - 使用专用虚拟环境避免PEP 668问题
RUN python3 -m venv /opt/pytools && \
    /opt/pytools/bin/pip install --upgrade pip && \
    /opt/pytools/bin/pip install --no-cache-dir \
    pipenv \
    poetry \
    virtualenv \
    tox \
    black \
    flake8 \
    mypy \
    pytest

# 将Python工具添加到PATH
ENV PATH="/opt/pytools/bin:${PATH}"

# 安装Java (OpenJDK)
RUN apt-get update && \
    apt-get install -y openjdk-17-jdk maven gradle ant && \
    rm -rf /var/lib/apt/lists/*

# 安装.NET SDK
RUN wget -q https://dot.net/v1/dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet && \
    rm dotnet-install.sh
ENV PATH="/usr/share/dotnet:${PATH}"
ENV DOTNET_ROOT="/usr/share/dotnet"

# 安装Protocol Buffers
RUN apt-get update && \
    apt-get install -y protobuf-compiler libprotobuf-dev && \
    rm -rf /var/lib/apt/lists/*

# 安装kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# 安装Helm - 直接下载二进制文件以避免脚本检测问题
RUN HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/') && \
    wget -q https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz && \
    tar -zxf helm-v${HELM_VERSION}-linux-amd64.tar.gz && \
    mv linux-amd64/helm /usr/local/bin/helm && \
    rm -rf linux-amd64 helm-v${HELM_VERSION}-linux-amd64.tar.gz && \
    chmod +x /usr/local/bin/helm

# 安装Terraform
RUN wget -q https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip && \
    unzip terraform_1.7.0_linux_amd64.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform_1.7.0_linux_amd64.zip

# 创建Runner用户
RUN groupadd -f docker && \
    useradd -m -s /bin/bash runner && \
    usermod -aG sudo,docker runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 切换到Runner用户
USER runner
WORKDIR /home/runner

# 安装Rust（以runner用户身份）
RUN mkdir -p /home/runner/.cargo/bin && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
    . $HOME/.cargo/env && \
    rustup component add rustfmt clippy

# 安装GitHub Actions Runner
RUN mkdir actions-runner && cd actions-runner && \
    curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# 复制脚本
COPY --chown=runner:runner scripts/ /home/runner/scripts/
RUN chmod +x /home/runner/scripts/*.sh

# 为所有工具设置PATH
ENV PATH="/home/runner/.cargo/bin:/opt/pytools/bin:/usr/local/go/bin:/usr/share/dotnet:/usr/local/bin:${PATH}"
ENV DOTNET_ROOT="/usr/share/dotnet"

WORKDIR /home/runner/actions-runner
ENTRYPOINT ["/home/runner/scripts/entrypoint.sh"]