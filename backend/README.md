# Anchor Android Backend - FastAPI

FastAPI-based backend for the Anchor Android sovereign memory server.

## Features

- ✅ RESTful API compatible with existing Anchor clients
- ✅ SQLite database with async support
- ✅ GitHub repository synchronization
- ✅ Full-text search with token budget management
- ✅ OpenAI-compatible chat completion endpoint
- ✅ Background task processing

## Installation

### Prerequisites

- Python 3.11+
- pip

### Setup

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## Running the Server

### Development

```bash
# With auto-reload
uvicorn main:app --reload --host 0.0.0.0 --port 3160

# Or using Python
python main.py
```

### Production

```bash
# With multiple workers
uvicorn main:app --host 0.0.0.0 --port 3160 --workers 4
```

## API Endpoints

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

### System Management

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/system/paths` | GET | Get watched paths |
| `/v1/system/paths` | POST | Add watched path |
| `/v1/system/paths` | DELETE | Remove watched path |

### GitHub Integration

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/github/sync` | POST | Sync GitHub repository |

## Usage Examples

### Health Check

```bash
curl http://localhost:3160/health
```

Response:
```json
{
  "status": "healthy",
  "database": {
    "status": "healthy",
    "path": "/path/to/anchor.db",
    "uptime_seconds": 1234
  },
  "service": "running"
}
```

### Search Knowledge Base

```bash
curl -X POST http://localhost:3160/v1/memory/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "tokenization logic",
    "token_budget": 2048,
    "max_chars": 4096
  }'
```

### Sync GitHub Repository

```bash
curl -X POST http://localhost:3160/github/sync \
  -H "Content-Type: application/json" \
  -d '{
    "owner": "qwen-code",
    "repo": "qwen-cli",
    "branch": "main",
    "github_token": "your_github_token"
  }'
```

## Project Structure

```
backend/
├── main.py                 # FastAPI application entry point
├── requirements.txt        # Python dependencies
├── api/
│   ├── __init__.py
│   └── routes.py          # API route definitions
├── services/
│   ├── __init__.py
│   ├── database.py        # Database service (SQLite/PGlite)
│   └── github_sync.py     # GitHub synchronization service
└── tests/
    ├── __init__.py
    ├── test_api.py
    └── test_services.py
```

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `ANCHOR_DB_PATH` | `/data/data/org.anchoros.android/files/anchor.db` | Database file path |
| `ANCHOR_STORAGE_PATH` | `/data/data/org.anchoros.android/files/mirrored_brain` | Storage directory |
| `ANCHOR_LOG_LEVEL` | `INFO` | Logging level |

## Database Schema

### Atoms Table

Smallest unit of knowledge (code snippets, text chunks).

```sql
CREATE TABLE atoms (
    id TEXT PRIMARY KEY,
    content TEXT NOT NULL,
    source_path TEXT,
    timestamp INTEGER,
    buckets TEXT,  -- JSON array
    tags TEXT,     -- JSON array
    epochs TEXT,   -- JSON array
    provenance TEXT,
    simhash TEXT,
    molecular_signature TEXT,
    start_byte INTEGER,
    end_byte INTEGER,
    created_at INTEGER
)
```

### Molecules Table

Collections of related atoms.

```sql
CREATE TABLE molecules (
    id TEXT PRIMARY KEY,
    atoms TEXT NOT NULL,  -- JSON array of atom IDs
    content TEXT,
    tags TEXT,
    created_at INTEGER
)
```

### Sources Table

File and repository metadata.

```sql
CREATE TABLE sources (
    id TEXT PRIMARY KEY,
    path TEXT UNIQUE NOT NULL,
    type TEXT,
    metadata TEXT,
    last_sync INTEGER,
    created_at INTEGER
)
```

## Testing

```bash
# Run tests
pytest

# With coverage
pytest --cov=.

# Run specific test file
pytest tests/test_api.py
```

## Android Integration

For Android deployment, this backend runs via Chaquopy (Python in Android) or as a standalone service.

See `../flutter_app/` for the Flutter frontend integration.

## License

AGPL-3.0

## Contributing

Contributions welcome! Please read CONTRIBUTING.md first.
