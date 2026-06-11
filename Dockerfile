FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG EOC_TOOLKIT_REV=unknown

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
    nodejs \
    npm \
    emacs-pgtk \
    fonts-dejavu \
    build-essential \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY docker/entrypoint.sh /usr/local/bin/container-entrypoint
COPY docker/load-runtime-env.sh /usr/local/bin/load-runtime-env
COPY docker/git-safe /usr/local/bin/git
COPY elisp-helpers/opencode.el /opt/elisp-helpers/opencode.el
RUN chmod +x /usr/local/bin/container-entrypoint /usr/local/bin/load-runtime-env /usr/local/bin/git \
    && chmod -R a+rX /opt/elisp-helpers

WORKDIR /workspace

ENV SHELL=/bin/bash
ENTRYPOINT ["/usr/local/bin/container-entrypoint"]
CMD ["bash", "-lc", "sleep infinity"]
