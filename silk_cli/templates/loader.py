"""
Template loader for SILK projects.

Handles loading and substituting templates for project initialization.
"""

import re
from importlib import resources
from pathlib import Path
from typing import Optional

# SILK project directory structure
SILK_PROJECT_DIRS = [
    "00-instructions-llm",
    "01-Manuscrit",
    "02-Personnages/Principaux",
    "02-Personnages/Secondaires",
    "03-Lieux",
    "04-Concepts",
    "07-timeline",
    "10-Lore",
    "20-Pitch-Editeurs",
    "21-Planning",
    "50-Sessions-Claude",
    "60-idees-tome-2",
    "99-Templates",
    "formats",
    "outputs/context",
    "outputs/publish",
    "outputs/temp",
]

# Available genres
AVAILABLE_GENRES = [
    "polar-psychologique",
    "fantasy",
    "romance",
    "literary",
    "thriller",
]

GENRE_DESCRIPTIONS = {
    "polar-psychologique": "Polar sophistiqué avec éléments psychologiques",
    "fantasy": "Fantasy/fantastique avec worldbuilding",
    "romance": "Romance/sentiment avec développement relationnel",
    "literary": "Littérature générale/contemporaine",
    "thriller": "Thriller/suspense action",
}


def get_available_genres() -> list[str]:
    """Get list of available genre templates."""
    return AVAILABLE_GENRES.copy()


def get_genre_description(genre: str) -> str:
    """Get description for a genre."""
    return GENRE_DESCRIPTIONS.get(genre, "Genre littéraire")


def substitute_variables(content: str, variables: dict[str, str]) -> str:
    """
    Substitute template variables in content.

    Variables are in the format {{VARIABLE_NAME}} or {{VARIABLE:+suffix}}.

    Args:
        content: Template content with variables.
        variables: Dictionary of variable names to values.

    Returns:
        Content with variables substituted.
    """
    result = content

    # Handle conditional substitution: {{VAR:+text if VAR exists}}
    def replace_conditional(match: re.Match[str]) -> str:
        var_name = match.group(1)
        suffix = match.group(2)
        value = variables.get(var_name, "")
        if value:
            return suffix.replace(f"{{{{{var_name}}}}}", value)
        return ""

    result = re.sub(r"\{\{(\w+):\+([^}]+)\}\}", replace_conditional, result)

    # Handle simple substitution: {{VAR}}
    for var_name, value in variables.items():
        result = result.replace(f"{{{{{var_name}}}}}", str(value) if value else "")

    return result


def get_template_path(template_name: str, category: str = "common") -> Optional[Path]:
    """
    Get path to a template file.

    Args:
        template_name: Name of the template (without extension).
        category: Template category (common, genres/polar-psychologique, formats, etc.).

    Returns:
        Path to template file or None if not found.
    """
    # Try to find in package data
    try:
        templates_dir = resources.files("silk_cli.data.templates")
        base_path = Path(str(templates_dir))

        template_path = base_path / category / f"{template_name}.template"
        if template_path.exists():
            return template_path

        # Try .md extension
        template_path = base_path / category / f"{template_name}.md"
        if template_path.exists():
            return template_path

        # Try .yaml extension
        template_path = base_path / category / f"{template_name}.yaml"
        if template_path.exists():
            return template_path
    except (TypeError, FileNotFoundError):
        pass

    return None


def load_template(template_name: str, category: str = "common") -> Optional[str]:
    """
    Load a template file content.

    Args:
        template_name: Name of the template.
        category: Template category.

    Returns:
        Template content or None if not found.
    """
    template_path = get_template_path(template_name, category)
    if template_path and template_path.exists():
        return template_path.read_text(encoding="utf-8")
    return None


def create_project_structure(project_dir: Path) -> None:
    """
    Create the SILK project directory structure.

    Args:
        project_dir: Root directory for the project.
    """
    for dir_path in SILK_PROJECT_DIRS:
        (project_dir / dir_path).mkdir(parents=True, exist_ok=True)


def sanitize_directory_name(name: str) -> str:
    """
    Convert a project name to a valid directory name.

    Args:
        name: Original project name.

    Returns:
        Sanitized directory name.
    """
    # Replace spaces with hyphens
    result = name.replace(" ", "-")
    # Convert to lowercase
    result = result.lower()
    # Keep only alphanumeric, hyphens, and underscores
    result = re.sub(r"[^a-z0-9_-]", "", result)
    # Remove leading/trailing hyphens
    result = result.strip("-")
    return result or "silk-project"
