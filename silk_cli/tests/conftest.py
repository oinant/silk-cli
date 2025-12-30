"""
Pytest fixtures for SILK CLI tests.
"""

import tempfile
from pathlib import Path
from typing import Generator

import pytest


@pytest.fixture
def temp_dir() -> Generator[Path, None, None]:
    """Create a temporary directory for tests."""
    with tempfile.TemporaryDirectory() as td:
        yield Path(td)


@pytest.fixture
def silk_project(temp_dir: Path) -> Path:
    """Create a minimal SILK project structure."""
    # Create .silk directory and config
    silk_dir = temp_dir / ".silk"
    silk_dir.mkdir()

    config_content = """TITLE="Test Novel"
GENRE="polar-psychologique"
LANGUAGE="fr"
TARGET_WORDS=80000
TARGET_CHAPTERS=30
AUTHOR_NAME="Test Author"
MANUSCRIPT_SEPARATOR="## manuscrit"
"""
    (silk_dir / "config").write_text(config_content, encoding="utf-8")

    # Create manuscript directory with chapters
    manuscript_dir = temp_dir / "01-Manuscrit"
    manuscript_dir.mkdir()

    # Chapter 1 (simple)
    ch1_content = """# Ch.01 : Premier Chapitre

## Objectifs
- Test objectif

## manuscrit

Ceci est le contenu du premier chapitre.

Il contient plusieurs paragraphes pour tester le comptage de mots.

---

Une nouvelle scène commence ici avec une transition.

~

Un blanc typographique.

*Paris - Matin*

Une indication temporelle.
"""
    (manuscript_dir / "Ch01.md").write_text(ch1_content, encoding="utf-8")

    # Chapter 2 (multi-part)
    ch2_content = """# Ch.02 : Deuxième Chapitre

## manuscrit

Début du chapitre deux, première partie.
"""
    (manuscript_dir / "Ch02.md").write_text(ch2_content, encoding="utf-8")

    ch2_part1 = """# Ch.02 : Deuxième Chapitre (suite)

## manuscrit

Suite du chapitre deux, deuxième partie.
"""
    (manuscript_dir / "Ch02-1.md").write_text(ch2_part1, encoding="utf-8")

    # Chapter 3 (with dialogue)
    ch3_content = """# Ch.03 : Troisième Chapitre

## manuscrit

- Bonjour, dit-il.
- Bonsoir, répondit-elle.

"Citation en anglais" pour tester les guillemets.
"""
    (manuscript_dir / "Ch03.md").write_text(ch3_content, encoding="utf-8")

    # Create other required directories
    (temp_dir / "02-Personnages" / "Principaux").mkdir(parents=True)
    (temp_dir / "02-Personnages" / "Secondaires").mkdir(parents=True)
    (temp_dir / "03-Lieux").mkdir()
    (temp_dir / "04-Concepts").mkdir()
    (temp_dir / "outputs" / "context").mkdir(parents=True)
    (temp_dir / "outputs" / "publish").mkdir(parents=True)
    (temp_dir / "outputs" / "temp").mkdir(parents=True)

    return temp_dir


@pytest.fixture
def sample_chapter_content() -> str:
    """Sample chapter content for unit tests."""
    return """# Ch.05 : Test Chapter

## Objectifs SILK
- Objectif 1
- Objectif 2

## Notes
Some notes here.

## manuscrit

This is the actual manuscript content.

It has multiple paragraphs.

---

A scene break here.

~

A typographic space.

*London - Evening*

A time indicator.

- Hello, he said.
- Goodbye, she replied.
"""


@pytest.fixture
def sample_config_content() -> str:
    """Sample config file content."""
    return """TITLE="L'Araignée"
GENRE="polar-psychologique"
LANGUAGE="fr"
TARGET_WORDS=80000
TARGET_CHAPTERS=30
AUTHOR_NAME="Alex Servat"
AUTHOR_PSEUDO="Alex S."
MANUSCRIPT_SEPARATOR="## manuscrit"
"""
