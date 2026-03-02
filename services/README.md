# Anchor Engine Node.js Integration

This directory contains the anchor-engine-node runtime for Android.

## Setup Instructions

### 1. Copy Engine Code

```bash
# From anchor-android directory
cd services
git clone https://github.com/RSBalchII/anchor-engine-node.git engine-source
cd engine-source
pnpm install
pnpm run build
```

### 2. For Android Deployment

The engine will be bundled in the APK's assets and extracted at runtime.

```bash
# Copy built engine to assets
cp -r engine-source/dist flutter_app/android/app/src/main/assets/engine/
cp -r engine-source/node_modules flutter_app/android/app/src/main/assets/engine/node_modules/
```

### 3. Runtime Execution

The engine runs as a separate Node.js process via nodejs-mobile or as a standalone binary.

## Architecture

```
Flutter App (Dart)
    ↓
Background Service
    ↓
Node.js Runtime (nodejs-mobile)
    ↓
Anchor Engine (port 3160)
    ↓
PGlite Database
```

## Memory Management

- **Max RAM Usage**: 1.7GB (configurable)
- **GC**: `--expose-gc` flag enabled
- **Process**: Runs independently from Flutter UI

## API Endpoints

The engine exposes these endpoints on localhost:3160:

- `GET /health` - Health check
- `GET /stats` - Database statistics
- `POST /v1/memory/search` - Search with context expansion
- `POST /v1/chat/completions` - Chat with RAG
- `GET /v1/system/paths` - Path management

## Integration Points

1. **Engine Process Manager**: Starts/stops the Node.js process
2. **API Service**: HTTP client for engine endpoints
3. **Background Service**: Keeps engine running in background
4. **Storage Manager**: Manages mirrored_brain/ directory
