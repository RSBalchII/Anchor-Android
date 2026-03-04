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
#   - Node.js >= 18, pnpm installed
#   - @yao-pkg/pkg installed (added to engine devDependencies)
#   - Run from the anchor-android repo root

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_REPO="${1:-$SCRIPT_DIR/../anchor-engine-node}"
FLUTTER_ASSETS="$SCRIPT_DIR/flutter_app/assets/engine"

echo "[sync_engine] Engine repo: $ENGINE_REPO"
echo "[sync_engine] Flutter assets target: $FLUTTER_ASSETS"

# 1. Pull latest engine code
echo "[sync_engine] Pulling latest engine..."
cd "$ENGINE_REPO"
git pull origin main

# 2. Install dependencies
echo "[sync_engine] Installing engine dependencies..."
pnpm install --frozen-lockfile

# 3. Build TypeScript + pkg linux-arm64 binary
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

# 4. Copy binary to Flutter assets
echo "[sync_engine] Copying binary to Flutter assets..."
mkdir -p "$FLUTTER_ASSETS"
cp "$BINARY" "$FLUTTER_ASSETS/anchor-engine"

echo "[sync_engine] ✅ Done. Binary at: $FLUTTER_ASSETS/anchor-engine ($BINARY_SIZE)"
echo "[sync_engine] Now run: flutter build apk --release"
