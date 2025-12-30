"""
End-to-end tests for silk init command.
"""

import os
from pathlib import Path

import pytest
from typer.testing import CliRunner

from silk_cli.cli import app

runner = CliRunner()


class TestInitCommand:
    """E2E tests for init command."""

    def test_init_creates_project(self, temp_dir: Path):
        """Test that init creates a new project."""
        os.chdir(temp_dir)

        result = runner.invoke(
            app,
            ["init", "Mon Roman", "--genre", "fantasy", "-y"],
        )

        assert result.exit_code == 0
        project_dir = temp_dir / "mon-roman"
        assert project_dir.exists()
        assert (project_dir / ".silk").exists()
        assert (project_dir / ".silk" / "config").exists()
        assert (project_dir / "01-Manuscrit").exists()

    def test_init_config_content(self, temp_dir: Path):
        """Test that config contains correct values."""
        os.chdir(temp_dir)

        runner.invoke(
            app,
            ["init", "Test Title", "--genre", "thriller", "--author", "John Doe", "-y"],
        )

        project_dir = temp_dir / "test-title"
        config_path = project_dir / ".silk" / "config"
        assert config_path.exists()

        config_content = config_path.read_text()
        assert "Test Title" in config_content
        assert "thriller" in config_content
        assert "John Doe" in config_content

    def test_init_creates_directories(self, temp_dir: Path):
        """Test that init creates required directories."""
        os.chdir(temp_dir)

        runner.invoke(
            app,
            ["init", "Directory Test", "-y"],
        )

        project_dir = temp_dir / "directory-test"
        expected_dirs = [
            "01-Manuscrit",
            "02-Personnages",
            "03-Lieux",
            "04-Concepts",
            "outputs",
        ]

        for dir_name in expected_dirs:
            assert (project_dir / dir_name).exists(), f"{dir_name} should exist"

    def test_init_with_words_target(self, temp_dir: Path):
        """Test init with custom word target."""
        os.chdir(temp_dir)

        runner.invoke(
            app,
            ["init", "Words Test", "--words", "100000", "-y"],
        )

        project_dir = temp_dir / "words-test"
        config_content = (project_dir / ".silk" / "config").read_text()
        assert "100000" in config_content

    def test_init_creates_subproject(self, silk_project: Path):
        """Test that init can create a subproject inside existing project."""
        os.chdir(silk_project)
        result = runner.invoke(
            app,
            ["init", "New Project", "-y"],
        )

        # Should succeed and create subdirectory
        assert result.exit_code == 0
        assert (silk_project / "new-project" / ".silk").exists()


class TestInitGenres:
    """E2E tests for genre handling in init."""

    @pytest.mark.parametrize("genre", [
        "polar-psychologique",
        "fantasy",
        "romance",
        "literary",
        "thriller",
    ])
    def test_all_genres(self, temp_dir: Path, genre: str):
        """Test all valid genres can be used."""
        os.chdir(temp_dir)

        result = runner.invoke(
            app,
            ["init", f"Test {genre}", "--genre", genre, "-y"],
        )

        assert result.exit_code == 0
        # Project name is sanitized
        project_name = f"test-{genre}"
        project_dir = temp_dir / project_name
        config_content = (project_dir / ".silk" / "config").read_text()
        assert genre in config_content
