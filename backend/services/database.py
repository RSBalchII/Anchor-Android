"""
Database Service for Anchor Android Engine
Handles PGlite/PostgreSQL operations
"""

import asyncio
import logging
import time
from pathlib import Path
from typing import Optional, List, Dict, Any
from datetime import datetime

logger = logging.getLogger(__name__)


class DatabaseService:
    """
    Database service managing PGlite/PostgreSQL connections
    and providing high-level API for knowledge base operations
    """
    
    def __init__(self):
        self.db_path: Optional[str] = None
        self.connection = None
        self.start_time = time.time()
        self._initialized = False
    
    async def initialize(self, db_path: str) -> None:
        """
        Initialize database connection
        
        Args:
            db_path: Path to SQLite/PostgreSQL database file
        """
        try:
            self.db_path = db_path
            logger.info(f"Initializing database at: {db_path}")
            
            # For Android, we'll use SQLite initially
            # Can be upgraded to PGlite or full PostgreSQL later
            import aiosqlite
            
            self.connection = await aiosqlite.connect(db_path)
            await self._create_tables()
            
            self._initialized = True
            logger.info("Database initialized successfully")
            
        except Exception as e:
            logger.error(f"Database initialization failed: {e}")
            raise
    
    async def _create_tables(self) -> None:
        """Create database tables if they don't exist"""
        if not self.connection:
            raise RuntimeError("Database not initialized")
        
        cursor = self.connection.cursor()
        
        # Atoms table - smallest unit of knowledge
        await cursor.execute("""
            CREATE TABLE IF NOT EXISTS atoms (
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
                created_at INTEGER DEFAULT (strftime('%s', 'now'))
            )
        """)
        
        # Molecules table - collections of related atoms
        await cursor.execute("""
            CREATE TABLE IF NOT EXISTS molecules (
                id TEXT PRIMARY KEY,
                atoms TEXT NOT NULL,  -- JSON array of atom IDs
                content TEXT,
                tags TEXT,            -- JSON array
                created_at INTEGER DEFAULT (strftime('%s', 'now'))
            )
        """)
        
        # Sources table - file/repo metadata
        await cursor.execute("""
            CREATE TABLE IF NOT EXISTS sources (
                id TEXT PRIMARY KEY,
                path TEXT UNIQUE NOT NULL,
                type TEXT,
                metadata TEXT,  -- JSON object
                last_sync INTEGER,
                created_at INTEGER DEFAULT (strftime('%s', 'now'))
            )
        """)
        
        # Tags table - faceted tag system
        await cursor.execute("""
            CREATE TABLE IF NOT EXISTS tags (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL,
                bucket TEXT,
                usage_count INTEGER DEFAULT 0,
                created_at INTEGER DEFAULT (strftime('%s', 'now'))
            )
        """)
        
        # Create indexes for performance
        await cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_atoms_content 
            ON atoms(content)
        """)
        
        await cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_atoms_tags 
            ON atoms(tags)
        """)
        
        await cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_atoms_provenance 
            ON atoms(provenance)
        """)
        
        await self.connection.commit()
        logger.info("Database tables created successfully")
    
    async def health_check(self) -> Dict[str, Any]:
        """Check database health"""
        try:
            if not self.connection:
                return {"status": "disconnected"}
            
            cursor = self.connection.cursor()
            await cursor.execute("SELECT 1")
            await cursor.fetchone()
            
            return {
                "status": "healthy",
                "path": self.db_path,
                "uptime_seconds": int(time.time() - self.start_time)
            }
        except Exception as e:
            return {
                "status": "unhealthy",
                "error": str(e)
            }
    
    async def get_statistics(self) -> Dict[str, Any]:
        """Get database statistics"""
        if not self.connection:
            raise RuntimeError("Database not initialized")
        
        cursor = self.connection.cursor()
        
        # Count atoms
        await cursor.execute("SELECT COUNT(*) FROM atoms")
        atom_count = (await cursor.fetchone())[0]
        
        # Count molecules
        await cursor.execute("SELECT COUNT(*) FROM molecules")
        molecule_count = (await cursor.fetchone())[0]
        
        # Count sources
        await cursor.execute("SELECT COUNT(*) FROM sources")
        source_count = (await cursor.fetchone())[0]
        
        # Count tags
        await cursor.execute("SELECT COUNT(*) FROM tags")
        tag_count = (await cursor.fetchone())[0]
        
        # Get storage size (approximate)
        storage_mb = 0
        if self.db_path and Path(self.db_path).exists():
            storage_mb = round(Path(self.db_path).stat().st_size / (1024 * 1024), 2)
        
        return {
            "atom_count": atom_count,
            "molecule_count": molecule_count,
            "source_count": source_count,
            "tag_count": tag_count,
            "storage_mb": storage_mb,
            "uptime": int(time.time() - self.start_time)
        }
    
    async def search(
        self,
        query: str,
        token_budget: int = 2048,
        max_chars: int = 4096,
        provenance: str = "all",
        buckets: Optional[List[str]] = None,
        tags: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        """
        Search the knowledge base
        
        Args:
            query: Search query string
            token_budget: Maximum tokens to return
            max_chars: Maximum characters to return
            provenance: Filter by provenance (all, internal, external)
            buckets: Filter by buckets
            tags: Filter by tags
            
        Returns:
            Dictionary with results and metadata
        """
        if not self.connection:
            raise RuntimeError("Database not initialized")
        
        start_time = time.time()
        cursor = self.connection.cursor()
        
        # Build query
        base_query = """
            SELECT id, content, source_path, timestamp, 
                   buckets, tags, provenance, simhash,
                   start_byte, end_byte
            FROM atoms
            WHERE 1=1
        """
        
        params = []
        
        # Add provenance filter
        if provenance != "all":
            base_query += " AND provenance = ?"
            params.append(provenance)
        
        # Add full-text search
        base_query += " AND content LIKE ?"
        params.append(f"%{query}%")
        
        # Order by relevance (timestamp for now, can be improved with scoring)
        base_query += " ORDER BY timestamp DESC"
        
        # Limit results
        base_query += " LIMIT 100"
        
        # Execute query
        await cursor.execute(base_query, params)
        rows = await cursor.fetchall()
        
        # Process results
        results = []
        total_chars = 0
        
        for row in rows:
            if total_chars >= max_chars:
                break
            
            import json
            result = {
                "id": row[0],
                "content": row[1],
                "source": row[2],
                "timestamp": row[3],
                "buckets": json.loads(row[4]) if row[4] else [],
                "tags": json.loads(row[5]) if row[5] else [],
                "provenance": row[6],
                "molecular_signature": row[7],
                "start_byte": row[8],
                "end_byte": row[9],
                "score": 1.0  # Placeholder score
            }
            
            results.append(result)
            total_chars += len(row[1]) if row[1] else 0
        
        # Calculate metadata
        duration_ms = int((time.time() - start_time) * 1000)
        
        return {
            "results": results,
            "metadata": {
                "duration_ms": duration_ms,
                "atoms_searched": len(rows),
                "atoms_returned": len(results),
                "token_count": total_chars // 4,  # Approximate tokens
                "filled_percent": round((total_chars / max_chars) * 100, 2)
            },
            "split_queries": []  # Could implement query splitting here
        }
    
    async def add_atom(self, atom_data: Dict[str, Any]) -> str:
        """Add a new atom to the database"""
        if not self.connection:
            raise RuntimeError("Database not initialized")
        
        import json
        
        cursor = self.connection.cursor()
        
        await cursor.execute("""
            INSERT INTO atoms (
                id, content, source_path, timestamp,
                buckets, tags, epochs, provenance,
                simhash, molecular_signature, start_byte, end_byte
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            atom_data.get("id"),
            atom_data.get("content"),
            atom_data.get("source_path"),
            atom_data.get("timestamp"),
            json.dumps(atom_data.get("buckets", [])),
            json.dumps(atom_data.get("tags", [])),
            json.dumps(atom_data.get("epochs", [])),
            atom_data.get("provenance", "external"),
            atom_data.get("simhash"),
            atom_data.get("molecular_signature"),
            atom_data.get("start_byte"),
            atom_data.get("end_byte")
        ))
        
        await self.connection.commit()
        return atom_data.get("id", "unknown")
    
    async def close(self) -> None:
        """Close database connection"""
        if self.connection:
            await self.connection.close()
            logger.info("Database connection closed")
