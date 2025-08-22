FROM ubuntu:24.04

ARG RUNNER_VERSION=2.328.0
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETPLATFORM=linux/amd64

# Install base dependencies
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
    # Network tools
    iputils-ping \
    dnsutils \
    netcat-openbsd \
    # Process management
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-buildx-plugin docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# Install common development tools based on platform needs
RUN apt-get update && apt-get install -y \
    # Version control
    git-lfs \
    subversion \
    mercurial \
    # C/C++ development
    gcc \
    g++ \
    make \
    cmake \
    autoconf \
    automake \
    libtool \
    # Database clients
    postgresql-client \
    mysql-client \
    redis-tools \
    # Cloud CLI tools placeholder (installed later based on needs)
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn pnpm && \
    rm -rf /var/lib/apt/lists/*

# Install Go
RUN wget -q https://go.dev/dl/go1.22.0.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz && \
    rm go1.22.0.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# Install Rust (optional, can be commented out if not needed)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Python tools
RUN pip3 install --no-cache-dir \
    pipenv \
    poetry \
    virtualenv \
    tox \
    black \
    flake8 \
    mypy \
    pytest

# Install Java (OpenJDK)
RUN apt-get update && \
    apt-get install -y openjdk-17-jdk maven gradle ant && \
    rm -rf /var/lib/apt/lists/*

# Install .NET SDK
RUN wget -q https://dot.net/v1/dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet && \
    rm dotnet-install.sh
ENV PATH="/usr/share/dotnet:${PATH}"
ENV DOTNET_ROOT="/usr/share/dotnet"

# Install Protocol Buffers
RUN apt-get update && \
    apt-get install -y protobuf-compiler libprotobuf-dev && \
    rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Terraform
RUN wget -q https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip && \
    unzip terraform_1.7.0_linux_amd64.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform_1.7.0_linux_amd64.zip

# Create runner user
RUN useradd -m -s /bin/bash runner && \
    usermod -aG sudo,docker runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to runner user
USER runner
WORKDIR /home/runner

# Copy Rust environment to runner user
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
    . $HOME/.cargo/env && \
    rustup component add rustfmt clippy

# Install GitHub Actions Runner
RUN mkdir actions-runner && cd actions-runner && \
    curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Copy scripts
COPY --chown=runner:runner scripts/ /home/runner/scripts/
RUN chmod +x /home/runner/scripts/*.sh

# Set PATH for all tools
ENV PATH="/home/runner/.cargo/bin:/usr/local/go/bin:/usr/share/dotnet:/usr/local/bin:${PATH}"
ENV DOTNET_ROOT="/usr/share/dotnet"

WORKDIR /home/runner/actions-runner
ENTRYPOINT ["/home/runner/scripts/entrypoint.sh"]