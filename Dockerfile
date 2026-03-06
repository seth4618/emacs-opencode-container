FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
ARG OPENCODE_NPM_PACKAGE=opencode-ai

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    fd-find \
    git \
    jq \
    less \
    procps \
    ripgrep \
    rsync \
    openssh-client \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    emacs-gtk \
    fonts-dejavu \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/bash "${USERNAME}"

RUN npm install -g pnpm typescript typescript-language-server pyright solhint hardhat @nomicfoundation/solidity-language-server "${OPENCODE_NPM_PACKAGE}" || true

USER ${USERNAME}
WORKDIR /workspace

ENV HOME=/home/${USERNAME}
ENV PATH=${HOME}/.local/bin:${PATH}

CMD ["bash", "-lc", "sleep infinity"]
