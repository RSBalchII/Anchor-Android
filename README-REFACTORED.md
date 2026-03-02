# Anchor Android - Refactored (Flutter + FastAPI)

**Sovereign Memory Server for Your Pocket** - Now with Flutter/Dart and FastAPI!

## 🎉 Project Overview

This is a complete refactoring of the Anchor Android app from Kotlin/Java to **Flutter/Dart** for the frontend and **FastAPI (Python)** for the backend, making it cross-platform and easier to maintain.

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│         Android/iOS Device              │
│  ┌───────────────────────────────────┐  │
│  │  Flutter App (Dart)               │  │
│  │  - Native UI                      │  │
│  │  - Background Service             │  │
│  │  - State Management               │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │  FastAPI Backend (Python)         │  │
│  │  - RESTful API                    │  │
│  │  - SQLite Database                │  │
│  │  - GitHub Sync                    │  │
│  │  - Port: localhost:3160           │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │  Tailscale (Encrypted VPN)        │  │
│  │  - Mesh network                   │  │
│  │  - No open ports                  │  │
│  └───────────────────────────────────┘  │
└───────────────────────────────────────────┘
           ▲
           │ HTTP (encrypted)
           │
┌──────────┴──────────────────┐
│  Your Laptop / AI Tools     │
│  - Qwen Code CLI            │
│  - Claude Code              │
│  - VS Code                  │
└─────────────────────────────┘
```

## 📁 Project Structure

```
anchor-android/
├── backend/                    # FastAPI Python Backend
│   ├── main.py                # Application entry point
│   ├── requirements.txt       # Python dependencies
│   ├── api/
│   │   ├── __init__.py
│   │   └── routes.py          # API endpoints
│   ├── services/
│   │   ├── __init__.py
│   │   ├── database.py        # SQLite service
│   │   └── github_sync.py     # GitHub synchronization
│   └── README.md
│
├── flutter_app/               # Flutter/Dart Frontend
│   ├── lib/
│   │   ├── main.dart          # App entry point
│   │   ├── services/
│   │   │   ├── api_service.dart
│   │   │   ├── settings_service.dart
│   │   │   └── background_service.dart
│   │   └── screens/
│   │       ├── home_screen.dart
│   │       ├── search_screen.dart
│   │       ├── settings_screen.dart
│   │       └── repos_screen.dart
│   ├── android/               # Android-specific files
│   ├── ios/                   # iOS-specific files
│   ├── assets/                # Images, icons, etc.
│   └── pubspec.yaml          # Flutter dependencies
│
├── docs/                      # Documentation
│   ├── architecture.md
│   ├── api-reference.md
│   └── deployment-guide.md
│
└── README.md                  # This file
```

## ✨ Features

### Backend (FastAPI)
- ✅ RESTful API compatible with existing clients
- ✅ SQLite database with async support (aiosqlite)
- ✅ Full-text search with token budget management
- ✅ GitHub repository synchronization
- ✅ OpenAI-compatible chat completion endpoint
- ✅ Background task processing
- ✅ CORS support for web clients

### Frontend (Flutter)
- ✅ Cross-platform (Android + iOS from one codebase)
- ✅ Modern Material 3 UI
- ✅ Real-time connection status
- ✅ Search interface with token budget slider
- ✅ Repository management
- ✅ Settings with persistent storage
- ✅ Background service support
- ✅ Provider state management

## 🚀 Quick Start

### Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
venv\Scripts\activate  # Windows
# source venv/bin/activate  # Linux/Mac

# Install dependencies
pip install -r requirements.txt

# Run the server
python main.py
# Or: uvicorn main:app --reload --host 0.0.0.0 --port 3160
```

### Flutter App Setup

```bash
cd flutter_app

# Install Flutter dependencies
flutter pub get

# Run on Android emulator/device
flutter run

# Run on iOS simulator (Mac only)
flutter run -d ios
```

## 📱 Building for Production

### Android APK

```bash
cd flutter_app

# Build release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS App (Mac only)

```bash
cd flutter_app

