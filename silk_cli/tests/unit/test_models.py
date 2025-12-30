"""
Unit tests for SILK models.

Tests SilkConfig, Chapter, ChapterGroup, and ChapterRange without IO dependencies.
"""

from pathlib import Path

import pytest

from silk_cli.models.chapter import Chapter, ChapterGroup, ChapterRange
from silk_cli.models.config import SilkConfig


class TestSilkConfig:
    """Tests for SilkConfig model."""

    def test_default_values(self):
        """Test default configuration values."""
        config = SilkConfig()
        assert config.title == "Untitled"
        assert config.genre == "polar-psychologique"
        assert config.language == "fr"
        assert config.target_words == 80000
        assert config.target_chapters == 30
        assert config.manuscript_separator == "## manuscrit"

    def test_custom_values(self):
        """Test configuration with custom values."""
        config = SilkConfig(
            title="Mon Roman",
            genre="fantasy",
            language="en",
            target_words=100000,
            target_chapters=40,
            author_name="Test Author",
        )
        assert config.title == "Mon Roman"
        assert config.genre == "fantasy"
        assert config.language == "en"
        assert config.target_words == 100000
        assert config.target_chapters == 40
        assert config.author_name == "Test Author"

    def test_language_must_be_valid(self):
        """Test that invalid language raises error."""
        with pytest.raises(Exception):  # Pydantic validation error
            SilkConfig(language="invalid")

    def test_valid_languages(self):
        """Test all valid language codes."""
        for lang in ["fr", "en", "es", "de", "it"]:
            config = SilkConfig(language=lang)
            assert config.language == lang

    def test_valid_genres(self):
        """Test all valid genre values."""
        valid_genres = ["polar-psychologique", "fantasy", "romance", "literary", "thriller"]
        for genre in valid_genres:
            config = SilkConfig(genre=genre)
            assert config.genre == genre

    def test_words_per_chapter(self):
        """Test words per chapter calculation."""
        config = SilkConfig(target_words=90000, target_chapters=30)
        assert config.target_words // config.target_chapters == 3000


class TestChapter:
    """Tests for Chapter dataclass."""

    def test_chapter_creation(self):
        """Test basic chapter creation."""
        chapter = Chapter(
            number=1,
            path=Path("/test/Ch01.md"),
            title="Premier Chapitre",
            content="Some content here.",
            word_count=1500,
        )
        assert chapter.number == 1
        assert chapter.title == "Premier Chapitre"
        assert chapter.word_count == 1500
        assert chapter.is_part is False
        assert chapter.part_number is None

    def test_chapter_part(self):
        """Test chapter part creation."""
        chapter = Chapter(
            number=2,
            path=Path("/test/Ch02-1.md"),
            title="Deuxième Chapitre",
            content="Part content.",
            word_count=800,
            is_part=True,
            part_number=1,
        )
        assert chapter.is_part is True
        assert chapter.part_number == 1

    def test_chapter_display_name(self):
        """Test display name generation."""
        chapter = Chapter(
            number=5,
            path=Path("/test/Ch05.md"),
            title="Test",
            content="Content",
            word_count=100,
        )
        assert chapter.display_name == "Ch05"

    def test_chapter_part_display_name(self):
        """Test display name for chapter part."""
        chapter = Chapter(
            number=5,
            path=Path("/test/Ch05-2.md"),
            title="Test",
            content="Content",
            word_count=100,
            is_part=True,
            part_number=2,
        )
        assert chapter.display_name == "Ch05-2"


class TestChapterGroup:
    """Tests for ChapterGroup dataclass."""

    def test_single_chapter_group(self):
        """Test group with single chapter."""
        chapter = Chapter(
            number=1,
            path=Path("/test/Ch01.md"),
            title="Test",
            content="Content here.",
            word_count=1000,
        )
        group = ChapterGroup(number=1, chapters=[chapter])

        assert group.number == 1
        assert group.title == "Test"
        assert group.total_words == 1000
        assert group.parts_count == 1
        assert group.is_multipart is False

    def test_multipart_chapter_group(self):
        """Test group with multiple parts."""
        chapters = [
            Chapter(
                number=2, path=Path("/test/Ch02.md"),
                title="Test", content="Part 0", word_count=500
            ),
            Chapter(
                number=2, path=Path("/test/Ch02-1.md"), title="Test",
                content="Part 1", word_count=600, is_part=True, part_number=1
            ),
            Chapter(
                number=2, path=Path("/test/Ch02-2.md"), title="Test",
                content="Part 2", word_count=400, is_part=True, part_number=2
            ),
        ]
        group = ChapterGroup(number=2, chapters=chapters)

        assert group.total_words == 1500
        assert group.parts_count == 3
        assert group.is_multipart is True

    def test_group_display_name(self):
        """Test display name for multipart group."""
        chapters = [
            Chapter(
                number=3, path=Path("/test/Ch03.md"),
                title="Test", content="A", word_count=100
            ),
            Chapter(
                number=3, path=Path("/test/Ch03-1.md"), title="Test",
                content="B", word_count=100, is_part=True, part_number=1
            ),
        ]
        group = ChapterGroup(number=3, chapters=chapters)
        assert group.display_name == "Ch03+"


class TestChapterRange:
    """Tests for ChapterRange parsing."""

    def test_single_chapter(self):
        """Test parsing single chapter number."""
        range_obj = ChapterRange.parse("5", max_chapter=30)
        assert 5 in range_obj.chapters
        assert len(range_obj.chapters) == 1

    def test_chapter_range(self):
        """Test parsing chapter range."""
        range_obj = ChapterRange.parse("1-5", max_chapter=30)
        assert range_obj.chapters == {1, 2, 3, 4, 5}

    def test_multiple_ranges(self):
        """Test parsing multiple ranges."""
        range_obj = ChapterRange.parse("1-3,10,15-17", max_chapter=30)
        assert range_obj.chapters == {1, 2, 3, 10, 15, 16, 17}

    def test_all_chapters(self):
        """Test 'all' keyword."""
        range_obj = ChapterRange.parse("all", max_chapter=10)
        assert range_obj.chapters == {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
        assert range_obj.is_all is True

    def test_range_beyond_max(self):
        """Test that range can extend beyond max_chapter (no clamping)."""
        # The actual implementation doesn't clamp, so test the actual behavior
        range_obj = ChapterRange.parse("25-35", max_chapter=30)
        assert 35 in range_obj.chapters  # Not clamped

    def test_contains(self):
        """Test __contains__ method."""
        range_obj = ChapterRange.parse("1-10", max_chapter=30)
        assert 5 in range_obj
        assert 15 not in range_obj

    def test_invalid_raises_error(self):
        """Test that invalid input raises ValueError."""
        with pytest.raises(ValueError):
            ChapterRange.parse("invalid", max_chapter=30)

    def test_empty_spec_raises_error(self):
        """Test that empty spec raises ValueError."""
        with pytest.raises(ValueError):
            ChapterRange.parse("", max_chapter=30)

    def test_display_property(self):
        """Test display property for ranges."""
        range_obj = ChapterRange.parse("1-3,5,7-9", max_chapter=30)
        assert "1-3" in range_obj.display
        assert "5" in range_obj.display
