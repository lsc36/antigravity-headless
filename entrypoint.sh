#!/usr/bin/env bash
set -euo pipefail

AGY_DIR="${AGY_DIR:-/opt/antigravity}"
LS_BIN="${AGY_DIR}/resources/bin/language_server"
ELECTRON_BIN="${AGY_DIR}/antigravity"
USER_DATA_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/Antigravity"

# Resolve installed Antigravity version dynamically
if [[ -f "${AGY_DIR}/.resolved_version" ]]; then
  IDE_VERSION="$(cat "${AGY_DIR}/.resolved_version")"
elif [[ -f "${AGY_DIR}/version" ]]; then
  IDE_VERSION="$(cat "${AGY_DIR}/version")"
else
  IDE_VERSION="2.28.2"
fi

# Configurable ports & settings via environment variables
HTTPS_PORT="${JETSKI_LS_PORT:-${HTTPS_PORT:-8443}}"
HTTP_PORT="${HTTP_PORT:-8080}"
CSRF_TOKEN="${CSRF_TOKEN:-$(cat /proc/sys/kernel/random/uuid)}"
REMOTE_ACCESSIBLE="${REMOTE_ACCESSIBLE:-1}"

# Set up bundled agy-node wrapper (used by sidecars and MCP servers)
AGY_BIN_DIR="${USER_DATA_DIR}/bin"
AGY_NODE_WRAPPER="${AGY_BIN_DIR}/agy-node"
mkdir -p "${AGY_BIN_DIR}"
cat <<EOF > "${AGY_NODE_WRAPPER}"
#!/bin/sh
ELECTRON_RUN_AS_NODE=1 exec "${ELECTRON_BIN}" "\$@"
EOF
chmod +x "${AGY_NODE_WRAPPER}"

export PATH="${AGY_BIN_DIR}:${PATH}"
export AGY_BROWSER_ACTIVE_PORT_FILE="${USER_DATA_DIR}/DevToolsActivePort"
export CHROME_DEVTOOLS_MCP_JS="${AGY_DIR}/resources/app.asar.unpacked/node_modules/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js"

EXTRA_ARGS=()
if [[ "${REMOTE_ACCESSIBLE}" == "1" || "${REMOTE_ACCESSIBLE}" == "true" ]]; then
  EXTRA_ARGS+=(--remote_accessible)
  LISTEN_HOST="0.0.0.0"
else
  LISTEN_HOST="127.0.0.1"
fi

echo "============================================================"
echo "  Starting Antigravity ${IDE_VERSION} Headless Web Server"
echo "  HTTP:   http://${LISTEN_HOST}:${HTTP_PORT}/"
echo "  HTTPS:  https://${LISTEN_HOST}:${HTTPS_PORT}/"
echo "============================================================"

exec "${LS_BIN}" \
  --standalone \
  --headless \
  --override_ide_name=antigravity \
  --subclient_type=hub \
  --override_ide_version="${IDE_VERSION}" \
  --override_user_agent_name=antigravity \
  --app_data_dir=antigravity \
  --api_server_url=https://generativelanguage.googleapis.com \
  --cloud_code_endpoint=https://daily-cloudcode-pa.googleapis.com \
  --enable_sidecars \
  --csrf_token="${CSRF_TOKEN}" \
  --http_server_port="${HTTP_PORT}" \
  --https_server_port="${HTTPS_PORT}" \
  "${EXTRA_ARGS[@]}" \
  "$@"
