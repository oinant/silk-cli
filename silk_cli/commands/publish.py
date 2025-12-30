"""
SILK publish command - Generate PDF, EPUB, and HTML from manuscript.
"""

from datetime import datetime
from pathlib import Path
from typing import Annotated, Optional

import typer
from rich.console import Console
from rich.panel import Panel

from silk_cli.core.chapters import collect_chapters, extract_manuscript_content
from silk_cli.core.project import get_manuscript_dir, get_outputs_dir, load_project_config
from silk_cli.models.chapter import ChapterRange
from silk_cli.publishing.pandoc import (
    PandocOptions,
    check_pandoc_available,
    check_xelatex_available,
    create_metadata_file,
    load_format_config,
    run_pandoc,
)
from silk_cli.publishing.transformers import (
    OutputType,
    create_chapter_header,
    transform_manuscript,
)

console = Console()

# Available formats
FORMATS = {
    "digital": {"type": "pdf", "desc": "Screen format (6\"x9\")"},
    "book": {"type": "pdf", "desc": "Print book (A5)"},
    "iphone": {"type": "pdf", "desc": "Mobile (4.7\"x8.3\")"},
    "kindle": {"type": "pdf", "desc": "E-reader optimized"},
    "epub": {"type": "epub", "desc": "EPUB reflowable"},
    "html": {"type": "html", "desc": "HTML standalone"},
}


def publish(
    format_name: Annotated[
        str,
        typer.Option("--format", "-f", help="Output format (digital, book, epub, html)"),
    ] = "digital",
    chapters: Annotated[
        Optional[str],
        typer.Option("--chapters", "-ch", help="Chapter range (e.g., '1-10', 'all')"),
    ] = None,
    output_name: Annotated[
        Optional[str],
        typer.Option("--output", "-o", help="Custom output filename"),
    ] = None,
    french_quotes: Annotated[
        bool,
        typer.Option("--french-quotes", help="Convert quotes to French guillemets « »"),
    ] = False,
    auto_dashes: Annotated[
        bool,
        typer.Option("--auto-dashes", help="Convert hyphens to em-dashes for dialogue"),
    ] = False,
    no_toc: Annotated[
        bool,
        typer.Option("--no-toc", help="Exclude table of contents"),
    ] = False,
    with_stats: Annotated[
        bool,
        typer.Option("--with-stats", help="Include statistics page"),
    ] = False,
    dry_run: Annotated[
        bool,
        typer.Option("--dry-run", help="Simulate without generating output"),
    ] = False,
) -> None:
    """
    Generate PDF, EPUB, or HTML from your manuscript.

    Processes chapters after the manuscript separator, applies SILK conventions
    (scene breaks, typographic spaces), and generates professional output via Pandoc.

    Examples:
        silk publish                        # Default digital PDF
        silk publish -f epub                # EPUB format
        silk publish -f book --french-quotes # Print format with French quotes
        silk publish --chapters 1-10        # First 10 chapters only
    """
    # Validate format
    if format_name not in FORMATS:
        console.print(f"[red]Unknown format:[/red] {format_name}")
        console.print(f"[dim]Available: {', '.join(FORMATS.keys())}[/dim]")
        raise typer.Exit(1)

    format_info = FORMATS[format_name]
    output_type = OutputType(format_info["type"])

    # Check dependencies
    if not dry_run:
        if not check_pandoc_available():
            console.print("[red]Pandoc not found.[/red]")
            console.print("[dim]Install from: https://pandoc.org/installing.html[/dim]")
            raise typer.Exit(1)

        if output_type == OutputType.PDF and not check_xelatex_available():
            console.print("[red]XeLaTeX not found.[/red]")
            console.print("[dim]Install MacTeX: brew install --cask mactex[/dim]")
            raise typer.Exit(1)

    # Load project
    try:
        root, config = load_project_config()
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(1)

    # Parse chapter range
    manuscript_dir = get_manuscript_dir(root)
    chapter_range: Optional[ChapterRange] = None
    if chapters and chapters.lower() != "all":
        from silk_cli.core.chapters import get_max_chapter_number
        max_chapter = get_max_chapter_number(manuscript_dir)
        chapter_range = ChapterRange.parse(chapters, max_chapter)

    # Collect chapters
    groups = collect_chapters(
        manuscript_dir,
        config.manuscript_separator,
        chapter_range,
    )

    if not groups:
        console.print("[yellow]No chapters found with manuscript content.[/yellow]")
        raise typer.Exit(1)

    chapters_count = len(groups)
    console.print(f"[purple]SILK tisse votre {output_type.value.upper()}...[/purple]")
    console.print(f"[dim]Format: {format_name} | Chapitres: {chapters_count}[/dim]")

    if dry_run:
        _show_dry_run(groups, format_name, output_type)
        return

    # Generate output
    try:
        result = _generate_output(
            root=root,
            config=config,
            groups=groups,
            format_name=format_name,
            output_type=output_type,
            output_name=output_name,
            french_quotes=french_quotes,
            auto_dashes=auto_dashes,
            include_toc=not no_toc,
            with_stats=with_stats,
        )

        if result.success:
            _show_success(result, format_name, chapters_count, french_quotes, auto_dashes)
        else:
            console.print(f"[red]Error:[/red] {result.error_message}")
            raise typer.Exit(1)

    except Exception as e:
        console.print(f"[red]Error during generation:[/red] {e}")
        raise typer.Exit(1)


