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
    nodejs \
    npm \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
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
