#!/usr/bin/env bash
set -euo pipefail

AGY_DIR="${AGY_DIR:-/opt/antigravity}"
LS_BIN="${AGY_DIR}/resources/bin/language_server"
ELECTRON_BIN="${AGY_DIR}/antigravity"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
USER_DATA_DIR="${CONFIG_HOME}/Antigravity"

# Resolve installed Antigravity version dynamically
if [[ -f "${AGY_DIR}/.resolved_version" ]]; then
  IDE_VERSION="$(cat "${AGY_DIR}/.resolved_version")"
elif [[ -f "${AGY_DIR}/version" ]]; then
  IDE_VERSION="$(cat "${AGY_DIR}/version")"
else
  IDE_VERSION="2.28.2"
fi

# Configurable ports via environment variables
HTTPS_PORT="${JETSKI_LS_PORT:-${HTTPS_PORT:-8443}}"
HTTP_PORT="${HTTP_PORT:-8080}"
CSRF_TOKEN="$(cat /proc/sys/kernel/random/uuid)"

# Ensure home state directories exist (supports fresh bind-mounted /home/antigravity)
AGY_BIN_DIR="${USER_DATA_DIR}/bin"
AGY_NODE_WRAPPER="${AGY_BIN_DIR}/agy-node"
mkdir -p "${HOME}/.gemini" "${CONFIG_HOME}/antigravity" "${AGY_BIN_DIR}"

# Set up bundled agy-node wrapper (used by sidecars and MCP servers)
cat <<EOF > "${AGY_NODE_WRAPPER}"
#!/bin/sh
ELECTRON_RUN_AS_NODE=1 exec "${ELECTRON_BIN}" "\$@"
EOF
chmod +x "${AGY_NODE_WRAPPER}"

export PATH="${AGY_BIN_DIR}:${PATH}"
export AGY_BROWSER_ACTIVE_PORT_FILE="${USER_DATA_DIR}/DevToolsActivePort"
export CHROME_DEVTOOLS_MCP_JS="${AGY_DIR}/resources/app.asar.unpacked/node_modules/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js"

echo "============================================================"
echo "  Starting Antigravity ${IDE_VERSION} Headless Web Server"
echo "  HTTP:   http://0.0.0.0:${HTTP_PORT}/"
echo "  HTTPS:  https://0.0.0.0:${HTTPS_PORT}/"
echo "============================================================"

exec "${LS_BIN}" \
  --standalone \
  --headless \
  --remote_accessible \
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
  "$@"
