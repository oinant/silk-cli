"""
Unit tests for SILK statistics calculations.

Tests manuscript statistics and editorial categories without IO.
"""

from pathlib import Path

from silk_cli.core.statistics import (
    EDITORIAL_THRESHOLDS,
    WORDS_PER_PAGE,
    ChapterStats,
    ManuscriptStats,
    calculate_manuscript_stats,
    get_editorial_position,
)
from silk_cli.models.chapter import Chapter, ChapterGroup


class TestChapterStats:
    """Tests for ChapterStats dataclass."""

    def test_display_name_simple(self):
        """Test display name for simple chapter."""
        stats = ChapterStats(
            number=5,
            title="Test",
            words=1500,
            parts_count=1,
            is_multipart=False,
        )
        assert stats.display_name == "Ch05"

    def test_display_name_multipart(self):
        """Test display name for multipart chapter."""
        stats = ChapterStats(
            number=12,
            title="Test",
            words=3000,
            parts_count=3,
            is_multipart=True,
        )
        assert stats.display_name == "Ch12+"


class TestManuscriptStats:
    """Tests for ManuscriptStats dataclass."""

    def test_is_complete_true(self):
        """Test is_complete when target reached."""
        stats = ManuscriptStats(
            chapters=[],
            total_words=85000,
            total_chapters=30,
            target_words=80000,
            average_words_per_chapter=2833,
            min_chapter=None,
            max_chapter=None,
            completion_percent=106.25,
            words_remaining=0,
            words_per_chapter_needed=0,
            editorial_category="Roman standard",
            estimated_pages=340,
        )
        assert stats.is_complete is True

    def test_is_complete_false(self):
        """Test is_complete when target not reached."""
        stats = ManuscriptStats(
            chapters=[],
            total_words=50000,
            total_chapters=20,
            target_words=80000,
            average_words_per_chapter=2500,
            min_chapter=None,
            max_chapter=None,
            completion_percent=62.5,
            words_remaining=30000,
            words_per_chapter_needed=3000,
            editorial_category="Roman court",
            estimated_pages=200,
        )
        assert stats.is_complete is False

    def test_effort_level_complete(self):
        """Test effort level when complete."""
        stats = ManuscriptStats(
            chapters=[],
            total_words=80000,
            total_chapters=30,
            target_words=80000,
            average_words_per_chapter=2667,
            min_chapter=None,
            max_chapter=None,
            completion_percent=100,
            words_remaining=0,
            words_per_chapter_needed=0,
            editorial_category="Roman standard",
            estimated_pages=320,
        )
        assert stats.effort_level == "Objectif atteint"
        assert stats.effort_emoji == "✅"

    def test_effort_level_moderate(self):
        """Test moderate effort level."""
        stats = ManuscriptStats(
            chapters=[],
            total_words=70000,
            total_chapters=30,
            target_words=80000,
            average_words_per_chapter=2333,
            min_chapter=None,
            max_chapter=None,
            completion_percent=87.5,
            words_remaining=10000,
            words_per_chapter_needed=333,
            editorial_category="Roman court",
            estimated_pages=280,
        )
        assert stats.effort_level == "Modéré"
        assert stats.effort_emoji == "🟡"


class TestCalculateManuscriptStats:
    """Tests for calculate_manuscript_stats function."""

    def test_empty_groups(self):
        """Test with no chapters."""
        stats = calculate_manuscript_stats({}, target_words=80000)
        assert stats.total_words == 0
        assert stats.total_chapters == 0
        assert stats.completion_percent == 0

    def test_single_chapter(self):
        """Test with single chapter."""
        chapter = Chapter(
            number=1,
            path=Path("/test/Ch01.md"),
            title="Premier",
            content="Content here with several words to count.",
            word_count=2500,
        )
        group = ChapterGroup(number=1, chapters=[chapter])

        stats = calculate_manuscript_stats({1: group}, target_words=80000)
        assert stats.total_words == 2500
        assert stats.total_chapters == 1
        assert stats.average_words_per_chapter == 2500

    def test_multiple_chapters(self):
        """Test with multiple chapters."""
        groups = {}
        for i in range(1, 4):
            chapter = Chapter(
                number=i,
                path=Path(f"/test/Ch0{i}.md"),
                title=f"Chapter {i}",
                content=f"Content for chapter {i}",
                word_count=1000 * i,  # 1000, 2000, 3000
            )
            groups[i] = ChapterGroup(number=i, chapters=[chapter])

        stats = calculate_manuscript_stats(groups, target_words=10000)
        assert stats.total_words == 6000  # 1000 + 2000 + 3000
        assert stats.total_chapters == 3
        assert stats.average_words_per_chapter == 2000
        assert stats.min_chapter.words == 1000
        assert stats.max_chapter.words == 3000

    def test_completion_percent(self):
        """Test completion percentage calculation."""
        chapter = Chapter(
            number=1,
            path=Path("/test/Ch01.md"),
            title="Test",
            content="Large content block.",
            word_count=40000,
        )
        group = ChapterGroup(number=1, chapters=[chapter])

        stats = calculate_manuscript_stats({1: group}, target_words=80000)
        assert stats.completion_percent == 50.0
        assert stats.words_remaining == 40000


class TestGetEditorialPosition:
    """Tests for editorial positioning."""

    def test_below_thresholds(self):
        """Test word count below all thresholds."""
        category, pages, progress = get_editorial_position(30000)
        assert category == "En dessous des seuils"

    def test_novella_range(self):
        """Test novella range (40k-60k)."""
        category, pages, progress = get_editorial_position(50000)
        assert category == "Novella courte"

    def test_roman_court(self):
        """Test roman court range (60k-80k)."""
        category, pages, progress = get_editorial_position(70000)
        assert category == "Roman court"

    def test_roman_standard(self):
        """Test roman standard range (80k-100k)."""
        category, pages, progress = get_editorial_position(90000)
        assert category == "Roman standard"

    def test_gros_roman(self):
        """Test gros roman range (100k-120k)."""
        category, pages, progress = get_editorial_position(110000)
        assert category == "Gros roman"

    def test_tres_gros_roman(self):
        """Test très gros roman (120k+)."""
        category, pages, progress = get_editorial_position(150000)
        assert category == "Très gros roman"


class TestConstants:
    """Tests for module constants."""

    def test_words_per_page(self):
        """Test standard words per page constant."""
        assert WORDS_PER_PAGE == 250

    def test_editorial_thresholds_order(self):
        """Test thresholds are in ascending order."""
        thresholds = list(EDITORIAL_THRESHOLDS.keys())
        assert thresholds == sorted(thresholds)
