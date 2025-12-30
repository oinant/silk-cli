"""
Pandoc interface for SILK publishing.

Handles PDF, EPUB, and HTML generation via Pandoc.
"""

import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from silk_cli.publishing.transformers import OutputType


@dataclass
class PandocOptions:
    """Options for Pandoc generation."""

    output_type: OutputType = OutputType.PDF
    include_toc: bool = True
    toc_depth: int = 1
    french_quotes: bool = False
    auto_dashes: bool = False

    # PDF specific
    pdf_engine: str = "xelatex"

    # EPUB specific
    epub_cover: Optional[Path] = None

    # HTML specific
    standalone: bool = True
    self_contained: bool = True


@dataclass
class PandocResult:
    """Result of Pandoc generation."""

    success: bool
    output_file: Optional[Path] = None
    error_message: str = ""
    chapters_count: int = 0
    duration_ms: int = 0


def check_pandoc_available() -> bool:
    """Check if Pandoc is installed and available."""
    return shutil.which("pandoc") is not None


def check_xelatex_available() -> bool:
    """Check if XeLaTeX is installed and available."""
    return shutil.which("xelatex") is not None


def get_pandoc_version() -> Optional[str]:
    """Get Pandoc version string."""
    try:
        result = subprocess.run(
            ["pandoc", "--version"],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            # First line contains version
            return result.stdout.split("\n")[0]
    except FileNotFoundError:
        pass
    return None


def run_pandoc(
    input_files: list[Path],
    output_file: Path,
    metadata_file: Optional[Path] = None,
    options: Optional[PandocOptions] = None,
) -> PandocResult:
    """
    Run Pandoc to generate output.

    Args:
        input_files: List of markdown input files.
        output_file: Output file path.
        metadata_file: Optional YAML metadata file.
        options: Pandoc generation options.

    Returns:
        PandocResult with success status and details.
    """
    import time

    start_time = time.time()
    options = options or PandocOptions()

    # Build Pandoc command
    cmd = ["pandoc"]

    # Add metadata file first if provided
    if metadata_file and metadata_file.exists():
        cmd.append(str(metadata_file))

    # Add input files
    for f in input_files:
        cmd.append(str(f))

    # Output file
    cmd.extend(["-o", str(output_file)])

    # Input format with smart typography
    cmd.extend(["-f", "markdown+smart"])

    # Output-specific options
    if options.output_type == OutputType.PDF:
        cmd.extend(["--pdf-engine", options.pdf_engine])
        cmd.extend(["--highlight-style", "tango"])

    elif options.output_type == OutputType.EPUB:
        cmd.extend(["--split-level", "2"])
        if options.epub_cover and options.epub_cover.exists():
            cmd.extend(["--epub-cover-image", str(options.epub_cover)])

    elif options.output_type == OutputType.HTML:
        if options.standalone:
            cmd.append("--standalone")
        if options.self_contained:
            cmd.append("--embed-resources")

    # Table of contents
    if options.include_toc:
        cmd.append("--toc")
        cmd.extend(["--toc-depth", str(options.toc_depth)])

    # Run Pandoc
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=300,  # 5 minute timeout
        )

        duration_ms = int((time.time() - start_time) * 1000)

        if result.returncode == 0 and output_file.exists():
            return PandocResult(
                success=True,
                output_file=output_file,
                chapters_count=len(input_files),
                duration_ms=duration_ms,
            )
        else:
            error_msg = result.stderr or result.stdout or "Unknown error"
            return PandocResult(
                success=False,
                error_message=f"Pandoc error (code {result.returncode}): {error_msg}",
                duration_ms=duration_ms,
            )

    except subprocess.TimeoutExpired:
        return PandocResult(
            success=False,
            error_message="Pandoc timed out after 5 minutes",
        )
    except FileNotFoundError:
        return PandocResult(
            success=False,
            error_message="Pandoc not found. Install from https://pandoc.org/installing.html",
        )


def _yaml_escape(value: str) -> str:
    """Escape a string for safe YAML output."""
    # If contains special chars, use single quotes and escape internal quotes
    if any(c in value for c in '":{}[]#&*!|>\'\\'):
        escaped = value.replace("'", "''")
        return f"'{escaped}'"
    return value


def create_metadata_file(
    output_dir: Path,
    title: str,
    author: str,
    language: str = "fr",
    format_config: Optional[dict] = None,
    include_toc: bool = True,
) -> Path:
    """
    Create a YAML metadata file for Pandoc.

    Args:
        output_dir: Directory to create the file in.
        title: Document title.
        author: Author name.
        language: Language code.
        format_config: Additional format configuration (geometry, fonts, etc.).
        include_toc: Whether to include table of contents settings.

    Returns:
        Path to the created metadata file.
    """
    metadata_path = output_dir / "silk_metadata.yaml"

    lines = [
        "---",
        f"title: {_yaml_escape(title)}",
        f"author: {_yaml_escape(author)}",
        f"lang: {language}",
    ]

    # Add format configuration (filter out reserved keys)
    reserved_keys = {"title", "author", "lang", "toc", "toc-depth", "toc-title",
                     "output_type", "custom_structure", "variables", "css"}
    if format_config:
        for key, value in format_config.items():
            if key in reserved_keys:
                continue
            if isinstance(value, str) and "\n" in value:
                # Multi-line value (like header-includes)
                lines.append(f"{key}: |")
                for line in value.split("\n"):
                    lines.append(f"  {line}")
            elif isinstance(value, str):
                lines.append(f"{key}: {_yaml_escape(value)}")
            else:
                lines.append(f"{key}: {value}")

    # TOC settings
    if include_toc:
        lines.append("toc: true")
        lines.append("toc-depth: 1")
        lines.append(f"toc-title: {_yaml_escape('Table des matières')}")

    lines.append("---")

    metadata_path.write_text("\n".join(lines), encoding="utf-8")
    return metadata_path


def load_format_config(format_file: Path) -> dict:
    """
    Load format configuration from a YAML file.

    Args:
        format_file: Path to format YAML file.

    Returns:
        Dictionary of format settings.
    """
    import yaml

    if not format_file.exists():
        return {}

    try:
        content = format_file.read_text(encoding="utf-8")
        return yaml.safe_load(content) or {}
    except Exception:
        return {}
