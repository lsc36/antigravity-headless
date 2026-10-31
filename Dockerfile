FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG ANTIGRAVITY_VERSION=2.28.2
ARG ANTIGRAVITY_EXECUTION_ID=5937220255875072

LABEL org.opencontainers.image.title="antigravity-headless" \
      org.opencontainers.image.description="Headless Google Antigravity 2.0 web server" \
      org.opencontainers.image.version="${ANTIGRAVITY_VERSION}"

# Install runtime dependencies, agent tools (git, ripgrep, python3), and
# shared libraries required by the bundled Electron/Node runtime (agy-node).
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libexpat1 \
    libgbm1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libx11-6 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    procps \
    python3 \
    ripgrep \
    sudo \
    tar \
    uuid-runtime \
  && rm -rf /var/lib/apt/lists/*

# Download and extract the pinned Antigravity 2.0 release
RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "${ARCH}" in \
      x86_64)  AGY_ARCH="x64" ;; \
      aarch64) AGY_ARCH="arm" ;; \
      *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;; \
    esac; \
    DOWNLOAD_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/${ANTIGRAVITY_VERSION}-${ANTIGRAVITY_EXECUTION_ID}/linux-${AGY_ARCH}/Antigravity.tar.gz"; \
    echo "Downloading Antigravity ${ANTIGRAVITY_VERSION} (${AGY_ARCH}) from ${DOWNLOAD_URL}..."; \
    mkdir -p /opt/antigravity; \
    curl -fsSL "${DOWNLOAD_URL}" | tar -xz --strip-components=1 -C /opt/antigravity; \
    printf '%s\n' "${ANTIGRAVITY_VERSION}" > /opt/antigravity/.resolved_version; \
    chmod 4755 /opt/antigravity/chrome-sandbox || true

COPY entrypoint.sh /usr/local/bin/antigravity-headless
RUN chmod +x /usr/local/bin/antigravity-headless

# Create non-root user with passwordless sudo; /home/antigravity can be bind-mounted to persist all state
RUN useradd -m -u 1000 -s /bin/bash -G sudo antigravity \
  && echo "antigravity ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/antigravity \
  && chmod 0440 /etc/sudoers.d/antigravity

USER antigravity
WORKDIR /home/antigravity
VOLUME ["/home/antigravity"]

ENV HOME=/home/antigravity \
    HTTP_PORT=8080 \
    HTTPS_PORT=8443

EXPOSE 8080 8443

ENTRYPOINT ["/usr/local/bin/antigravity-headless"]
