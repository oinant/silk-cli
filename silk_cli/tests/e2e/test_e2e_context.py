"""
End-to-end tests for silk context command.
"""

import os
from pathlib import Path

from typer.testing import CliRunner

from silk_cli.cli import app

runner = CliRunner()


class TestContextCommand:
    """E2E tests for context command."""

    def test_context_with_predefined_prompt(self, silk_project: Path):
        """Test context generation with predefined prompt."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["context", "-p", "coherence", "--chapters", "1"])

        assert result.exit_code == 0
        context_file = silk_project / "outputs" / "context" / "silk-context.md"
        assert context_file.exists()

    def test_context_nocontext_mode(self, silk_project: Path):
        """Test context with nocontext mode."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["context", "-p", "coherence", "--mode", "nocontext"])

        assert result.exit_code == 0

    def test_context_chapter_range(self, silk_project: Path):
        """Test context with chapter range."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["context", "-p", "coherence", "--chapters", "1-2"])

        assert result.exit_code == 0

    def test_context_outside_project(self, temp_dir: Path):
        """Test context fails outside project."""
        os.chdir(temp_dir)
        result = runner.invoke(app, ["context", "-p", "coherence"])

        assert result.exit_code != 0
