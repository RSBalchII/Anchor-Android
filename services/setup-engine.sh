#!/bin/bash

# Anchor Engine Node.js Setup Script for Android
# This script prepares the anchor-engine-node for bundling with the Flutter app

set -e

echo "🔧 Setting up anchor-engine-node for Android..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SERVICES_DIR="$SCRIPT_DIR/../services"
ENGINE_DIR="$SERVICES_DIR/engine-source"
FLUTTER_ASSETS="$SCRIPT_DIR/../flutter_app/android/app/src/main/assets"

echo -e "${YELLOW}Step 1: Creating services directory...${NC}"
mkdir -p "$SERVICES_DIR"
mkdir -p "$FLUTTER_ASSETS/engine"

echo -e "${YELLOW}Step 2: Cloning anchor-engine-node repository...${NC}"
if [ -d "$ENGINE_DIR" ]; then
    echo "Engine source already exists. Pulling latest changes..."
    cd "$ENGINE_DIR"
    git pull
else
    git clone https://github.com/RSBalchII/anchor-engine-node.git "$ENGINE_DIR"
fi

echo -e "${YELLOW}Step 3: Installing dependencies...${NC}"
cd "$ENGINE_DIR"

# Check if pnpm is installed
if ! command -v pnpm &> /dev/null; then
    echo -e "${RED}pnpm is not installed. Installing globally...${NC}"
    npm install -g pnpm
fi

# Install dependencies
pnpm install

echo -e "${YELLOW}Step 4: Building engine...${NC}"
pnpm run build

echo -e "${YELLOW}Step 5: Preparing for Android bundling...${NC}"

# Create a clean copy for bundling
BUNDLE_DIR="$SERVICES_DIR/engine-bundle"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# Copy only necessary files
cp -r "$ENGINE_DIR/dist" "$BUNDLE_DIR/"
cp -r "$ENGINE_DIR/node_modules" "$BUNDLE_DIR/"
cp "$ENGINE_DIR/package.json" "$BUNDLE_DIR/"
cp "$ENGINE_DIR/user_settings.json" "$BUNDLE_DIR/" 2>/dev/null || echo "No user_settings.json found"

# Create optimized bundle
echo -e "${YELLOW}Step 6: Creating optimized bundle...${NC}"
cd "$SERVICES_DIR"
tar -czf engine-bundle.tar.gz engine-bundle/

echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Engine bundle created at: $SERVICES_DIR/engine-bundle.tar.gz"
echo ""
echo "To bundle with Flutter app:"
echo "  1. Extract the bundle to: flutter_app/android/app/src/main/assets/engine/"
echo "  2. Or use the tarball directly in your build process"
echo ""
echo "Next steps:"
echo "  - Update pubspec.yaml to include native assets"
echo "  - Configure Android Gradle to bundle Node.js runtime"
echo "  - Test engine startup on Android device"
