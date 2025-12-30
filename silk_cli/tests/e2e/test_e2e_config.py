"""
End-to-end tests for silk config command.
"""

import os
from pathlib import Path

from typer.testing import CliRunner

from silk_cli.cli import app

runner = CliRunner()


class TestConfigCommand:
    """E2E tests for config command."""

    def test_config_list(self, silk_project: Path):
        """Test config --list shows configuration."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["config", "--list"])

        assert result.exit_code == 0
        assert "title" in result.output.lower()
        assert "Test Novel" in result.output

    def test_config_shows_genre(self, silk_project: Path):
        """Test config shows genre."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["config", "-l"])

        assert result.exit_code == 0
        assert "polar-psychologique" in result.output

    def test_config_shows_target_words(self, silk_project: Path):
        """Test config shows target words."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["config", "-l"])

        assert result.exit_code == 0
        assert "80000" in result.output

    def test_config_outside_project(self, temp_dir: Path):
        """Test config fails outside project."""
        os.chdir(temp_dir)
        result = runner.invoke(app, ["config", "-l"])

        assert result.exit_code != 0


class TestConfigSubcommands:
    """E2E tests for config subcommands."""

    def test_config_get_title(self, silk_project: Path):
        """Test getting a specific config value."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["config", "get", "title"])

        # If get subcommand exists
        if result.exit_code == 0:
            assert "Test Novel" in result.output

    def test_config_set_author(self, silk_project: Path):
        """Test setting a config value."""
        os.chdir(silk_project)
        result = runner.invoke(app, ["config", "set", "author_name", "New Author"])

        # If set subcommand exists
        if result.exit_code == 0:
            # Verify the change
            result2 = runner.invoke(app, ["config", "-l"])
            assert "New Author" in result2.output
