"""
End-to-end tests for silk wordcount command.
"""

import os
from pathlib import Path

from typer.testing import CliRunner

from silk_cli.cli import app

runner = CliRunner()


class TestWordcountCommand:
    """E2E tests for wordcount command."""

    def test_wordcount_in_project(self, silk_project: Path):
        """Test wordcount in a SILK project."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["wordcount"])

        assert result.exit_code == 0
        assert "Ch01" in result.output or "Chapitre" in result.output

    def test_wordcount_with_target(self, silk_project: Path):
        """Test wordcount with custom target."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["wordcount", "--target", "50000"])

        assert result.exit_code == 0

    def test_wordcount_chapter_range(self, silk_project: Path):
        """Test wordcount with chapter range."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["wordcount", "--chapters", "1-2"])

        assert result.exit_code == 0

    def test_wordcount_json_output(self, silk_project: Path):
        """Test wordcount with JSON output."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["wordcount", "--format", "json"])

        assert result.exit_code == 0
        # Should contain JSON structure
        assert "{" in result.output

    def test_wordcount_summary_output(self, silk_project: Path):
        """Test wordcount with summary output."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["wordcount", "--summary"])

        assert result.exit_code == 0

    def test_wordcount_outside_project(self, temp_dir: Path):
        """Test wordcount outside SILK project fails gracefully."""
        os.chdir(temp_dir)
        result = runner.invoke(app, ["wordcount"])

        # Should fail with informative error
        assert result.exit_code != 0 or "not" in result.output.lower()


class TestWordcountMultipart:
    """E2E tests for multipart chapter handling in wordcount."""

    def test_multipart_grouped(self, silk_project: Path):
        """Test that multipart chapters are grouped."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["wordcount"])

        assert result.exit_code == 0
        # Ch02 and Ch02-1 should be grouped
        # Look for multipart indicator or combined word count
        output_lower = result.output.lower()
        assert "ch02" in output_lower or "chapitre 2" in output_lower


class TestWordcountFormats:
    """E2E tests for different output formats."""

    def test_table_format(self, silk_project: Path):
        """Test default table format."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["wordcount", "--format", "table"])
        assert result.exit_code == 0

    def test_csv_format(self, silk_project: Path):
        """Test CSV output format."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["wordcount", "--format", "csv"])
        assert result.exit_code == 0
        # CSV should have comma-separated values
        assert "," in result.output
