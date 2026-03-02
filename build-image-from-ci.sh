#!/bin/bash
# Build Shopizer Docker image using a pre-built artifact from GitHub Actions CI
#
# Usage:
#   ./build-image-from-ci.sh [OPTIONS] <github-owner> <github-repo> [branch] [image-tag]
#
# Arguments:
#   <github-owner>   GitHub username or organization (required)
#   <github-repo>    Repository name (required)
#   [branch]         Branch name (default: main)
#   [image-tag]      Docker image tag (default: shopizer:ci-latest)
#
# Options:
#   --help, -h       Show this help message
#
# Examples:
#   ./build-image-from-ci.sh kumarsaroj18 shopizer
#   ./build-image-from-ci.sh kumarsaroj18 shopizer main shopizer:3.2.5
#   ./build-image-from-ci.sh kumarsaroj18 shopizer develop shopizer:dev-latest
#
# Prerequisites:
#   - gh (GitHub CLI) authenticated
#   - docker
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

usage() {
  sed -n '/^# Usage/,/^# ====/p' "$0" | grep -v '^# ====' | sed 's/^# //'
  exit 0
}

# Parse --help flag
for arg in "$@"; do
  if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
    usage
  fi
done

GITHUB_OWNER="${1:-}"
GITHUB_REPO="${2:-}"
GITHUB_BRANCH="${3:-main}"
IMAGE_TAG="${4:-shopizer:ci-latest}"
DOWNLOAD_DIR=".ci-download"
ARTIFACT_ZIP="${DOWNLOAD_DIR}/artifact.zip"
ARTIFACT_CACHE_FILE="${DOWNLOAD_DIR}/.last-artifact-id"

# ─────────────────────────────────────────────────────────────
# Validation
# ─────────────────────────────────────────────────────────────
if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ]; then
    echo "❌ GitHub owner and repo are required"
    echo ""
    usage
fi

command -v gh >/dev/null || { echo "❌ gh CLI not installed"; exit 1; }
command -v docker >/dev/null || { echo "❌ Docker not installed"; exit 1; }

gh auth status >/dev/null 2>&1 || {
    echo "❌ Not authenticated. Run: gh auth login"
    exit 1
}

echo "📦 Building Docker image from CI artifact"
echo "  Owner  : $GITHUB_OWNER"
echo "  Repo   : $GITHUB_REPO"
echo "  Branch : $GITHUB_BRANCH"
echo "  Tag    : $IMAGE_TAG"
echo ""

cd "$(dirname "$0")" || exit 1

# ─────────────────────────────────────────────────────────────
# Step 1 — Find latest successful CI run
# ─────────────────────────────────────────────────────────────
echo "🔍 Resolving latest successful CI run..."

LATEST_RUN=$(gh run list \
    --repo="${GITHUB_OWNER}/${GITHUB_REPO}" \
    --branch="${GITHUB_BRANCH}" \
    --status=success \
    --limit=1 \
    --json databaseId \
    --jq '.[0].databaseId')

if [ -z "$LATEST_RUN" ] || [ "$LATEST_RUN" = "null" ]; then
    echo "❌ No successful CI run found"
    exit 1
fi

echo "   Run ID: $LATEST_RUN"

# ─────────────────────────────────────────────────────────────
# Step 2 — Resolve Artifact ID
# ─────────────────────────────────────────────────────────────
echo "🔍 Resolving artifact ID..."

ARTIFACT_ID=$(gh api \
  "repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/runs/${LATEST_RUN}/artifacts" \
  --jq '.artifacts[] | select(.name | startswith("shopizer-")) | .id' \
  | head -1)

if [ -z "$ARTIFACT_ID" ]; then
    echo "❌ No artifact starting with 'shopizer-' found"
    exit 1
fi

echo "   Artifact ID: $ARTIFACT_ID"

# ─────────────────────────────────────────────────────────────
# Step 3 — Download Artifact (skip if already cached)
# ─────────────────────────────────────────────────────────────
echo ""

CACHED_ID=""
if [ -f "$ARTIFACT_CACHE_FILE" ]; then
    CACHED_ID=$(cat "$ARTIFACT_CACHE_FILE")
fi

if [ "$CACHED_ID" = "$ARTIFACT_ID" ] && [ -f "${DOWNLOAD_DIR}/shopizer.jar" ]; then
    echo "✅ Artifact ${ARTIFACT_ID} already downloaded — skipping download."
else
    echo "⬇️  Downloading artifact (id: ${ARTIFACT_ID})..."

    # Preserve any previously cached artifact — clean only the zip + jar
    mkdir -p "$DOWNLOAD_DIR"
    rm -f "$ARTIFACT_ZIP" "${DOWNLOAD_DIR}/shopizer.jar"

    # 1️⃣ Get archive download URL from artifact metadata
    ARCHIVE_URL=$(gh api \
      "repos/${GITHUB_OWNER}/${GITHUB_REPO}/actions/artifacts/${ARTIFACT_ID}" \
      --jq '.archive_download_url')

    if [ -z "$ARCHIVE_URL" ]; then
        echo "❌ Failed to resolve archive_download_url"
        exit 1
    fi

    echo "   Download URL resolved"

    # 2️⃣ Get token for authenticated curl
    GH_TOKEN=$(gh auth token)

    # 3️⃣ Download using curl with progress bar
    curl -L \
      -H "Authorization: Bearer ${GH_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      --progress-bar \
      "$ARCHIVE_URL" \
      -o "$ARTIFACT_ZIP"

    echo ""
    echo "📦 Extracting artifact..."
    unzip -q "$ARTIFACT_ZIP" -d "$DOWNLOAD_DIR"
    rm -f "$ARTIFACT_ZIP"

    # Locate the JAR (may be named after the artifact) and normalise to shopizer.jar
    JAR_PATH=$(find "$DOWNLOAD_DIR" -name "*.jar" -type f | head -1)
    if [ -z "$JAR_PATH" ]; then
        echo "❌ No JAR found in downloaded artifact"
        rm -rf "$DOWNLOAD_DIR"
        exit 1
    fi
    if [ "$JAR_PATH" != "${DOWNLOAD_DIR}/shopizer.jar" ]; then
        mv "$JAR_PATH" "${DOWNLOAD_DIR}/shopizer.jar"
    fi

    # Save artifact ID to cache so future runs can skip the download
    echo "$ARTIFACT_ID" > "$ARTIFACT_CACHE_FILE"
fi

echo "   JAR ready at: ${DOWNLOAD_DIR}/shopizer.jar"

# ─────────────────────────────────────────────────────────────
# Step 4 — Build Docker Image
# ─────────────────────────────────────────────────────────────
echo ""
echo "🐳 Building Docker image '$IMAGE_TAG'..."

docker build -f Dockerfile.ci -t "$IMAGE_TAG" .

echo ""
echo "🧹 Cleaning up..."
# Remove the JAR (large) but keep the cache file so the next run can skip the download
rm -f "${DOWNLOAD_DIR}/shopizer.jar"

echo ""
echo "✅ Docker image built successfully: $IMAGE_TAG"
echo ""
echo "Run with:"
echo "  docker run -p 8080:8080 $IMAGE_TAG"