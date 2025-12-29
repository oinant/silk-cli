"""
Text transformations for SILK manuscript processing.

Handles SILK-specific conventions like scene breaks, typographic spaces,
French quotes, and em-dashes.
"""

import re
from enum import Enum


class OutputType(str, Enum):
    """Output format types."""
    PDF = "pdf"
    EPUB = "epub"
    HTML = "html"


def transform_manuscript(
    content: str,
    output_type: OutputType = OutputType.PDF,
    french_quotes: bool = False,
    auto_dashes: bool = False,
) -> str:
    """
    Transform manuscript content with SILK conventions.

    SILK conventions:
    - `---` → Scene transition (*** or LaTeX centered)
    - `~` → Typographic space (blank line or vspace)
    - `*text with dash*` → Time/place indicator (centered italic)
    - `[[link|text]]` or `[[link]]` → Obsidian links converted to plain text

    Args:
        content: Raw manuscript content.
        output_type: Target output format.
        french_quotes: Convert straight quotes to French guillemets.
        auto_dashes: Convert hyphens to em-dashes for dialogue.

    Returns:
        Transformed content.
    """
    lines = content.split("\n")
    result_lines = []

    for line in lines:
        transformed = transform_line(
            line, output_type, french_quotes, auto_dashes
        )
        result_lines.append(transformed)

    return "\n".join(result_lines)


def transform_line(
    line: str,
    output_type: OutputType,
    french_quotes: bool,
    auto_dashes: bool,
) -> str:
    """Transform a single line with SILK conventions."""
    stripped = line.strip()

    # Scene transition: ---
    if stripped == "---":
        return _transform_scene_break(output_type)

    # Typographic space: ~
    if stripped == "~":
        return _transform_typographic_space(output_type)

    # Time/place indicator: *text with dash*
    if _is_time_indicator(stripped):
        return _transform_time_indicator(stripped, output_type)

    # Empty line
    if not stripped:
        return ""

    # Normal line processing
    processed = line

    # French quotes
    if french_quotes:
        processed = _convert_french_quotes(processed)

    # Auto dashes for dialogue
    if auto_dashes:
        processed = _convert_dashes(processed, output_type)

    # Convert Obsidian links
    processed = _convert_obsidian_links(processed)

    # Add trailing spaces for markdown line breaks (PDF only)
    if output_type == OutputType.PDF:
        # Add noindent for dialogue lines
        if processed.lstrip().startswith(('"', '«', '—', '"')):
            processed = f"\\noindent {processed}  "
        else:
            processed = f"{processed}  "

    return processed


def _transform_scene_break(output_type: OutputType) -> str:
    """Transform scene break marker."""
    if output_type == OutputType.PDF:
        return "\n\\begin{center}\n\\vspace{1cm}\n***\n\\vspace{1cm}\n\\end{center}\n"
    else:
        return "\n***\n"


def _transform_typographic_space(output_type: OutputType) -> str:
    """Transform typographic space marker."""
    if output_type == OutputType.PDF:
        return "\n\\vspace{0.5cm}\n"
    else:
        return "\n"


def _is_time_indicator(line: str) -> bool:
    """Check if line is a time/place indicator (*text - text*)."""
    return (
        line.startswith("*")
        and line.endswith("*")
        and "-" in line
        and len(line) > 2
    )


def _transform_time_indicator(line: str, output_type: OutputType) -> str:
    """Transform time/place indicator to centered italic."""
    # Remove surrounding asterisks
    inner_text = line[1:-1]

    if output_type == OutputType.PDF:
        return f"\n\\begin{{center}}\n\\textit{{{inner_text}}}\n\\end{{center}}\n"
    else:
        return f"\n*{inner_text}*\n"


def _convert_french_quotes(text: str) -> str:
    """Convert straight quotes to French guillemets."""
    # Pattern: "text" -> « text »
    result = re.sub(r'"([^"]*)"', r'« \1 »', text)
    return result


def _convert_dashes(text: str, output_type: OutputType) -> str:
    """Convert hyphens to em-dashes for dialogue."""
    if output_type == OutputType.PDF:
        # LaTeX em-dash
        result = text.replace("—", "---")
        if text.lstrip().startswith("- "):
            result = re.sub(r"^(\s*)- ", r"\1--- ", result)
    else:
        # Unicode em-dash for EPUB/HTML
        result = text.replace("---", "—")
        if text.lstrip().startswith("- "):
            result = re.sub(r"^(\s*)- ", r"\1— ", result)
    return result


def _convert_obsidian_links(text: str) -> str:
    """Convert Obsidian wiki links to plain text."""
    # [[link|display]] -> display
    result = re.sub(r'\[\[([^|\]]*)\|([^\]]*)\]\]', r'\2', text)
    # [[link]] -> link
    result = re.sub(r'\[\[([^\]]*)\]\]', r'\1', result)
    return result


def create_chapter_header(
    chapter_num: int,
    title: str,
    output_type: OutputType,
    is_first: bool = False,
) -> str:
    """
    Create chapter header with optional page break.

    Args:
        chapter_num: Chapter number.
        title: Chapter title.
        output_type: Target output format.
        is_first: True if this is the first chapter (no page break).

    Returns:
        Chapter header markdown/LaTeX.
    """
    header_parts = []

    # Page break for non-first chapters (PDF only)
    if not is_first and output_type == OutputType.PDF:
        header_parts.append("\\newpage\n")

    # Chapter heading
    header_parts.append(f"# {title}\n")

    return "\n".join(header_parts)
