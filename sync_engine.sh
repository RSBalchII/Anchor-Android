#!/usr/bin/env bash
# sync_engine.sh — Build anchor-engine-node and copy ARM64 binary into Flutter assets
#
# Usage:
#   ./sync_engine.sh [PATH_TO_ANCHOR_ENGINE_NODE]
#
# If no path is given, assumes the engine repo is a sibling directory:
#   ../anchor-engine-node
#
# Prerequisites:
#   - Linux or WSL2 (cross-compiling linux-arm64 from Windows is NOT supported)
#   - Node.js >= 18, pnpm installed
#   - @yao-pkg/pkg is a devDependency — installed automatically by pnpm install
#   - Run from the anchor-android repo root
#
# NOTE: This script MUST be run on Linux or WSL2.
# @yao-pkg/pkg cannot cross-compile linux-arm64 binaries from a Windows host.
# Windows users: open WSL2 and run this script from within WSL.

set -e

# Check we're on Linux (or WSL)
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "[sync_engine] ERROR: This script must run on Linux or WSL2."
    echo "[sync_engine] On Windows: open WSL2 and run ./sync_engine.sh from there."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_REPO="${1:-$SCRIPT_DIR/../anchor-engine-node}"
FLUTTER_ASSETS="$SCRIPT_DIR/flutter_app/assets/engine"

echo "[sync_engine] Engine repo: $ENGINE_REPO"
echo "[sync_engine] Flutter assets target: $FLUTTER_ASSETS"

# 1. Pull or clone latest engine code
echo "[sync_engine] Pulling latest engine..."
if [ -d "$ENGINE_REPO/.git" ]; then
    cd "$ENGINE_REPO"
    git pull origin main
else
    REPO_URL="${ENGINE_REPO_URL:-}"
    if [ -z "$REPO_URL" ]; then
        echo "[sync_engine] ERROR: Engine repo not found at $ENGINE_REPO"
        echo "[sync_engine] Either clone the engine repo as a sibling directory,"
        echo "[sync_engine] or set ENGINE_REPO_URL to a cloneable URL (e.g. with a PAT for CI)."
        exit 1
    fi
    echo "[sync_engine] Engine repo not found — cloning from ENGINE_REPO_URL..."
    git clone "$REPO_URL" "$ENGINE_REPO"
    cd "$ENGINE_REPO"
fi

# 2. Install dependencies
echo "[sync_engine] Installing engine dependencies..."
pnpm install --frozen-lockfile

# 3. Ensure a .env file exists (it is gitignored in the engine repo)
# Create one with placeholder values if it is absent so the build does not fail.
ENGINE_ENV="$ENGINE_REPO/engine/.env"
if [ ! -f "$ENGINE_ENV" ]; then
    echo "[sync_engine] .env not found — creating placeholder at $ENGINE_ENV"
    cat > "$ENGINE_ENV" <<'EOF'
PORT=3160
EOF
    echo "[sync_engine] Placeholder .env written."
fi

# 4. Build TypeScript + pkg linux-arm64 binary
echo "[sync_engine] Building engine (TypeScript + pkg android)..."
cd "$ENGINE_REPO/engine"
pnpm run build:android

BINARY="$ENGINE_REPO/engine/dist-android/anchor-engine"
if [ ! -f "$BINARY" ]; then
    echo "[sync_engine] ERROR: Binary not found at $BINARY"
    exit 1
fi

BINARY_SIZE=$(du -sh "$BINARY" | cut -f1)
echo "[sync_engine] Binary built successfully: $BINARY_SIZE"

# 5. Copy binary to Flutter assets
echo "[sync_engine] Copying binary to Flutter assets..."
mkdir -p "$FLUTTER_ASSETS"
cp "$BINARY" "$FLUTTER_ASSETS/anchor-engine"

echo "[sync_engine] ✅ Done. Binary at: $FLUTTER_ASSETS/anchor-engine ($BINARY_SIZE)"
echo "[sync_engine] Now run: flutter build apk --release"
