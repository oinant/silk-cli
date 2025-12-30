"""
Unit tests for SILK text transformers.

Tests SILK conventions, French quotes, and em-dashes without IO.
"""


from silk_cli.publishing.transformers import (
    OutputType,
    _convert_dashes,
    _convert_french_quotes,
    _convert_obsidian_links,
    _is_time_indicator,
    create_chapter_header,
    transform_line,
    transform_manuscript,
)


class TestSceneBreak:
    """Tests for scene break transformation (---)."""

    def test_scene_break_pdf(self):
        """Test scene break for PDF output."""
        result = transform_line("---", OutputType.PDF, False, False)
        assert "\\begin{center}" in result
        assert "***" in result
        assert "\\vspace{1cm}" in result

    def test_scene_break_epub(self):
        """Test scene break for EPUB output."""
        result = transform_line("---", OutputType.EPUB, False, False)
        assert result.strip() == "***"

    def test_scene_break_html(self):
        """Test scene break for HTML output."""
        result = transform_line("---", OutputType.HTML, False, False)
        assert result.strip() == "***"


class TestTypographicSpace:
    """Tests for typographic space transformation (~)."""

    def test_typo_space_pdf(self):
        """Test typographic space for PDF output."""
        result = transform_line("~", OutputType.PDF, False, False)
        assert "\\vspace{0.5cm}" in result

    def test_typo_space_epub(self):
        """Test typographic space for EPUB/HTML output."""
        result = transform_line("~", OutputType.EPUB, False, False)
        assert result == "\n"


class TestTimeIndicator:
    """Tests for time/place indicator (*text - text*)."""

    def test_is_time_indicator_valid(self):
        """Test valid time indicators."""
        assert _is_time_indicator("*Paris - Matin*") is True
        assert _is_time_indicator("*London - Evening*") is True
        assert _is_time_indicator("*Quelque part - Plus tard*") is True

    def test_is_time_indicator_invalid(self):
        """Test invalid time indicators."""
        assert _is_time_indicator("*simple italic*") is False  # No dash
        assert _is_time_indicator("Paris - Matin") is False  # No asterisks
        assert _is_time_indicator("**bold text**") is False
        assert _is_time_indicator("*") is False  # Too short

    def test_time_indicator_pdf(self):
        """Test time indicator for PDF output."""
        result = transform_line("*Paris - Matin*", OutputType.PDF, False, False)
        assert "\\begin{center}" in result
        assert "\\textit{Paris - Matin}" in result
        assert "\\end{center}" in result

    def test_time_indicator_epub(self):
        """Test time indicator for EPUB/HTML output."""
        result = transform_line("*London - Evening*", OutputType.EPUB, False, False)
        assert "*London - Evening*" in result


class TestFrenchQuotes:
    """Tests for French guillemets conversion."""

    def test_convert_simple_quotes(self):
        """Test simple quote conversion."""
        result = _convert_french_quotes('"Hello world"')
        assert result == "« Hello world »"

    def test_convert_multiple_quotes(self):
        """Test multiple quotes in same line."""
        result = _convert_french_quotes('He said "yes" and she said "no"')
        assert result == "He said « yes » and she said « no »"

    def test_no_quotes(self):
        """Test line without quotes."""
        result = _convert_french_quotes("No quotes here")
        assert result == "No quotes here"

    def test_transform_with_french_quotes(self):
        """Test full transform with french_quotes option."""
        result = transform_manuscript(
            '"Bonjour" dit-il.',
            output_type=OutputType.EPUB,
            french_quotes=True,
            auto_dashes=False,
        )
        assert "«" in result
        assert "»" in result


class TestDashConversion:
    """Tests for em-dash conversion."""

    def test_dialogue_dash_pdf(self):
        """Test dialogue dash for PDF (LaTeX)."""
        result = _convert_dashes("- Hello", OutputType.PDF)
        assert result.startswith("--- ")

    def test_dialogue_dash_epub(self):
        """Test dialogue dash for EPUB/HTML."""
        result = _convert_dashes("- Hello", OutputType.EPUB)
        assert result.startswith("— ")

    def test_existing_emdash_pdf(self):
        """Test existing em-dash for PDF."""
        result = _convert_dashes("— Already em-dash", OutputType.PDF)
        assert "---" in result

    def test_no_dash(self):
        """Test line without dash."""
        result = _convert_dashes("No dash here", OutputType.PDF)
        assert result == "No dash here"


class TestObsidianLinks:
    """Tests for Obsidian wiki link conversion."""

    def test_link_with_display(self):
        """Test [[link|display]] format."""
        result = _convert_obsidian_links("See [[Character/John|John]] here")
        assert result == "See John here"
        assert "[[" not in result

    def test_simple_link(self):
        """Test [[link]] format."""
        result = _convert_obsidian_links("See [[John]] here")
        assert result == "See John here"

    def test_multiple_links(self):
        """Test multiple links in same line."""
        result = _convert_obsidian_links("[[Alice]] and [[Bob|Robert]]")
        assert result == "Alice and Robert"

    def test_no_links(self):
        """Test line without links."""
        result = _convert_obsidian_links("No links here")
        assert result == "No links here"


class TestChapterHeader:
    """Tests for chapter header generation."""

    def test_first_chapter_no_pagebreak(self):
        """Test first chapter has no page break."""
        result = create_chapter_header(1, "Premier Chapitre", OutputType.PDF, is_first=True)
        assert "\\newpage" not in result
        assert "# Premier Chapitre" in result

    def test_subsequent_chapter_pagebreak(self):
        """Test subsequent chapters have page break (PDF)."""
        result = create_chapter_header(2, "Deuxième Chapitre", OutputType.PDF, is_first=False)
        assert "\\newpage" in result
        assert "# Deuxième Chapitre" in result

    def test_epub_no_pagebreak(self):
        """Test EPUB chapters have no LaTeX page break."""
        result = create_chapter_header(5, "Test", OutputType.EPUB, is_first=False)
        assert "\\newpage" not in result
        assert "# Test" in result


class TestFullTransform:
    """Integration tests for full manuscript transformation."""

    def test_transform_with_all_conventions(self):
        """Test transformation with all SILK conventions."""
        content = """First paragraph.

---

After scene break.

~

After typo space.

*Paris - Morning*

Time indicator.
"""
        result = transform_manuscript(content, OutputType.EPUB, False, False)

        assert "***" in result  # Scene break
        assert "First paragraph" in result
        assert "*Paris - Morning*" in result

    def test_transform_preserves_empty_lines(self):
        """Test that empty lines are preserved."""
        content = "Line 1\n\nLine 2"
        result = transform_manuscript(content, OutputType.EPUB, False, False)
        assert "\n\n" in result or result.count("\n") >= 2
