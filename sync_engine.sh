#!/usr/bin/env bash
# sync_engine.sh
# Clones (or updates) the anchor-engine-node repository, builds it, and copies
# the resulting static output files (HTML, JS, WASM) into the Flutter assets folder.

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_REPO="https://github.com/RSBalchII/anchor-engine-node.git"
ENGINE_DIR="$SCRIPT_DIR/.engine-cache/anchor-engine-node"
FLUTTER_ASSETS="$SCRIPT_DIR/flutter_app/assets"

# ---------------------------------------------------------------------------
# Step 1: Clone or pull the latest main branch
# ---------------------------------------------------------------------------
echo "==> Syncing anchor-engine-node (main)..."
if [ -d "$ENGINE_DIR/.git" ]; then
    git -C "$ENGINE_DIR" fetch --depth=1 origin main
    git -C "$ENGINE_DIR" checkout main
    git -C "$ENGINE_DIR" reset --hard origin/main
else
    mkdir -p "$(dirname "$ENGINE_DIR")"
    git clone --depth=1 --branch main "$ENGINE_REPO" "$ENGINE_DIR"
fi

# ---------------------------------------------------------------------------
# Step 2: Install dependencies and build
# ---------------------------------------------------------------------------
echo "==> Installing dependencies..."
cd "$ENGINE_DIR"
npm install

echo "==> Building..."
npm run build

# ---------------------------------------------------------------------------
# Step 3: Copy static output files (HTML, JS, WASM) to Flutter assets
# ---------------------------------------------------------------------------
echo "==> Copying static output to $FLUTTER_ASSETS ..."
mkdir -p "$FLUTTER_ASSETS"

# The build output is expected in the 'dist/' directory.
if [ ! -d "$ENGINE_DIR/dist" ]; then
    echo "ERROR: Build did not produce a dist/ directory in $ENGINE_DIR" >&2
    exit 1
fi

# Copy all HTML, JS, and WASM files while preserving relative paths.
find "$ENGINE_DIR/dist" \( -name "*.html" -o -name "*.js" -o -name "*.wasm" \) \
    | while IFS= read -r src; do
        rel="${src#$ENGINE_DIR/dist/}"
        dest="$FLUTTER_ASSETS/$rel"
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
    done

echo "==> Done. Static files written to $FLUTTER_ASSETS"
