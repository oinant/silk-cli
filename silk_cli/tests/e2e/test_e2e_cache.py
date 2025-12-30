"""
End-to-end tests for silk cache command.
"""

import os
from pathlib import Path

from typer.testing import CliRunner

from silk_cli.cli import app

runner = CliRunner()


class TestCacheCommand:
    """E2E tests for cache command."""

    def test_cache_stats(self, silk_project: Path):
        """Test cache stats display."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["cache"])

        assert result.exit_code == 0
        # Should show cache info
        assert "cache" in result.output.lower() or "entries" in result.output.lower()

    def test_cache_cleanup(self, silk_project: Path):
        """Test cache cleanup command."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["cache", "--cleanup"])

        assert result.exit_code == 0

    def test_cache_stats_flag(self, silk_project: Path):
        """Test cache stats command with --stats flag."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["cache", "--stats"])

        assert result.exit_code == 0

    def test_cache_outside_project(self, temp_dir: Path):
        """Test cache fails outside project."""
        os.chdir(temp_dir)
        result = runner.invoke(app, ["cache"])

        assert result.exit_code != 0
