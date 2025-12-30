"""
SILK project detection and management.

Handles finding and validating SILK project structures.
"""

from pathlib import Path
from typing import Optional

from silk_cli.models.config import SilkConfig

# Required directories for a valid SILK project
SILK_REQUIRED_DIRS = ["01-Manuscrit", "02-Personnages", "04-Concepts"]


class SilkProjectNotFoundError(Exception):
    """Raised when no SILK project is found in the directory tree."""

    pass


def is_silk_project(path: Path) -> bool:
    """
    Check if a directory is a valid SILK project.

    A valid SILK project must contain:
    - 01-Manuscrit/
    - 02-Personnages/
    - 04-Concepts/

    Args:
        path: Directory to check.

    Returns:
        True if the directory is a valid SILK project.
    """
    return all((path / d).is_dir() for d in SILK_REQUIRED_DIRS)


def find_silk_root(start: Optional[Path] = None) -> Optional[Path]:
    """
    Find the root of a SILK project by walking up the directory tree.

    Args:
        start: Starting directory (defaults to current working directory).

    Returns:
        Path to the SILK project root, or None if not found.
    """
    current = (start or Path.cwd()).resolve()

    while current != current.parent:
        if is_silk_project(current):
            return current
        current = current.parent

    # Check the root itself
    if is_silk_project(current):
        return current

    return None


def ensure_silk_context(start: Optional[Path] = None) -> Path:
    """
    Ensure we are in a SILK project and return its root.

    Args:
        start: Starting directory (defaults to current working directory).

    Returns:
        Path to the SILK project root.

    Raises:
        SilkProjectNotFoundError: If no SILK project is found.
    """
    root = find_silk_root(start)
    if root is None:
        raise SilkProjectNotFoundError(
            "Not in a SILK project. Use 'silk init' to create a new project."
        )
    return root


def load_project_config(root: Optional[Path] = None) -> tuple[Path, SilkConfig]:
    """
    Load the configuration for a SILK project.

    Args:
        root: Project root (will be detected if not provided).

    Returns:
        Tuple of (project_root, config).

    Raises:
        SilkProjectNotFoundError: If no SILK project is found.
    """
    project_root = root or ensure_silk_context()
    config_path = project_root / ".silk" / "config"
    config = SilkConfig.from_file(config_path)
    return project_root, config


def get_manuscript_dir(root: Path) -> Path:
    """Get the manuscript directory for a project."""
    return root / "01-Manuscrit"


def get_characters_dir(root: Path) -> Path:
    """Get the characters directory for a project."""
    return root / "02-Personnages"


def get_concepts_dir(root: Path) -> Path:
    """Get the concepts directory for a project."""
    return root / "04-Concepts"


def get_outputs_dir(root: Path) -> Path:
    """Get the outputs directory for a project (created if needed)."""
    outputs = root / "outputs"
    outputs.mkdir(exist_ok=True)
    return outputs


def get_config_dir(root: Path) -> Path:
    """Get the .silk config directory for a project (created if needed)."""
    config_dir = root / ".silk"
    config_dir.mkdir(exist_ok=True)
    return config_dir
