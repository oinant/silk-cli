"""
Chapter parsing and collection for SILK projects.

Handles multi-part chapter detection (Ch01, Ch01-1, Ch01-2) and consolidation.
"""

import re
from pathlib import Path
from typing import Optional

from silk_cli.models.chapter import Chapter, ChapterGroup, ChapterRange

# Pattern to match chapter filenames: Ch01.md, Ch23-1.md, Ch07-2-suite.md, etc.
CHAPTER_PATTERN = re.compile(
    r"^[Cc]h(\d+)(?:-(\d+))?.*\.md$"
)


def parse_chapter_filename(filename: str) -> Optional[tuple[int, Optional[int]]]:
    """
    Parse a chapter filename to extract chapter and part numbers.

    Args:
        filename: The filename to parse (e.g., "Ch01.md", "Ch07-1.md").

    Returns:
        Tuple of (chapter_number, part_number) or None if not a chapter file.
        part_number is None for main chapters.

    Examples:
        >>> parse_chapter_filename("Ch01.md")
        (1, None)
        >>> parse_chapter_filename("Ch07-1.md")
        (7, 1)
        >>> parse_chapter_filename("Ch23-2-suite.md")
        (23, 2)
        >>> parse_chapter_filename("notes.md")
        None
    """
    match = CHAPTER_PATTERN.match(filename)
    if not match:
        return None

    chapter_num = int(match.group(1))
    part_num = int(match.group(2)) if match.group(2) else None

    return (chapter_num, part_num)


def extract_chapter_title(file_path: Path) -> str:
    """
    Extract the title from a chapter file.

    Looks for the first heading line (# ...) in the file.

    Args:
        file_path: Path to the chapter file.

    Returns:
        The chapter title, or a default title if not found.
    """
    try:
        content = file_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return f"Chapter {file_path.stem}"

    for line in content.split("\n"):
        line = line.strip()
        if line.startswith("# "):
            # Remove the # prefix and clean up
            title = line[2:].strip()
            # Remove common prefixes like "Ch.01 : " or "Chapitre 1 - "
            title = re.sub(r"^(Ch\.?\s*\d+\s*[:\-]\s*|Chapitre\s*\d+\s*[:\-]\s*)", "", title)
            return title if title else f"Chapter {file_path.stem}"

    return f"Chapter {file_path.stem}"


def extract_manuscript_content(
    file_path: Path,
    separator: str = "## manuscrit",
) -> Optional[str]:
    """
    Extract content after the manuscript separator.

    Args:
        file_path: Path to the chapter file.
        separator: The separator marking the start of manuscript content.

    Returns:
        Content after the separator, or None if separator not found.
    """
    try:
        content = file_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None

    if separator not in content:
        return None

    # Split on separator and take everything after
    parts = content.split(separator, 1)
    if len(parts) < 2:
        return None

    # Strip leading whitespace/newlines from the content
    manuscript = parts[1].strip()
    return manuscript if manuscript else None


def count_words(text: str) -> int:
    """
    Count words in text.

    Args:
        text: The text to count words in.

    Returns:
        Word count.
    """
    if not text:
        return 0
    # Split on whitespace and count non-empty parts
    return len(text.split())


def collect_chapters(
    manuscript_dir: Path,
    separator: str = "## manuscrit",
    chapter_range: Optional[ChapterRange] = None,
) -> dict[int, ChapterGroup]:
    """
    Collect and group chapters from a manuscript directory.

    Automatically groups multi-part chapters:
    Ch01.md + Ch01-1.md + Ch01-2.md -> ChapterGroup(number=1)

    Args:
        manuscript_dir: Path to the 01-Manuscrit directory.
        separator: The manuscript separator string.
        chapter_range: Optional range to filter chapters.

    Returns:
        Dictionary mapping chapter numbers to ChapterGroups.
    """
    groups: dict[int, ChapterGroup] = {}

    if not manuscript_dir.exists():
        return groups

    # Find all chapter files
    chapter_files = sorted(manuscript_dir.glob("Ch*.md")) + sorted(
        manuscript_dir.glob("ch*.md")
    )

    for file_path in chapter_files:
        parsed = parse_chapter_filename(file_path.name)
        if not parsed:
            continue

        chapter_num, part_num = parsed

        # Filter by range if specified
        if chapter_range and chapter_num not in chapter_range:
            continue

        # Extract content after separator
        content = extract_manuscript_content(file_path, separator)
        if content is None:
            # Skip files without manuscript separator
            continue

        # Extract title
        title = extract_chapter_title(file_path)

        # Create Chapter object
        chapter = Chapter(
            number=chapter_num,
            path=file_path,
            title=title,
            content=content,
            word_count=count_words(content),
            is_part=part_num is not None,
            part_number=part_num,
        )

        # Add to group
        if chapter_num not in groups:
            groups[chapter_num] = ChapterGroup(number=chapter_num)
        groups[chapter_num].chapters.append(chapter)

    return groups


def get_max_chapter_number(manuscript_dir: Path) -> int:
    """
    Get the highest chapter number in a manuscript directory.

    Args:
        manuscript_dir: Path to the 01-Manuscrit directory.

    Returns:
        The highest chapter number found, or 0 if none.
    """
    max_num = 0

    if not manuscript_dir.exists():
        return max_num

    for file_path in manuscript_dir.glob("Ch*.md"):
        parsed = parse_chapter_filename(file_path.name)
        if parsed:
            max_num = max(max_num, parsed[0])

    for file_path in manuscript_dir.glob("ch*.md"):
        parsed = parse_chapter_filename(file_path.name)
        if parsed:
            max_num = max(max_num, parsed[0])

    return max_num
