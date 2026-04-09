#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
SERVER="${L8B_SERVER}"
TOKEN="${L8B_TOKEN}"
PROJECT_ID="${L8B_PROJECT_ID}"
PORT="${L8B_PORT:-3000}"
DOCKERFILE="${L8B_DOCKERFILE:-}"
CMD="${L8B_CMD:-}"
MEMORY="${L8B_MEMORY:-}"
CPU="${L8B_CPU:-}"
NODE_ID="${L8B_NODE_ID:-}"
PATH_DIR="${L8B_PATH:-.}"

IMAGE_TAG="l8b/${PROJECT_ID}:latest"
TAR_PATH="/tmp/l8b-${PROJECT_ID}.tar"

# --- Validate required inputs ---
if [ -z "$SERVER" ]; then
  echo "::error::server is required"
  exit 1
fi
if [ -z "$TOKEN" ]; then
  echo "::error::token is required"
  exit 1
fi
if [ -z "$PROJECT_ID" ]; then
  echo "::error::project_id is required"
  exit 1
fi

SERVER="${SERVER%/}"

# --- Step 1: Build image ---
if [ -n "$DOCKERFILE" ]; then
  echo "::group::Building with Docker"
  docker build -f "$DOCKERFILE" -t "$IMAGE_TAG" "$PATH_DIR"
elif [ -f Dockerfile ]; then
  echo "::group::Building with Docker"
  docker build -t "$IMAGE_TAG" "$PATH_DIR"
else
  echo "::group::No Dockerfile found — installing Railpack"
  curl -sSL https://railpack.io/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
  echo "::endgroup::"

  echo "::group::Building with Railpack"
  railpack build -t "$IMAGE_TAG" "$PATH_DIR"
fi
echo "::endgroup::"

# --- Step 2: Save image as tar ---
echo "::group::Saving image"
docker save -o "$TAR_PATH" "$IMAGE_TAG"
echo "Image saved ($(du -h "$TAR_PATH" | cut -f1))"
echo "::endgroup::"

# --- Step 3: Upload image ---
echo "::group::Uploading image to LiteBin"
UPLOAD_URL="${SERVER}/images/upload?project_id=${PROJECT_ID}"
if [ -n "$NODE_ID" ]; then
  UPLOAD_URL="${UPLOAD_URL}&node_id=${NODE_ID}"
fi

UPLOAD_RESP=$(curl -sf -X POST "$UPLOAD_URL" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/x-tar" \
  --data-binary "@${TAR_PATH}")

IMAGE_ID=$(echo "$UPLOAD_RESP" | jq -r '.image_id')

if [ -z "$IMAGE_ID" ] || [ "$IMAGE_ID" = "null" ]; then
  echo "::error::Upload failed — no image_id in response: ${UPLOAD_RESP}"
  exit 1
fi

echo "Image uploaded (id: ${IMAGE_ID})"
echo "::endgroup::"

# --- Step 4: Deploy ---
echo "::group::Deploying"
DEPLOY_BODY=$(jq -n \
  --arg project_id "$PROJECT_ID" \
  --arg image "$IMAGE_ID" \
  --argjson port "$PORT" \
  '{project_id: $project_id, image: $image, port: $port, auto_stop_enabled: true}')

if [ -n "$CMD" ]; then
  DEPLOY_BODY=$(echo "$DEPLOY_BODY" | jq --arg cmd "$CMD" '. + {cmd: $cmd}')
fi
if [ -n "$MEMORY" ]; then
  DEPLOY_BODY=$(echo "$DEPLOY_BODY" | jq --argjson memory "$MEMORY" '. + {memory_limit_mb: $memory}')
fi
if [ -n "$CPU" ]; then
  DEPLOY_BODY=$(echo "$DEPLOY_BODY" | jq --argjson cpu "$CPU" '. + {cpu_limit: $cpu}')
fi
if [ -n "$NODE_ID" ]; then
  DEPLOY_BODY=$(echo "$DEPLOY_BODY" | jq --arg node_id "$NODE_ID" '. + {node_id: $node_id}')
fi

DEPLOY_RESP=$(curl -sf -X POST "${SERVER}/deploy" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$DEPLOY_BODY")

DEPLOY_URL=$(echo "$DEPLOY_RESP" | jq -r '.url')

if [ -z "$DEPLOY_URL" ] || [ "$DEPLOY_URL" = "null" ]; then
  echo "::error::Deploy failed — no url in response: ${DEPLOY_RESP}"
  exit 1
fi
echo "::endgroup::"

# --- Step 5: Output ---
echo "Deployed! ${DEPLOY_URL}"
echo "url=${DEPLOY_URL}" >> "$GITHUB_OUTPUT"

# --- Cleanup ---
rm -f "$TAR_PATH"
