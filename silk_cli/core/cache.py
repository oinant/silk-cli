"""
Cache system for SILK projects with composite MD5 hashing.

Handles multi-part chapter caching by combining individual file hashes
into a composite hash for efficient change detection.
"""

import csv
import hashlib
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from silk_cli.core.project import get_config_dir

# Cache constants
CACHE_FILE_NAME = "cleanedfilescache.csv"
CLEAN_FILES_DIR = "outputs/temp"


@dataclass
class CacheEntry:
    """A single cache entry for a chapter."""

    chapter_key: str  # e.g., "Ch01"
    composite_hash: str  # MD5 hash of combined file hashes
    clean_file: str  # e.g., "clean_Ch01.md"


class SilkCache:
    """
    Cache manager for SILK chapter processing.

    Tracks composite hashes for multi-part chapters to avoid
    unnecessary reprocessing during publish operations.
    """

    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.silk_dir = get_config_dir(project_root)
        self.cache_file = self.silk_dir / CACHE_FILE_NAME
        self.clean_dir = project_root / CLEAN_FILES_DIR
        self._entries: dict[str, CacheEntry] = {}
        self._load()

    def _load(self) -> None:
        """Load cache entries from CSV file."""
        self._entries = {}

        if not self.cache_file.exists():
            return

        try:
            with open(self.cache_file, "r", encoding="utf-8") as f:
                reader = csv.reader(f)
                for row in reader:
                    # Skip comments and invalid rows
                    if not row or row[0].startswith("#") or len(row) < 3:
                        continue

                    chapter_key, composite_hash, clean_file = row[:3]
                    self._entries[chapter_key] = CacheEntry(
                        chapter_key=chapter_key,
                        composite_hash=composite_hash,
                        clean_file=clean_file,
                    )
        except (OSError, csv.Error):
            # If cache is corrupted, start fresh
            self._entries = {}

    def _save(self) -> None:
        """Save cache entries to CSV file."""
        self.silk_dir.mkdir(parents=True, exist_ok=True)

        with open(self.cache_file, "w", encoding="utf-8", newline="") as f:
            f.write("# SILK Cache - Multi-part chapters\n")
            f.write("# format: chapter_key,composite_hash,clean_file\n")

            writer = csv.writer(f)
            for entry in sorted(self._entries.values(), key=lambda e: e.chapter_key):
                writer.writerow([entry.chapter_key, entry.composite_hash, entry.clean_file])

    def get_entry(self, chapter_num: int) -> Optional[CacheEntry]:
        """Get cache entry for a chapter number."""
        key = f"Ch{chapter_num:02d}"
        return self._entries.get(key)

    def update_entry(self, chapter_num: int, composite_hash: str, clean_file: str) -> None:
        """Update or create cache entry for a chapter."""
        key = f"Ch{chapter_num:02d}"
        self._entries[key] = CacheEntry(
            chapter_key=key,
            composite_hash=composite_hash,
            clean_file=clean_file,
        )
        self._save()

    def remove_entry(self, chapter_num: int) -> bool:
        """Remove cache entry for a chapter. Returns True if entry existed."""
        key = f"Ch{chapter_num:02d}"
        if key in self._entries:
            del self._entries[key]
            self._save()
            return True
        return False

    def is_valid(self, chapter_num: int, source_files: list[Path]) -> bool:
        """
        Check if cache is valid for a chapter.

        Args:
            chapter_num: The chapter number.
            source_files: List of source file paths for this chapter.

        Returns:
            True if cache entry exists, hash matches, and clean file exists.
        """
        entry = self.get_entry(chapter_num)
        if not entry:
            return False

        # Calculate current composite hash
        current_hash = calculate_composite_hash(source_files)
        if current_hash != entry.composite_hash:
            return False

        # Verify clean file exists
        clean_path = self.clean_dir / entry.clean_file
        return clean_path.exists()

    def get_clean_file_path(self, chapter_num: int) -> Optional[Path]:
        """Get path to cached clean file if it exists."""
        entry = self.get_entry(chapter_num)
        if not entry:
            return None

        clean_path = self.clean_dir / entry.clean_file
        if clean_path.exists():
            return clean_path
        return None

    def cleanup(self, force: bool = False) -> tuple[int, int]:
        """
        Clean up invalid cache entries.

        Args:
            force: If True, clear entire cache.

        Returns:
            Tuple of (entries_removed, files_removed).
        """
        entries_removed = 0
        files_removed = 0

        if force:
            # Clear everything
            entries_removed = len(self._entries)
            self._entries = {}

            # Remove cache file
            if self.cache_file.exists():
                self.cache_file.unlink()

            # Remove clean files
            if self.clean_dir.exists():
                for f in self.clean_dir.glob("clean_Ch*.md"):
                    f.unlink()
                    files_removed += 1

            # Reinitialize
            self._save()
        else:
            # Remove entries with missing clean files
            to_remove = []
            for key, entry in self._entries.items():
                clean_path = self.clean_dir / entry.clean_file
                if not clean_path.exists():
                    to_remove.append(key)

            for key in to_remove:
                del self._entries[key]
                entries_removed += 1

            if entries_removed > 0:
                self._save()

        return entries_removed, files_removed

    def stats(self) -> dict:
        """Get cache statistics."""
        total_entries = len(self._entries)
        valid_entries = 0
        clean_files_count = 0

        if self.clean_dir.exists():
            clean_files_count = len(list(self.clean_dir.glob("clean_Ch*.md")))

        for entry in self._entries.values():
            clean_path = self.clean_dir / entry.clean_file
            if clean_path.exists():
                valid_entries += 1

        return {
            "total_entries": total_entries,
            "valid_entries": valid_entries,
            "invalid_entries": total_entries - valid_entries,
            "clean_files": clean_files_count,
            "cache_file": str(self.cache_file),
        }


def calculate_file_hash(file_path: Path) -> str:
    """Calculate MD5 hash of a file."""
    hasher = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def calculate_composite_hash(files: list[Path]) -> str:
    """
    Calculate composite MD5 hash from multiple files.

    The composite hash is MD5(hash1 + hash2 + ...) where each
    hashN is the MD5 of the corresponding file.

    Args:
        files: List of file paths, must be sorted for reproducibility.

    Returns:
        Composite MD5 hash string.
    """
    if not files:
        return ""

    # Sort files for reproducible hash
    sorted_files = sorted(files)

    # Concatenate individual file hashes
    combined_hashes = ""
    for f in sorted_files:
        if f.exists():
            combined_hashes += calculate_file_hash(f)

    # Hash the combined hashes
    return hashlib.md5(combined_hashes.encode()).hexdigest()
