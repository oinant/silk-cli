"""
Configuration models for SILK projects.

Handles loading and saving of .silk/config files.
"""

import re
from pathlib import Path
from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator

Genre = Literal[
    "polar-psychologique",
    "fantasy",
    "romance",
    "literary",
    "thriller",
]

Language = Literal["fr", "en", "es", "de", "it"]


class SilkConfig(BaseModel):
    """Configuration for a SILK project."""

    title: str = Field(default="Untitled", min_length=1, description="Novel title")
    genre: Genre = Field(default="polar-psychologique", description="Literary genre")
    language: Language = Field(default="fr", description="Language code")
    target_words: int = Field(default=80000, ge=1000, le=1000000, description="Word count target")
    target_chapters: int = Field(default=30, ge=1, le=200, description="Chapter count target")
    author_name: str = Field(default="", description="Author's real name")
    author_pseudo: Optional[str] = Field(default=None, description="Author's pen name")
    cover: Optional[Path] = Field(default=None, description="Cover image path")
    manuscript_separator: str = Field(
        default="## manuscrit",
        description="Separator between metadata and manuscript content",
    )
    default_format: str = Field(default="digital", description="Default publish format")

    @field_validator("language")
    @classmethod
    def validate_language(cls, v: str) -> str:
        """Ensure language is lowercase."""
        return v.lower()

    @classmethod
    def from_file(cls, config_path: Path) -> "SilkConfig":
        """
        Load configuration from a .silk/config file.

        The file format is KEY="VALUE" or KEY=VALUE per line.
        """
        if not config_path.exists():
            return cls()

        config_data: dict[str, str] = {}
        content = config_path.read_text(encoding="utf-8")

        # Parse KEY="VALUE" or KEY=VALUE format
        pattern = re.compile(r'^(\w+)=["\']?([^"\'\n]*)["\']?$', re.MULTILINE)
        for match in pattern.finditer(content):
            key = match.group(1).lower()
            value = match.group(2)
            config_data[key] = value

        # Map bash-style keys to Pydantic field names
        field_mapping = {
            "title": "title",
            "genre": "genre",
            "language": "language",
            "target_words": "target_words",
            "target_chapters": "target_chapters",
            "author_name": "author_name",
            "author_pseudo": "author_pseudo",
            "cover": "cover",
            "manuscript_separator": "manuscript_separator",
            "default_format": "default_format",
        }

        mapped_data: dict[str, str | int | Path | None] = {}
        for bash_key, pydantic_key in field_mapping.items():
            if bash_key in config_data:
                value = config_data[bash_key]
                # Convert numeric fields
                if pydantic_key in ("target_words", "target_chapters"):
                    mapped_data[pydantic_key] = int(value) if value.isdigit() else 80000
                elif pydantic_key == "cover" and value:
                    mapped_data[pydantic_key] = Path(value)
                else:
                    mapped_data[pydantic_key] = value

        return cls(**mapped_data)

    def save(self, config_path: Path) -> None:
        """Save configuration to a .silk/config file."""
        config_path.parent.mkdir(parents=True, exist_ok=True)

        lines = [
            f'TITLE="{self.title}"',
            f'GENRE="{self.genre}"',
            f'LANGUAGE="{self.language}"',
            f"TARGET_WORDS={self.target_words}",
            f"TARGET_CHAPTERS={self.target_chapters}",
            f'AUTHOR_NAME="{self.author_name}"',
        ]

        if self.author_pseudo:
            lines.append(f'AUTHOR_PSEUDO="{self.author_pseudo}"')
        if self.cover:
            lines.append(f'COVER="{self.cover}"')
        if self.manuscript_separator != "## manuscrit":
            lines.append(f'MANUSCRIPT_SEPARATOR="{self.manuscript_separator}"')
        if self.default_format != "digital":
            lines.append(f'DEFAULT_FORMAT="{self.default_format}"')

        config_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
