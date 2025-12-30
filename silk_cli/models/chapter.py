"""
Chapter models for SILK projects.

Handles chapter representation, multi-part grouping, and range parsing.
"""

from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterator, Optional, Set


@dataclass
class Chapter:
    """
    Represents a single chapter file.

    A chapter can be a main chapter (Ch01.md) or a part (Ch01-1.md, Ch01-2.md).
    """

    number: int
    path: Path
    title: str
    content: str  # Content after manuscript separator
    word_count: int
    is_part: bool = False  # True if this is Ch01-1, Ch01-2, etc.
    part_number: Optional[int] = None  # The -1, -2 suffix number

    @property
    def base_number(self) -> int:
        """Get the base chapter number (same as number)."""
        return self.number

    @property
    def display_name(self) -> str:
        """Get display name like 'Ch01' or 'Ch01-1'."""
        if self.is_part and self.part_number is not None:
            return f"Ch{self.number:02d}-{self.part_number}"
        return f"Ch{self.number:02d}"


@dataclass
class ChapterGroup:
    """
    A group of related chapters (main chapter + parts).

    For example: Ch07.md + Ch07-1.md + Ch07-2.md form a single ChapterGroup.
    """

    number: int
    chapters: list[Chapter] = field(default_factory=list)

    @property
    def title(self) -> str:
        """Get the title from the main chapter (not a part)."""
        main = next((c for c in self.chapters if not c.is_part), None)
        if main:
            return main.title
        # Fallback to first chapter's title
        return self.chapters[0].title if self.chapters else f"Chapter {self.number}"

    @property
    def combined_content(self) -> str:
        """Get combined content from all parts, sorted by part number."""
        sorted_chapters = sorted(
            self.chapters,
            key=lambda c: (c.part_number or 0, c.path.name),
        )
        return "\n\n".join(c.content for c in sorted_chapters)

    @property
    def total_words(self) -> int:
        """Get total word count across all parts."""
        return sum(c.word_count for c in self.chapters)

    @property
    def parts_count(self) -> int:
        """Get the number of parts (files) in this group."""
        return len(self.chapters)

    @property
    def is_multipart(self) -> bool:
        """Check if this group has multiple parts."""
        return len(self.chapters) > 1

    @property
    def display_name(self) -> str:
        """Get display name with indicator if multipart."""
        suffix = "+" if self.is_multipart else ""
        return f"Ch{self.number:02d}{suffix}"

    @property
    def source_files(self) -> list[Path]:
        """Get all source file paths, sorted."""
        return sorted(c.path for c in self.chapters)


@dataclass
class ChapterRange:
    """
    Represents a range of chapter numbers.

    Supports formats:
    - "1" -> {1}
    - "1-10" -> {1, 2, 3, ..., 10}
    - "1,5,10" -> {1, 5, 10}
    - "1,5,10-15" -> {1, 5, 10, 11, 12, 13, 14, 15}
    - "all" -> all chapters
    """

    chapters: Set[int]
    is_all: bool = False

    @classmethod
    def parse(cls, spec: str, max_chapter: int = 999) -> "ChapterRange":
        """
        Parse a chapter range specification.

        Args:
            spec: Range specification string.
            max_chapter: Maximum chapter number for "all".

        Returns:
            ChapterRange instance.

        Raises:
            ValueError: If the specification is invalid.
        """
        spec = spec.strip().lower()

        if spec == "all":
            return cls(chapters=set(range(1, max_chapter + 1)), is_all=True)

        chapters: Set[int] = set()

        for part in spec.split(","):
            part = part.strip()
            if not part:
                continue

            if "-" in part:
                # Range: "1-10"
                try:
                    start_str, end_str = part.split("-", 1)
                    start = int(start_str.strip())
                    end = int(end_str.strip())
                    if start > end:
                        start, end = end, start
                    chapters.update(range(start, end + 1))
                except ValueError as e:
                    raise ValueError(f"Invalid range format: {part}") from e
            else:
                # Single number: "5"
                try:
                    chapters.add(int(part))
                except ValueError as e:
                    raise ValueError(f"Invalid chapter number: {part}") from e

        if not chapters:
            raise ValueError(f"Empty chapter range: {spec}")

        return cls(chapters=chapters)

    def contains(self, chapter_num: int) -> bool:
        """Check if a chapter number is in this range."""
        return chapter_num in self.chapters

    def __contains__(self, chapter_num: int) -> bool:
        """Support 'in' operator."""
        return self.contains(chapter_num)

    def __iter__(self) -> Iterator[int]:
        """Iterate over chapter numbers in sorted order."""
        return iter(sorted(self.chapters))

    def __len__(self) -> int:
        """Get the number of chapters in the range."""
        return len(self.chapters)

    @property
    def display(self) -> str:
        """Get a human-readable display of the range."""
        if self.is_all:
            return "all"
        if len(self.chapters) == 1:
            return str(next(iter(self.chapters)))

        sorted_chapters = sorted(self.chapters)

        # Try to compress into ranges
        ranges: list[str] = []
        start = sorted_chapters[0]
        end = start

        for num in sorted_chapters[1:]:
            if num == end + 1:
                end = num
            else:
                if start == end:
                    ranges.append(str(start))
                else:
                    ranges.append(f"{start}-{end}")
                start = num
                end = num

        # Add the last range
        if start == end:
            ranges.append(str(start))
        else:
            ranges.append(f"{start}-{end}")

        return ",".join(ranges)
