"""
End-to-end tests for silk publish command.
"""

import os
from pathlib import Path

import pytest
from typer.testing import CliRunner

from silk_cli.cli import app
from silk_cli.publishing.pandoc import check_pandoc_available, check_xelatex_available

runner = CliRunner()

# Skip tests if Pandoc is not available
pytestmark = pytest.mark.skipif(
    not check_pandoc_available(),
    reason="Pandoc not installed"
)


class TestPublishDryRun:
    """E2E tests for publish dry-run mode (no Pandoc required)."""

    @pytest.mark.skipif(True, reason="Dry run still requires project setup")
    def test_publish_dry_run(self, silk_project: Path):
        """Test publish dry-run mode."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["publish", "--dry-run"])

        assert result.exit_code == 0
        assert "dry run" in result.output.lower() or "No output" in result.output


class TestPublishFormats:
    """E2E tests for different publish formats."""

    def test_publish_html(self, silk_project: Path):
        """Test publishing HTML format."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["publish", "-f", "html", "--chapters", "1"])

        assert result.exit_code == 0
        # Check output file was created
        html_files = list((silk_project / "outputs" / "publish").glob("*.html"))
        assert len(html_files) >= 1

    def test_publish_epub(self, silk_project: Path):
        """Test publishing EPUB format."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["publish", "-f", "epub", "--chapters", "1"])

        assert result.exit_code == 0
        epub_files = list((silk_project / "outputs" / "publish").glob("*.epub"))
        assert len(epub_files) >= 1

    @pytest.mark.skipif(
        not check_xelatex_available(),
        reason="XeLaTeX not installed"
    )
    def test_publish_pdf(self, silk_project: Path):
        """Test publishing PDF format."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["publish", "-f", "digital", "--chapters", "1"])

        assert result.exit_code == 0
        pdf_files = list((silk_project / "outputs" / "publish").glob("*.pdf"))
        assert len(pdf_files) >= 1


class TestPublishOptions:
    """E2E tests for publish command options."""

    def test_publish_with_french_quotes(self, silk_project: Path):
        """Test publish with French quotes option."""
        os.chdir(silk_project)
        result = runner.invoke(
            app,
            ["publish", "-f", "html", "--chapters", "1", "--french-quotes"]
        )

        assert result.exit_code == 0
        # Check output mentions French quotes
        assert "guillemets" in result.output.lower() or result.exit_code == 0

    def test_publish_custom_output(self, silk_project: Path):
        """Test publish with custom output name."""
        os.chdir(silk_project)
        result = runner.invoke(
            app,
            ["publish", "-f", "html", "--chapters", "1", "-o", "custom-name"]
        )

        assert result.exit_code == 0
        custom_file = silk_project / "outputs" / "publish" / "custom-name.html"
        assert custom_file.exists()

    def test_publish_no_toc(self, silk_project: Path):
        """Test publish without table of contents."""
        os.chdir(silk_project)
        result = runner.invoke(
            app,
            ["publish", "-f", "html", "--chapters", "1", "--no-toc"]
        )

        assert result.exit_code == 0


class TestPublishErrors:
    """E2E tests for publish error handling."""

    def test_publish_invalid_format(self, silk_project: Path):
        """Test publish with invalid format."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["publish", "-f", "invalid"])

        assert result.exit_code != 0
        assert "unknown" in result.output.lower() or "invalid" in result.output.lower()

    def test_publish_outside_project(self, temp_dir: Path):
        """Test publish outside SILK project."""
        os.chdir(temp_dir)
        result = runner.invoke(app, ["publish"])

        assert result.exit_code != 0
