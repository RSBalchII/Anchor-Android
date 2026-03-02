"""
Anchor Android - FastAPI Backend
Sovereign Memory Server for Android Devices
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
import asyncio
import logging
import os
from pathlib import Path

# Import internal modules
from api.routes import router as api_router
from services.database import DatabaseService
from services.github_sync import GitHubSyncService

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create FastAPI application
app = FastAPI(
    title="Anchor Android Engine",
    description="Sovereign Memory Server for Android Devices",
    version="0.1.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
db_service = DatabaseService()
github_sync = GitHubSyncService()


@app.on_event("startup")
async def startup_event():
    """Initialize database and services on startup"""
    logger.info("Starting Anchor Android Engine...")
    
    # Initialize database
    db_path = os.environ.get("ANCHOR_DB_PATH", "/data/data/org.anchoros.android/files/anchor.db")
    await db_service.initialize(db_path)
    
    # Setup mirrored_brain directory
    storage_path = os.environ.get("ANCHOR_STORAGE_PATH", "/data/data/org.anchoros.android/files/mirrored_brain")
    Path(storage_path).mkdir(parents=True, exist_ok=True)
    Path(f"{storage_path}/github").mkdir(exist_ok=True)
    Path(f"{storage_path}/inbox").mkdir(exist_ok=True)
    
    logger.info(f"Database initialized at: {db_path}")
    logger.info(f"Storage path: {storage_path}")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down Anchor Android Engine...")
    await db_service.close()


# Mount static files (for web UI if needed)
# app.mount("/static", StaticFiles(directory="static"), name="static")


# Include API routes
app.include_router(api_router, prefix="/v1", tags=["API"])


@app.get("/")
async def root():
    """Root endpoint - returns API info"""
    return {
        "name": "Anchor Android Engine",
        "version": "0.1.0",
        "status": "running",
        "endpoints": {
            "health": "/health",
            "stats": "/stats",
            "search": "/v1/memory/search",
            "chat": "/v1/chat/completions"
        }
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        db_status = await db_service.health_check()
        return JSONResponse(
            status_code=200,
            content={
                "status": "healthy",
                "database": db_status,
                "service": "running"
            }
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "error": str(e)
            }
        )


@app.get("/stats")
async def get_stats():
    """Get database and system statistics"""
    try:
        stats = await db_service.get_statistics()
        return JSONResponse(
            status_code=200,
            content={
                "atoms": stats.get("atom_count", 0),
                "molecules": stats.get("molecule_count", 0),
                "sources": stats.get("source_count", 0),
                "tags": stats.get("tag_count", 0),
                "storage_used_mb": stats.get("storage_mb", 0),
                "uptime_seconds": stats.get("uptime", 0)
            }
        )
    except Exception as e:
        logger.error(f"Failed to get stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# Search request model
class SearchRequest(BaseModel):
    query: str = Field(..., description="Search query string")
    token_budget: Optional[int] = Field(2048, description="Maximum tokens to return")
    max_chars: Optional[int] = Field(4096, description="Maximum characters to return")
    provenance: Optional[str] = Field("all", description="Filter by provenance: all, internal, external")
    buckets: Optional[List[str]] = Field(default_factory=list, description="Filter by buckets")
    tags: Optional[List[str]] = Field(default_factory=list, description="Filter by tags")


@app.post("/memory/search")
async def search_memory(request: SearchRequest):
    """Search the knowledge base"""
    try:
        results = await db_service.search(
            query=request.query,
            token_budget=request.token_budget,
            max_chars=request.max_chars,
            provenance=request.provenance,
            buckets=request.buckets,
            tags=request.tags
        )
        
        return JSONResponse(
            status_code=200,
            content={
                "results": results.get("results", []),
                "metadata": results.get("metadata", {}),
                "split_queries": results.get("split_queries", [])
            }
        )
    except Exception as e:
        logger.error(f"Search failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# GitHub Sync request model
class GitHubSyncRequest(BaseModel):
    owner: str = Field(..., description="GitHub repository owner")
    repo: str = Field(..., description="Repository name")
    branch: Optional[str] = Field("main", description="Branch to sync")
    github_token: Optional[str] = Field(None, description="GitHub personal access token")


@app.post("/github/sync")
async def sync_github_repo(request: GitHubSyncRequest, background_tasks: BackgroundTasks):
    """Sync a GitHub repository"""
    try:
        # Add to background tasks to avoid blocking
        background_tasks.add_task(
            github_sync.sync_repository,
            owner=request.owner,
            repo=request.repo,
            branch=request.branch,
            token=request.github_token
        )
        
        return JSONResponse(
            status_code=202,
            content={
                "status": "syncing",
                "message": f"Started syncing {request.owner}/{request.repo}",
                "owner": request.owner,
                "repo": request.repo
            }
        )
    except Exception as e:
        logger.error(f"GitHub sync failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    
    # Run with uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=3160,
        reload=False,
        log_level="info"
    )
