"""
GitHub Sync Service for Anchor Android Engine
Handles repository synchronization and tarball ingestion
"""

import asyncio
import logging
import os
import tarfile
import io
import hashlib
from pathlib import Path
from typing import Optional, Dict, Any, List
from datetime import datetime

import httpx

logger = logging.getLogger(__name__)


class GitHubSyncService:
    """
    Service for syncing GitHub repositories
    Downloads tarballs, unpacks them, and triggers ingestion
    """
    
    def __init__(self):
        self.base_url = "https://api.github.com"
        self.storage_path = os.environ.get(
            "ANCHOR_STORAGE_PATH",
            "/data/data/org.anchoros.android/files/mirrored_brain"
        )
        self.github_dir = Path(f"{self.storage_path}/github")
        self.github_dir.mkdir(parents=True, exist_ok=True)
    
    async def sync_repository(
        self,
        owner: str,
        repo: str,
        branch: str = "main",
        token: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Sync a GitHub repository
        
        Args:
            owner: Repository owner (username or org)
            repo: Repository name
            branch: Branch to sync (default: main)
            token: GitHub personal access token (optional)
            
        Returns:
            Sync result metadata
        """
        try:
            logger.info(f"Starting sync for {owner}/{repo} (branch: {branch})")
            
            # Build headers
            headers = {
                "Accept": "application/vnd.github.v3+json",
                "User-Agent": f"Anchor-Android/{owner}/{repo}"
            }
            
            if token:
                headers["Authorization"] = f"token {token}"
            
            # Get repository info
            repo_info = await self._fetch_repo_info(owner, repo, headers)
            
            # Get latest commit SHA
            commit_sha = await self._get_latest_commit(owner, repo, branch, headers)
            
            # Create destination directory
            dest_dir = self.github_dir / f"{owner}-{repo}-{commit_sha[:8]}"
            
            # Check if already synced
            if dest_dir.exists():
                logger.info(f"Repository already synced at {dest_dir}")
                return {
                    "status": "already_synced",
                    "path": str(dest_dir),
                    "commit": commit_sha
                }
            
            # Download tarball
            tarball_url = f"{self.base_url}/repos/{owner}/{repo}/tarball/{branch}"
            tarball_data = await self._download_tarball(tarball_url, headers)
            
            # Unpack tarball
            await self._unpack_tarball(tarball_data, dest_dir)
            
            logger.info(f"Successfully synced {owner}/{repo} to {dest_dir}")
            
            return {
                "status": "success",
                "path": str(dest_dir),
                "commit": commit_sha,
                "files_extracted": self._count_files(dest_dir),
                "repo_info": repo_info
            }
            
        except Exception as e:
            logger.error(f"GitHub sync failed: {e}")
            raise
    
    async def _fetch_repo_info(
        self,
        owner: str,
        repo: str,
        headers: Dict[str, str]
    ) -> Dict[str, Any]:
        """Fetch repository metadata from GitHub"""
        url = f"{self.base_url}/repos/{owner}/{repo}"
        
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers, timeout=30.0)
            response.raise_for_status()
            return response.json()
    
    async def _get_latest_commit(
        self,
        owner: str,
        repo: str,
        branch: str,
        headers: Dict[str, str]
    ) -> str:
        """Get latest commit SHA for a branch"""
        url = f"{self.base_url}/repos/{owner}/{repo}/commits/{branch}"
        
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers, timeout=30.0)
            response.raise_for_status()
            data = response.json()
            return data.get("sha", "unknown")
    
    async def _download_tarball(
        self,
        url: str,
        headers: Dict[str, str]
    ) -> bytes:
        """Download repository tarball"""
        logger.info(f"Downloading tarball from {url}")
        
        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=headers, timeout=120.0)
            response.raise_for_status()
            return response.content
    
    async def _unpack_tarball(
        self,
        tarball_data: bytes,
        dest_dir: Path
    ) -> None:
        """Unpack tarball to destination directory"""
        logger.info(f"Unpacking tarball to {dest_dir}")
        
        # Create destination directory
        dest_dir.mkdir(parents=True, exist_ok=True)
        
        # Extract tarball
        with tarfile.open(fileobj=io.BytesIO(tarball_data), mode='r:gz') as tar:
            # Get the root directory name from tarball
            members = tar.getmembers()
            if not members:
                raise ValueError("Empty tarball")
            
            root_dir = members[0].name.split('/')[0]
            
            # Extract all members, removing the root directory prefix
            for member in members:
                # Skip the root directory itself
                if member.name == root_dir:
                    continue
                
                # Remove the root directory prefix
                member.name = member.name[len(root_dir) + 1:]
                
                # Extract the file
                if member.isfile():
                    file_obj = tar.extractfile(member)
                    if file_obj:
                        # Create parent directories
                        target_path = dest_dir / member.name
                        target_path.parent.mkdir(parents=True, exist_ok=True)
                        
                        # Write the file
                        with open(target_path, 'wb') as f:
                            f.write(file_obj.read())
    
    def _count_files(self, directory: Path) -> int:
        """Count number of files in directory"""
        count = 0
        for item in directory.rglob('*'):
            if item.is_file():
                count += 1
        return count
    
    async def list_synced_repos(self) -> List[Dict[str, Any]]:
        """List all synced repositories"""
        repos = []
        
        for repo_dir in self.github_dir.iterdir():
            if repo_dir.is_dir():
                # Parse directory name: owner-repo-commit
                parts = repo_dir.name.rsplit('-', 2)
                if len(parts) >= 3:
                    owner = parts[0]
                    repo = parts[1]
                    commit = parts[2]
                    
                    repos.append({
                        "owner": owner,
                        "repo": repo,
                        "commit": commit,
                        "path": str(repo_dir),
                        "files": self._count_files(repo_dir),
                        "synced_at": datetime.fromtimestamp(
                            repo_dir.stat().st_mtime
                        ).isoformat()
                    })
        
        return repos
    
    async def remove_repo(self, owner: str, repo: str) -> bool:
        """Remove a synced repository"""
        # Find matching directory
        for repo_dir in self.github_dir.iterdir():
            if repo_dir.name.startswith(f"{owner}-{repo}-"):
                # Remove directory
                import shutil
                shutil.rmtree(repo_dir)
                logger.info(f"Removed synced repo: {repo_dir}")
                return True
        
        logger.warning(f"Repo not found: {owner}/{repo}")
        return False
