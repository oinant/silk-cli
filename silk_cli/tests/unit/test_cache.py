"""
Unit tests for SILK cache system.

Tests MD5 hashing and cache management without external dependencies.
"""

from pathlib import Path

from silk_cli.core.cache import (
    CacheEntry,
    SilkCache,
    calculate_composite_hash,
    calculate_file_hash,
)


class TestCacheEntry:
    """Tests for CacheEntry dataclass."""

    def test_cache_entry_creation(self):
        """Test creating a cache entry."""
        entry = CacheEntry(
            chapter_key="Ch01",
            composite_hash="abc123def456",
            clean_file="clean_Ch01.md",
        )
        assert entry.chapter_key == "Ch01"
        assert entry.composite_hash == "abc123def456"
        assert entry.clean_file == "clean_Ch01.md"


class TestCalculateFileHash:
    """Tests for file hash calculation."""

    def test_hash_simple_file(self, temp_dir: Path):
        """Test hashing a simple file."""
        test_file = temp_dir / "test.txt"
        test_file.write_text("Hello, World!")

        hash_result = calculate_file_hash(test_file)

        assert isinstance(hash_result, str)
        assert len(hash_result) == 32  # MD5 hex digest length

    def test_hash_is_deterministic(self, temp_dir: Path):
        """Test that same content produces same hash."""
        file1 = temp_dir / "file1.txt"
        file2 = temp_dir / "file2.txt"

        file1.write_text("Same content")
        file2.write_text("Same content")

        assert calculate_file_hash(file1) == calculate_file_hash(file2)

    def test_different_content_different_hash(self, temp_dir: Path):
        """Test that different content produces different hash."""
        file1 = temp_dir / "file1.txt"
        file2 = temp_dir / "file2.txt"

        file1.write_text("Content A")
        file2.write_text("Content B")

        assert calculate_file_hash(file1) != calculate_file_hash(file2)


class TestCalculateCompositeHash:
    """Tests for composite hash calculation."""

    def test_empty_list(self):
        """Test with empty file list."""
        result = calculate_composite_hash([])
        assert result == ""

    def test_single_file(self, temp_dir: Path):
        """Test with single file."""
        test_file = temp_dir / "test.txt"
        test_file.write_text("Content")

        result = calculate_composite_hash([test_file])

        assert isinstance(result, str)
        assert len(result) == 32

    def test_multiple_files(self, temp_dir: Path):
        """Test with multiple files."""
        file1 = temp_dir / "ch01.md"
        file2 = temp_dir / "ch01-1.md"

        file1.write_text("Part 1")
        file2.write_text("Part 2")

        result = calculate_composite_hash([file1, file2])

        assert isinstance(result, str)
        assert len(result) == 32

    def test_order_independent_after_sort(self, temp_dir: Path):
        """Test that file order doesn't matter (sorted internally)."""
        file1 = temp_dir / "a.txt"
        file2 = temp_dir / "b.txt"

        file1.write_text("A")
        file2.write_text("B")

        # Different order, same result
        hash1 = calculate_composite_hash([file1, file2])
        hash2 = calculate_composite_hash([file2, file1])

        assert hash1 == hash2

    def test_missing_file_skipped(self, temp_dir: Path):
        """Test that missing files are skipped."""
        existing = temp_dir / "exists.txt"
        missing = temp_dir / "missing.txt"

        existing.write_text("Content")

        # Should not raise, just skip missing
        result = calculate_composite_hash([existing, missing])
        assert isinstance(result, str)


class TestSilkCache:
    """Tests for SilkCache class."""

    def test_cache_init_empty(self, silk_project: Path):
        """Test initializing cache on project without cache file."""
        cache = SilkCache(silk_project)

        assert cache.project_root == silk_project
        assert len(cache._entries) == 0

    def test_get_entry_not_found(self, silk_project: Path):
        """Test getting non-existent entry."""
        cache = SilkCache(silk_project)
        result = cache.get_entry(99)

        assert result is None

    def test_update_and_get_entry(self, silk_project: Path):
        """Test updating and retrieving entry."""
        cache = SilkCache(silk_project)

        cache.update_entry(5, "hash123", "clean_Ch05.md")
        entry = cache.get_entry(5)

        assert entry is not None
        assert entry.chapter_key == "Ch05"
        assert entry.composite_hash == "hash123"
        assert entry.clean_file == "clean_Ch05.md"

    def test_remove_entry(self, silk_project: Path):
        """Test removing an entry."""
        cache = SilkCache(silk_project)
        cache.update_entry(3, "hash", "clean_Ch03.md")

        assert cache.get_entry(3) is not None

        result = cache.remove_entry(3)

        assert result is True
        assert cache.get_entry(3) is None

    def test_remove_nonexistent_entry(self, silk_project: Path):
        """Test removing entry that doesn't exist."""
        cache = SilkCache(silk_project)
        result = cache.remove_entry(99)

        assert result is False

    def test_cache_persistence(self, silk_project: Path):
        """Test that cache persists to file."""
        cache1 = SilkCache(silk_project)
        cache1.update_entry(1, "persistent_hash", "clean_Ch01.md")

        # Create new cache instance
        cache2 = SilkCache(silk_project)
        entry = cache2.get_entry(1)

        assert entry is not None
        assert entry.composite_hash == "persistent_hash"

    def test_stats(self, silk_project: Path):
        """Test cache statistics."""
        cache = SilkCache(silk_project)
        cache.update_entry(1, "hash1", "clean_Ch01.md")
        cache.update_entry(2, "hash2", "clean_Ch02.md")

        stats = cache.stats()

        assert stats["total_entries"] == 2
        assert "cache_file" in stats

    def test_is_valid_no_entry(self, silk_project: Path):
        """Test is_valid with no cache entry."""
        cache = SilkCache(silk_project)
        result = cache.is_valid(99, [])

        assert result is False

    def test_cleanup_force(self, silk_project: Path):
        """Test force cleanup."""
        cache = SilkCache(silk_project)
        cache.update_entry(1, "hash", "clean_Ch01.md")

        entries_removed, files_removed = cache.cleanup(force=True)

        assert entries_removed == 1
        assert cache.get_entry(1) is None