def _generate_output(
    root: Path,
    config,
    groups: dict,
    format_name: str,
    output_type: OutputType,
    output_name: Optional[str],
    french_quotes: bool,
    auto_dashes: bool,
    include_toc: bool,
    with_stats: bool,
):
    """Generate the actual output file."""

    outputs_dir = get_outputs_dir(root)
    publish_dir = outputs_dir / "publish"
    publish_dir.mkdir(parents=True, exist_ok=True)

    temp_dir = outputs_dir / "temp"
    temp_dir.mkdir(parents=True, exist_ok=True)

    # Generate output filename
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    extension = {"pdf": "pdf", "epub": "epub", "html": "html"}[output_type.value]

    if output_name:
        filename = f"{output_name}.{extension}"
    else:
        project_name = root.name
        filename = f"{project_name}_{format_name}_{timestamp}.{extension}"

    output_file = publish_dir / filename

    # Load format configuration
    format_file = root / "formats" / f"{format_name}.yaml"
    format_config = load_format_config(format_file) if format_file.exists() else {}

    # Create metadata file
    metadata_file = create_metadata_file(
        output_dir=temp_dir,
        title=config.title,
        author=config.author_name or "Unknown",
        language=config.language,
        format_config=format_config,
        include_toc=include_toc,
    )

    # Create chapter files
    chapter_files = []
    is_first = True

    for num in sorted(groups.keys()):
        group = groups[num]
        chapter_file = temp_dir / f"ch{num:02d}.md"

        # Build chapter content
        content_parts = []

        # Header
        header = create_chapter_header(
            chapter_num=num,
            title=group.title,
            output_type=output_type,
            is_first=is_first,
        )
        content_parts.append(header)

        # Content from all parts
        for chapter in group.chapters:
            raw_content = extract_manuscript_content(
                chapter.path,
                config.manuscript_separator,
            )
            if raw_content:
                transformed = transform_manuscript(
                    raw_content,
                    output_type=output_type,
                    french_quotes=french_quotes,
                    auto_dashes=auto_dashes,
                )
                content_parts.append(transformed)

        # Write chapter file
        chapter_file.write_text("\n".join(content_parts), encoding="utf-8")
        chapter_files.append(chapter_file)
        is_first = False

    # Add stats page if requested
    if with_stats:
        stats_file = temp_dir / "stats.md"
        _create_stats_page(stats_file, groups, config, output_type)
        chapter_files.insert(0, stats_file)

    # Run Pandoc
    options = PandocOptions(
        output_type=output_type,
        include_toc=include_toc,
        french_quotes=french_quotes,
        auto_dashes=auto_dashes,
    )

    if output_type == OutputType.EPUB and config.cover:
        cover_path = root / config.cover
        if cover_path.exists():
            options.epub_cover = cover_path

    result = run_pandoc(
        input_files=chapter_files,
        output_file=output_file,
        metadata_file=metadata_file,
        options=options,
    )

    # Cleanup temp files
    for f in chapter_files:
        f.unlink(missing_ok=True)
    metadata_file.unlink(missing_ok=True)

    return result


def _create_stats_page(
    output_file: Path,
    groups: dict,
    config,
    output_type: OutputType,
) -> None:
    """Create statistics page."""
    from silk_cli.core.statistics import calculate_manuscript_stats

    stats = calculate_manuscript_stats(groups, config.target_words)

    lines = []

    if output_type == OutputType.PDF:
        lines.append("\\newpage\n")

    lines.extend([
        "# Statistiques de Publication SILK",
        "",
        f"**Généré le:** {datetime.now().strftime('%d/%m/%Y à %H:%M:%S')}",
        "",
        f"**Projet:** {config.title}",
        "",
        f"**Chapitres:** {stats.total_chapters}",
        "",
        f"**Total mots:** {stats.total_words:,}",
        "",
        f"**Pages estimées:** {stats.estimated_pages}",
        "",
        f"**Position éditoriale:** {stats.editorial_category}",
        "",
        "---",
        "",
        "*Généré par SILK CLI - Smart Integrated Literary Kit*",
    ])

    output_file.write_text("\n".join(lines), encoding="utf-8")


def _show_dry_run(groups: dict, format_name: str, output_type: OutputType) -> None:
    """Show dry run summary."""
    console.print()
    console.print("[bold]Dry run - No output generated[/bold]")
    console.print()
    console.print(f"Format: [cyan]{format_name}[/cyan] ({output_type.value})")
    console.print(f"Chapters: [cyan]{len(groups)}[/cyan]")
    console.print()
    console.print("[bold]Chapters to include:[/bold]")
    for num in sorted(groups.keys()):
        group = groups[num]
        parts = f" ({group.parts_count} parts)" if group.is_multipart else ""
        console.print(f"  Ch{num:02d}: {group.title}{parts} [{group.total_words:,} words]")


def _show_success(
    result, format_name: str, chapters_count: int, french_quotes: bool, auto_dashes: bool
) -> None:
    """Show success message."""
    console.print()
    console.print(
        Panel(
            f"[green]Publication réussie ![/green]\n\n"
            f"[bold]Fichier:[/bold] {result.output_file}\n"
            f"[bold]Format:[/bold] {format_name}\n"
            f"[bold]Chapitres:[/bold] {chapters_count}\n"
            f"[bold]Durée:[/bold] {result.duration_ms}ms\n"
            + ("[dim]Guillemets français activés[/dim]\n" if french_quotes else "")
            + ("[dim]Tirets cadratins activés[/dim]\n" if auto_dashes else ""),
            title="SILK Publish",
            border_style="green",
        )
    )
