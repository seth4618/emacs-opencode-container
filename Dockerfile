FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG EOC_TOOLKIT_REV=unknown
ARG OPENCODE_NPM_PACKAGE=opencode-ai
ARG NVM_VERSION=v0.40.3
ARG NODE_VERSION=lts/*

LABEL org.opencontainers.image.title="eoc-base-container" \
      org.opencontainers.image.description="Base image for Emacs/OpenCode dev containers" \
      org.opencontainers.image.revision="${EOC_TOOLKIT_REV}"

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
    emacs-pgtk \
    fonts-dejavu \
    build-essential \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

ENV NVM_DIR=/usr/local/nvm
ENV PATH=${NVM_DIR}/current/bin:${PATH}

RUN mkdir -p "$NVM_DIR" \
    && curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install "$NODE_VERSION" \
    && installed_node="$(nvm current)" \
    && nvm alias default "$installed_node" \
    && ln -sfn "$NVM_DIR/versions/node/${installed_node}" "$NVM_DIR/current" \
    && npm install -g "$OPENCODE_NPM_PACKAGE" \
    && npm cache clean --force \
    && node --version \
    && npm --version \
    && opencode --version

COPY docker/entrypoint.sh /usr/local/bin/container-entrypoint
COPY docker/load-runtime-env.sh /usr/local/bin/load-runtime-env
COPY docker/git-safe /usr/local/bin/git
COPY .devcontainer/elisp-helpers/opencode.el /opt/elisp-helpers/opencode.el
RUN chmod +x /usr/local/bin/container-entrypoint /usr/local/bin/load-runtime-env /usr/local/bin/git \
    && chmod -R a+rX /opt/elisp-helpers

WORKDIR /workspace

ENV SHELL=/bin/bash
ENTRYPOINT ["/usr/local/bin/container-entrypoint"]
CMD ["bash", "-lc", "sleep infinity"]
