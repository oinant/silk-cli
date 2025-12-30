"""
SILK wordcount command - Manuscript statistics and progress tracking.
"""

import json
from typing import Annotated, Optional

import typer
from rich.console import Console
from rich.panel import Panel
from rich.progress import BarColumn, Progress, TextColumn
from rich.table import Table

from silk_cli.core.chapters import collect_chapters, get_max_chapter_number
from silk_cli.core.project import get_manuscript_dir, load_project_config
from silk_cli.core.statistics import (
    EDITORIAL_THRESHOLDS,
    ManuscriptStats,
    calculate_manuscript_stats,
    get_editorial_position,
)
from silk_cli.models.chapter import ChapterRange

console = Console()


def run_wordcount(
    target: Optional[int] = None,
    output_format: str = "table",
    summary_only: bool = False,
    chapters_spec: Optional[str] = None,
    show_projections: bool = True,
) -> None:
    """
    Analyze manuscript word count and progress.

    Automatically groups multi-part chapters (Ch01 + Ch01-1 = Ch01).
    """
    try:
        root, config = load_project_config()
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(1)

    # Determine target
    target_words = target or config.target_words

    # Parse chapter range if specified
    manuscript_dir = get_manuscript_dir(root)
    chapter_range: Optional[ChapterRange] = None
    if chapters_spec:
        max_chapter = get_max_chapter_number(manuscript_dir)
        chapter_range = ChapterRange.parse(chapters_spec, max_chapter)

    # Collect chapters
    groups = collect_chapters(
        manuscript_dir,
        config.manuscript_separator,
        chapter_range,
    )

    if not groups:
        console.print("[yellow]No chapters found with manuscript content.[/yellow]")
        console.print(
            f'[dim]Make sure chapters contain "{config.manuscript_separator}" separator.[/dim]'
        )
        raise typer.Exit(1)

    # Calculate statistics
    stats = calculate_manuscript_stats(groups, target_words)

    # Output based on format
    if summary_only or output_format == "summary":
        _output_summary(stats, config.title)
    elif output_format == "json":
        _output_json(stats)
    elif output_format == "csv":
        _output_csv(stats)
    else:
        _output_table(stats, config.title, show_projections=show_projections)


def _output_table(stats: ManuscriptStats, title: str, show_projections: bool) -> None:
    """Display statistics as a Rich table."""
    # Header
    console.print(
        Panel(
            f"[bold]{title}[/bold]\n"
            f"[dim]Objectif: {stats.target_words:,} mots[/dim]",
            title="SILK Analytics",
            border_style="purple",
        )
    )

    # Chapter table
    table = Table(show_header=True, header_style="bold cyan")
    table.add_column("Chapitre", style="cyan", width=10)
    table.add_column("Mots", justify="right", width=8)
    table.add_column("Titre", max_width=50)

    for chapter in stats.chapters:
        table.add_row(
            chapter.display_name,
            f"{chapter.words:,}",
            chapter.title[:50],
        )

    console.print(table)

    # Summary
    console.print()
    console.print(f"[bold]Total:[/bold] {stats.total_words:,} mots")
    console.print(f"[bold]Chapitres:[/bold] {stats.total_chapters}")
    console.print(f"[bold]Moyenne:[/bold] {stats.average_words_per_chapter:,.0f} mots/chapitre")

    if stats.min_chapter:
        console.print(
            f"[bold]Min:[/bold] {stats.min_chapter.display_name} ({stats.min_chapter.words:,} mots)"
        )
    if stats.max_chapter:
        console.print(
            f"[bold]Max:[/bold] {stats.max_chapter.display_name} ({stats.max_chapter.words:,} mots)"
        )

    # Progress bar
    console.print()
    with Progress(
        TextColumn("[bold blue]Progression"),
        BarColumn(bar_width=40),
        TextColumn("[bold]{task.percentage:.1f}%"),
        console=console,
    ) as progress:
        task = progress.add_task("", total=100)
        progress.update(task, completed=min(100, stats.completion_percent))

    # Editorial positioning
    category, pages, _ = get_editorial_position(stats.total_words)
    console.print(f"\n[bold]Position éditoriale:[/bold] {category} ({pages})")
    console.print(f"[bold]Pages estimées:[/bold] {stats.estimated_pages}")

    # Projections
    if show_projections and stats.words_remaining > 0:
        console.print()
        console.print(
            Panel(
                f"[bold]Mots restants:[/bold] {stats.words_remaining:,}\n"
                f"[bold]Par chapitre:[/bold] {stats.words_per_chapter_needed:,.0f} mots\n"
                f"[bold]Effort:[/bold] {stats.effort_emoji} {stats.effort_level}",
                title="Projections",
                border_style="blue",
            )
        )

    # Thresholds
    console.print()
    console.print("[dim]Seuils éditoriaux:[/dim]")
    for threshold, (name, pages) in sorted(EDITORIAL_THRESHOLDS.items()):
        marker = "→" if stats.total_words >= threshold else " "
        style = "green" if stats.total_words >= threshold else "dim"
        console.print(f"  [{style}]{marker} {threshold:,}: {name} ({pages})[/{style}]")


