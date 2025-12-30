"""
Unit tests for SILK chapter parsing.

Tests chapter detection, parsing, and word counting without IO.
"""


from silk_cli.core.chapters import (
    CHAPTER_PATTERN,
    count_words,
    parse_chapter_filename,
)


class TestChapterPattern:
    """Tests for chapter filename regex pattern."""

    def test_simple_chapter(self):
        """Test simple chapter filename."""
        match = CHAPTER_PATTERN.match("Ch01.md")
        assert match is not None
        assert match.group(1) == "01"
        assert match.group(2) is None

    def test_two_digit_chapter(self):
        """Test two digit chapter number."""
        match = CHAPTER_PATTERN.match("Ch15.md")
        assert match is not None
        assert match.group(1) == "15"

    def test_multipart_chapter(self):
        """Test multipart chapter filename."""
        match = CHAPTER_PATTERN.match("Ch07-1.md")
        assert match is not None
        assert match.group(1) == "07"
        assert match.group(2) == "1"

    def test_multipart_higher_number(self):
        """Test multipart with higher part number."""
        match = CHAPTER_PATTERN.match("Ch12-3.md")
        assert match is not None
        assert match.group(1) == "12"
        assert match.group(2) == "3"

    def test_chapter_with_suffix(self):
        """Test chapter with additional suffix."""
        match = CHAPTER_PATTERN.match("Ch07-2-suite.md")
        assert match is not None
        assert match.group(1) == "07"
        assert match.group(2) == "2"

    def test_lowercase_chapter(self):
        """Test lowercase ch prefix."""
        match = CHAPTER_PATTERN.match("ch05.md")
        assert match is not None
        assert match.group(1) == "05"

    def test_non_chapter_file(self):
        """Test non-chapter files don't match."""
        assert CHAPTER_PATTERN.match("README.md") is None
        assert CHAPTER_PATTERN.match("notes.md") is None
        assert CHAPTER_PATTERN.match("Chapter01.md") is None


class TestParseChapterFilename:
    """Tests for parse_chapter_filename function."""

    def test_simple_chapter(self):
        """Test parsing simple chapter."""
        result = parse_chapter_filename("Ch05.md")
        assert result is not None
        number, part = result
        assert number == 5
        assert part is None

    def test_multipart_chapter(self):
        """Test parsing multipart chapter."""
        result = parse_chapter_filename("Ch10-2.md")
        assert result is not None
        number, part = result
        assert number == 10
        assert part == 2

    def test_chapter_with_suffix(self):
        """Test parsing chapter with suffix."""
        result = parse_chapter_filename("Ch23-2-suite.md")
        assert result is not None
        number, part = result
        assert number == 23
        assert part == 2

    def test_invalid_filename(self):
        """Test parsing invalid filename."""
        result = parse_chapter_filename("invalid.md")
        assert result is None

    def test_leading_zeros(self):
        """Test that leading zeros are handled."""
        result = parse_chapter_filename("Ch01.md")
        assert result is not None
        number, part = result
        assert number == 1  # Should be 1, not 01


class TestCountWords:
    """Tests for word counting."""

    def test_simple_text(self):
        """Test counting simple text."""
        text = "One two three four five"
        assert count_words(text) == 5

    def test_with_punctuation(self):
        """Test counting with punctuation."""
        text = "Hello, world! How are you?"
        assert count_words(text) == 5

    def test_multiline(self):
        """Test counting multiline text."""
        text = "Line one.\nLine two.\nLine three."
        assert count_words(text) == 6

    def test_empty(self):
        """Test counting empty text."""
        assert count_words("") == 0
        assert count_words(None) == 0  # type: ignore

    def test_whitespace_only(self):
        """Test counting whitespace-only text."""
        assert count_words("   \n\n  \t  ") == 0

    def test_french_text(self):
        """Test counting French text."""
        text = "C'est un test avec des mots français."
        assert count_words(text) >= 5

    def test_with_numbers(self):
        """Test that numbers count as words."""
        text = "Chapter 1 has 1000 words"
        assert count_words(text) == 5

    def test_long_text(self):
        """Test counting longer text."""
        words = ["word"] * 100
        text = " ".join(words)
        assert count_words(text) == 100


class TestChapterPatternEdgeCases:
    """Edge case tests for chapter patterns."""

    def test_single_digit_no_padding(self):
        """Test single digit without zero padding."""
        match = CHAPTER_PATTERN.match("Ch1.md")
        assert match is not None
        assert match.group(1) == "1"

    def test_three_digit_chapter(self):
        """Test three digit chapter number."""
        match = CHAPTER_PATTERN.match("Ch100.md")
        assert match is not None
        assert match.group(1) == "100"

    def test_chapter_99(self):
        """Test high chapter numbers."""
        match = CHAPTER_PATTERN.match("Ch99.md")
        assert match is not None
        assert match.group(1) == "99"

    def test_chapter_zero(self):
        """Test chapter zero."""
        match = CHAPTER_PATTERN.match("Ch00.md")
        assert match is not None
        assert match.group(1) == "00"
