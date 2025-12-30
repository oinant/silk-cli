"""
Manuscript statistics calculations for SILK projects.

Provides word count analysis, progress tracking, and editorial positioning.
"""

from dataclasses import dataclass
from typing import Optional

from silk_cli.models.chapter import ChapterGroup

# Editorial thresholds (word counts)
EDITORIAL_THRESHOLDS = {
    40_000: ("Novella courte", "~160 pages"),
    60_000: ("Roman court", "~240 pages"),
    80_000: ("Roman standard", "~320 pages"),
    100_000: ("Gros roman", "~400 pages"),
    120_000: ("Très gros roman", "~480 pages"),
}

# Words per page estimate
WORDS_PER_PAGE = 250


@dataclass
class ChapterStats:
    """Statistics for a single chapter group."""

    number: int
    title: str
    words: int
    parts_count: int
    is_multipart: bool

    @property
    def display_name(self) -> str:
        """Get display name with multipart indicator."""
        suffix = "+" if self.is_multipart else ""
        return f"Ch{self.number:02d}{suffix}"


@dataclass
class ManuscriptStats:
    """Complete manuscript statistics."""

    chapters: list[ChapterStats]
    total_words: int
    total_chapters: int
    target_words: int

    # Calculated stats
    average_words_per_chapter: float
    min_chapter: Optional[ChapterStats]
    max_chapter: Optional[ChapterStats]

    # Progress
    completion_percent: float
    words_remaining: int
    words_per_chapter_needed: float

    # Editorial positioning
    editorial_category: str
    estimated_pages: int

    @property
    def is_complete(self) -> bool:
        """Check if target has been reached."""
        return self.total_words >= self.target_words

    @property
    def effort_level(self) -> str:
        """Get effort level description based on words needed per chapter."""
        if self.words_remaining <= 0:
            return "Objectif atteint"
        if self.words_per_chapter_needed < 300:
            return "Très réalisable"
        if self.words_per_chapter_needed < 600:
            return "Modéré"
        if self.words_per_chapter_needed < 1000:
            return "Important"
        return "Très important"

    @property
    def effort_emoji(self) -> str:
        """Get emoji for effort level."""
        if self.words_remaining <= 0:
            return "✅"
        if self.words_per_chapter_needed < 300:
            return "✅"
        if self.words_per_chapter_needed < 600:
            return "🟡"
        if self.words_per_chapter_needed < 1000:
            return "🟠"
        return "🔥"


def calculate_manuscript_stats(
    groups: dict[int, ChapterGroup],
    target_words: int = 80000,
) -> ManuscriptStats:
    """
    Calculate comprehensive manuscript statistics.

    Args:
        groups: Dictionary of chapter groups from collect_chapters().
        target_words: Target word count.

    Returns:
        ManuscriptStats with all calculated metrics.
    """
    # Build chapter stats
    chapter_stats: list[ChapterStats] = []
    for num in sorted(groups.keys()):
        group = groups[num]
        chapter_stats.append(
            ChapterStats(
                number=num,
                title=group.title,
                words=group.total_words,
                parts_count=group.parts_count,
                is_multipart=group.is_multipart,
            )
        )

    # Calculate totals
    total_words = sum(cs.words for cs in chapter_stats)
    total_chapters = len(chapter_stats)

    # Calculate averages
    avg_words = total_words / total_chapters if total_chapters > 0 else 0

    # Find min/max
    min_chapter = min(chapter_stats, key=lambda c: c.words) if chapter_stats else None
    max_chapter = max(chapter_stats, key=lambda c: c.words) if chapter_stats else None

    # Progress calculations
    completion = (total_words / target_words * 100) if target_words > 0 else 0
    words_remaining = max(0, target_words - total_words)
    words_needed = words_remaining / total_chapters if total_chapters > 0 else 0

    # Editorial category
    category = "En dessous des seuils"
    for threshold, (cat_name, _) in sorted(EDITORIAL_THRESHOLDS.items()):
        if total_words >= threshold:
            category = cat_name

    # Estimated pages
    pages = total_words // WORDS_PER_PAGE

    return ManuscriptStats(
        chapters=chapter_stats,
        total_words=total_words,
        total_chapters=total_chapters,
        target_words=target_words,
        average_words_per_chapter=avg_words,
        min_chapter=min_chapter,
        max_chapter=max_chapter,
        completion_percent=completion,
        words_remaining=words_remaining,
        words_per_chapter_needed=words_needed,
        editorial_category=category,
        estimated_pages=pages,
    )


def get_editorial_position(total_words: int) -> tuple[str, str, float]:
    """
    Get editorial positioning for a word count.

    Args:
        total_words: Total word count.

    Returns:
        Tuple of (category_name, page_estimate, percent_to_next_threshold).
    """
    sorted_thresholds = sorted(EDITORIAL_THRESHOLDS.items())

    current_category = "En dessous des seuils"
    current_pages = "< 160 pages"
    next_threshold = sorted_thresholds[0][0] if sorted_thresholds else 80000

    for i, (threshold, (cat_name, pages)) in enumerate(sorted_thresholds):
        if total_words >= threshold:
            current_category = cat_name
            current_pages = pages
            # Find next threshold
            if i + 1 < len(sorted_thresholds):
                next_threshold = sorted_thresholds[i + 1][0]
            else:
                next_threshold = threshold  # Already at max
        else:
            next_threshold = threshold
            break

    # Calculate progress to next threshold
    if total_words >= next_threshold:
        progress = 100.0
    else:
        prev_threshold = 0
        for threshold, _ in sorted_thresholds:
            if threshold >= next_threshold:
                break
            prev_threshold = threshold
        range_size = next_threshold - prev_threshold
        if range_size > 0:
            progress = (total_words - prev_threshold) / range_size * 100
        else:
            progress = 100.0

    return current_category, current_pages, progress