def _output_summary(stats: ManuscriptStats, title: str) -> None:
    """Display a one-line summary."""
    console.print(
        f"[bold]{title}[/bold]: "
        f"{stats.total_words:,}/{stats.target_words:,} mots "
        f"({stats.completion_percent:.1f}%) - "
        f"{stats.total_chapters} chapitres - "
        f"{stats.editorial_category}"
    )


def _output_json(stats: ManuscriptStats) -> None:
    """Output statistics as JSON."""
    data = {
        "total_words": stats.total_words,
        "total_chapters": stats.total_chapters,
        "target_words": stats.target_words,
        "completion_percent": round(stats.completion_percent, 2),
        "words_remaining": stats.words_remaining,
        "average_words_per_chapter": round(stats.average_words_per_chapter, 2),
        "editorial_category": stats.editorial_category,
        "estimated_pages": stats.estimated_pages,
        "chapters": [
            {
                "number": c.number,
                "title": c.title,
                "words": c.words,
                "parts": c.parts_count,
            }
            for c in stats.chapters
        ],
    }
    console.print_json(json.dumps(data, ensure_ascii=False, indent=2))


def _output_csv(stats: ManuscriptStats) -> None:
    """Output statistics as CSV."""
    print("chapter,words,title,parts")
    for c in stats.chapters:
        # Escape title for CSV
        title_escaped = c.title.replace('"', '""')
        print(f'{c.number},{c.words},"{title_escaped}",{c.parts_count}')


# Typer CLI wrapper
def wordcount(
    target: Annotated[
        Optional[int],
        typer.Option("--target", "-t", help="Target word count (overrides config)"),
    ] = None,
    output_format: Annotated[
        str,
        typer.Option("--format", "-f", help="Output format: table, summary, json, csv"),
    ] = "table",
    summary_only: Annotated[
        bool,
        typer.Option("--summary", "-s", help="Show only summary line"),
    ] = False,
    chapters: Annotated[
        Optional[str],
        typer.Option("--chapters", "-ch", help="Chapter range (e.g., '1-10', '5,12,18-20')"),
    ] = None,
    no_projections: Annotated[
        bool,
        typer.Option("--no-projections", help="Hide projections panel"),
    ] = False,
) -> None:
    """
    Analyze manuscript word count and progress.

    Shows chapter-by-chapter statistics with editorial positioning.
    Automatically groups multi-part chapters (Ch01 + Ch01-1 = Ch01).
    """
    run_wordcount(
        target=target,
        output_format=output_format,
        summary_only=summary_only,
        chapters_spec=chapters,
        show_projections=not no_projections,
    )
