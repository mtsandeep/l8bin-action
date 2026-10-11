#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
SERVER="${L8B_SERVER}"
TOKEN="${L8B_TOKEN}"
PROJECT_ID="${L8B_PROJECT_ID}"
PORT="${L8B_PORT:-3000}"
PATH_DIR="${L8B_PATH:-.}"

# Optional
COMPOSE="${L8B_COMPOSE:-false}"
SERVICES="${L8B_SERVICES:-}"
DOCKERFILE="${L8B_DOCKERFILE:-}"
CMD="${L8B_CMD:-}"
MEMORY="${L8B_MEMORY:-}"
CPU="${L8B_CPU:-}"
NODE_ID="${L8B_NODE_ID:-}"

# --- Validate ---
if [ -z "$SERVER" ]; then echo "::error::server is required"; exit 1; fi
if [ -z "$TOKEN" ]; then echo "::error::token is required"; exit 1; fi
if [ -z "$PROJECT_ID" ]; then echo "::error::project_id is required"; exit 1; fi

case "${COMPOSE,,}" in
  true|1|yes) COMPOSE_MODE=1 ;;
  *) COMPOSE_MODE=0 ;;
esac

# --- Register secrets with GHA log masking ---
echo "::add-mask::${TOKEN}"
echo "::add-mask::${SERVER}"

# --- Install l8b CLI ---
echo "::group::Installing l8b CLI"
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
  ARCH="aarch64"
else
  ARCH="x86_64"
fi
L8B_URL="https://github.com/mtsandeep/l8bin/releases/latest/download/l8b-${ARCH}-linux"
curl -sfL "$L8B_URL" -o /usr/local/bin/l8b
chmod +x /usr/local/bin/l8b
echo "l8b $(l8b --version 2>&1 | head -1) installed"
echo "::endgroup::"

# --- Configure ---
l8b --ci config set --server "${SERVER%/}" --token "$TOKEN"

# --- Deploy ---
echo "::group::Deploying ${PROJECT_ID}"
DEPLOY_ARGS=("--project" "$PROJECT_ID" "--path" "$PATH_DIR")
if [ "$COMPOSE_MODE" = "1" ]; then
  DEPLOY_ARGS+=("--compose")
  if [ -n "$SERVICES" ]; then
    IFS=',' read -ra SVC_ARR <<< "$SERVICES"
    for s in "${SVC_ARR[@]}"; do
      s="${s//" "/}"
      if [ -n "$s" ]; then DEPLOY_ARGS+=("--service" "$s"); fi
    done
  fi
else
  DEPLOY_ARGS+=("--port" "$PORT")
  if [ -n "$DOCKERFILE" ]; then DEPLOY_ARGS+=("--dockerfile" "$DOCKERFILE"); fi
  if [ -n "$CMD" ]; then DEPLOY_ARGS+=("--cmd" "$CMD"); fi
fi
if [ -n "$MEMORY" ]; then DEPLOY_ARGS+=("--memory" "$MEMORY"); fi
if [ -n "$CPU" ]; then DEPLOY_ARGS+=("--cpu" "$CPU"); fi
if [ -n "$NODE_ID" ]; then DEPLOY_ARGS+=("--node" "$NODE_ID"); fi

# JSON mode prints one object on stdout; progress goes to the log via --ci.
DEPLOY_JSON=$(l8b --ci --json deploy "${DEPLOY_ARGS[@]}")
echo "${DEPLOY_JSON}"
echo "::endgroup::"

# --- Surface the deployed URL as the action output (best effort) ---
URL=$(printf '%s\n' "$DEPLOY_JSON" | tail -n1 | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
if [ -n "$URL" ]; then
  echo "url=${URL}" >> "$GITHUB_OUTPUT"
  echo "Deployed: ${URL}"
fi
