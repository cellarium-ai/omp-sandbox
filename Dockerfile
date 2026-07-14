FROM oven/bun:1-debian

USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    openssh-client \
    ripgrep \
    fd-find \
    jq \
    less \
    nano \
    vim \
    tree \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# Install Node 24 via NodeSource — apt ships Node 18 on bookworm, but
# @discourse/mcp requires >=24.
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

RUN mkdir -p /workspace /home/bun/.omp /home/bun/.bun \
    && chown -R bun:bun /workspace /home/bun

USER bun

ENV HOME=/home/bun
ENV BUN_INSTALL=/home/bun/.bun
ENV PATH=/home/bun/.bun/bin:/usr/local/bin:/home/bun/.local/bin:$PATH

RUN bun install -g @oh-my-pi/pi-coding-agent

WORKDIR /workspace

CMD ["omp"]