# Build for iOS
flutter build ios --release
```

## 🔧 Configuration

### Backend Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ANCHOR_DB_PATH` | `/data/data/org.anchoros.android/files/anchor.db` | Database path |
| `ANCHOR_STORAGE_PATH` | `/data/data/org.anchoros.android/files/mirrored_brain` | Storage directory |
| `ANCHOR_LOG_LEVEL` | `INFO` | Logging level |

### Flutter App Settings

Configure in the app's Settings screen:
- **Engine URL**: Backend API endpoint (default: `http://localhost:3160`)
- **GitHub Token**: Personal access token for private repos
- **Auto Sync**: Enable automatic repository synchronization
- **WiFi Only**: Only sync on WiFi connections
- **Sync Interval**: How often to sync (in hours)

## 📊 API Endpoints

### Core Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | API information |
| `/health` | GET | Health check |
| `/stats` | GET | Database statistics |

### Search & Query

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/memory/search` | POST | Search knowledge base |
| `/v1/chat/completions` | POST | Chat with RAG context |

### GitHub Integration

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/github/sync` | POST | Sync GitHub repository |

## 🧪 Testing

### Backend Tests

```bash
cd backend

# Install test dependencies
pip install pytest pytest-asyncio

# Run tests
pytest

# With coverage
pytest --cov=.
```

### Flutter Tests

```bash
cd flutter_app

# Run unit tests
flutter test

# Run with coverage
flutter test --coverage
```

## 📈 Performance Metrics

| Metric | Target | Notes |
|--------|--------|-------|
| App Size | < 50MB | Flutter + Python bundled |
| RAM Usage | < 200MB | Idle state |
| Battery Drain | < 2%/hour | Background service |
| Search Latency | < 500ms | Local database |
| GitHub Sync | < 30s | For typical repos |

## 🔒 Security

- ✅ No open ports (Tailscale only)
- ✅ All traffic encrypted via Tailscale
- ✅ GitHub tokens stored securely (SharedPreferences encrypted)
- ✅ Foreground service (can't be killed silently)
- ✅ No cloud dependency - data stays on device

## 🛣️ Roadmap

### v0.1.0 (Current) - Foundation
- [x] FastAPI backend structure
- [x] Flutter app structure
- [x] Basic API endpoints
- [x] Database service
- [x] GitHub sync service
- [ ] Complete Flutter UI
- [ ] Background service integration
- [ ] Tailscale auto-detection

### v0.2.0 - Feature Complete
- [ ] Full GitHub sync UI
- [ ] Repository list/management
- [ ] Advanced search filters
- [ ] Settings persistence
- [ ] Offline mode
- [ ] Push notifications

### v0.3.0 - Production Ready
- [ ] Performance optimization
- [ ] Battery usage optimization
- [ ] Multi-device sync
- [ ] Plugin ecosystem
- [ ] App Store deployment

### v1.0.0 - Release
- [ ] Stable release
- [ ] Documentation complete
- [ ] User guide
- [ ] Contributing guide
- [ ] Community support

## 🤝 Contributing

Contributions welcome! Please see CONTRIBUTING.md for guidelines.

### Areas We Need Help

1. **iOS Testing**: Need Mac owners to test iOS build
2. **Tailscale Integration**: Implement official Tailscale SDK
3. **UI/UX**: Design improvements and animations
4. **Testing**: Write more unit and integration tests
5. **Documentation**: Improve docs and examples

## 📚 Documentation

- [Architecture](docs/architecture.md) - System design and diagrams
- [API Reference](docs/api-reference.md) - Complete API documentation
- [Deployment Guide](docs/deployment-guide.md) - Build and deploy instructions
- [Contributing](CONTRIBUTING.md) - How to contribute

## 🙏 Acknowledgments

- Original Anchor Engine (Node.js version)
- FastAPI framework by Tiangolo
- Flutter team at Google
- Tailscale team

## 📄 License

AGPL-3.0 - Same license as the original Anchor project

## 📞 Support

- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Discord**: [Invite link coming soon]

---

**Built with ❤️ using Flutter + FastAPI**

Part of Anchor OS - Sovereign Knowledge Engine
