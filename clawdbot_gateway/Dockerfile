# Version-Pinning für reproduzierbare Builds
ARG NODE_VERSION=24
ARG GOG_VERSION=0.6.1
ARG BUN_VERSION=1.1.38
ARG PNPM_VERSION=9.15.2
ARG TARGETARCH

FROM node:${NODE_VERSION}-bookworm-slim

# Use bash with pipefail so curl|tar failures stop the build.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Pull latest Debian security updates, then clean apt caches.
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    git \
    jq \
    ripgrep \
    curl \
    nano \
    unzip \
    python3 \
    python3-pip \
    make \
    g++ \
    openssh-server \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (EINMAL - Duplikat entfernt!)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && apt-get update \
  && apt-get install -y gh \
  && rm -rf /var/lib/apt/lists/*

# Environment für Bun und pnpm
ENV BUN_INSTALL=/usr/local/bun
ENV PNPM_HOME=/pnpm
ENV PATH="${BUN_INSTALL}/bin:${PNPM_HOME}:${PATH}"

# KRITISCHER FIX: Bun via npm statt curl installieren
# Dies garantiert TypeScript-Verfügbarkeit (tsc)
# ALT: RUN curl -fsSL https://bun.sh/install | bash
RUN npm install -g bun@${BUN_VERSION} typescript pnpm@${PNPM_VERSION} \
  && mkdir -p /pnpm \
  && pnpm config set global-bin-dir /pnpm \
  && pnpm add -g clawdhub

RUN pip3 install --no-cache-dir --break-system-packages homeassistant-cli

# Install gog CLI (Google Workspace: Gmail, Calendar, Drive, Contacts, Sheets, Docs)
# Multi-Arch Support verbessert: amd64, arm64, armv7
RUN ARCH=$(echo ${TARGETARCH:-$(uname -m)} | sed 's/aarch64/arm64/;s/x86_64/amd64/;s/armv7l/armv7/') \
  && curl -fsSL "https://github.com/steipete/gogcli/releases/download/v${GOG_VERSION}/gogcli_${GOG_VERSION}_linux_${ARCH}.tar.gz" \
     | tar xz -C /usr/local/bin gog \
  && chmod +x /usr/local/bin/gog

WORKDIR /opt/clawdbot

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD [ "/run.sh" ]
