"""
SILK context command - Generate unified context for LLM interaction.
"""

from pathlib import Path
from typing import Annotated, Optional

import typer
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

from silk_cli.core.chapters import get_max_chapter_number
from silk_cli.core.context import (
    ContextGenerator,
    ContextMode,
    ContextOptions,
    auto_detect_files,
)
from silk_cli.core.project import get_manuscript_dir, load_project_config
from silk_cli.core.prompts import PREDEFINED_PROMPTS, get_predefined_prompt
from silk_cli.models.chapter import ChapterRange

console = Console()


def context(
    prompt: Annotated[
        Optional[str],
        typer.Argument(help="Direct prompt text (or use -p for predefined)"),
    ] = None,
    predefined: Annotated[
        Optional[str],
        typer.Option("--prompt", "-p", help="Use predefined prompt (coherence, revision, etc.)"),
    ] = None,
    prompt_file: Annotated[
        Optional[Path],
        typer.Option("--withpromptfile", help="Read prompt from file"),
    ] = None,
    chapters: Annotated[
        Optional[str],
        typer.Option("--chapters", "-ch", help="Chapter range (e.g., '1-10', '5,12,18-20', 'all')"),
    ] = None,
    mode: Annotated[
        str,
        typer.Option("--mode", help="Context level: nocontext, normal, full"),
    ] = "normal",
    timeline: Annotated[
        bool,
        typer.Option("--timeline", "-tl", help="Include timeline in output"),
    ] = False,
    wordcount: Annotated[
        bool,
        typer.Option("--wordcount", "-wc", help="Include wordcount statistics"),
    ] = False,
    timeline_file: Annotated[
        Optional[Path],
        typer.Option("--timeline-file", help="Specific timeline file to use"),
    ] = None,
    backstory_file: Annotated[
        Optional[Path],
        typer.Option("--backstory", help="Specific backstory file to use"),
    ] = None,
    list_prompts: Annotated[
        bool,
        typer.Option("--list-prompts", "-l", help="List available predefined prompts"),
    ] = False,
) -> None:
    """
    Generate unified context for LLM interaction.

    Combines prompt, project metadata, and manuscript content into
    a single file ready for copy-paste into your preferred LLM.

    Examples:
        silk context "Analyse la cohérence du chapitre 15"
        silk context -p coherence --chapters 1-10
        silk context -p characters --mode full
        silk context --withpromptfile analyse.md -ch 20,25,30
    """
    # List prompts mode
    if list_prompts:
        _show_predefined_prompts()
        return

    # Determine prompt text and source
    prompt_text: Optional[str] = None
    prompt_source: str = "unknown"

    if predefined:
        prompt_text = get_predefined_prompt(predefined)
        if not prompt_text:
            console.print(f"[red]Unknown predefined prompt:[/red] {predefined}")
            console.print("[dim]Use --list-prompts to see available prompts[/dim]")
            raise typer.Exit(1)
        prompt_source = f"predefined:{predefined}"
    elif prompt_file:
        if not prompt_file.exists():
            console.print(f"[red]Prompt file not found:[/red] {prompt_file}")
            raise typer.Exit(1)
        try:
            prompt_text = prompt_file.read_text(encoding="utf-8")
            prompt_source = f"file:{prompt_file.name}"
        except (OSError, UnicodeDecodeError) as e:
            console.print(f"[red]Error reading prompt file:[/red] {e}")
            raise typer.Exit(1)
    elif prompt:
        prompt_text = prompt
        prompt_source = "direct"
    else:
        console.print("[red]No prompt provided.[/red] Use one of:")
        console.print('  silk context "your question"')
        console.print("  silk context -p coherence")
        console.print("  silk context --withpromptfile prompt.md")
        raise typer.Exit(1)

    # Validate mode
    try:
        context_mode = ContextMode(mode)
    except ValueError:
        console.print(f"[red]Invalid mode:[/red] {mode}")
        console.print("[dim]Valid modes: nocontext, normal, full[/dim]")
        raise typer.Exit(1)

    # Load project
    try:
        root, config = load_project_config()
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(1)

    # Parse chapter range
    chapter_range: Optional[ChapterRange] = None
    if chapters and chapters.lower() != "all":
        manuscript_dir = get_manuscript_dir(root)
        max_chapter = get_max_chapter_number(manuscript_dir)
        chapter_range = ChapterRange.parse(chapters, max_chapter)

    # Auto-detect files if not specified
    auto_timeline, auto_backstory = auto_detect_files(root)
    final_timeline = timeline_file or (auto_timeline if timeline else None)
    final_backstory = backstory_file or auto_backstory

    # Build options
    options = ContextOptions(
        prompt_text=prompt_text,
        prompt_source=prompt_source,
        chapter_range=chapter_range,
        mode=context_mode,
        include_timeline=timeline,
        include_wordcount=wordcount,
        timeline_file=final_timeline,
        backstory_file=final_backstory,
    )

    # Generate context
    console.print("[purple]SILK tisse votre contexte unifié...[/purple]")

    generator = ContextGenerator(root, config)
    result = generator.generate(options)

    # Show report
    _show_report(result, options)


def _show_predefined_prompts() -> None:
    """Display available predefined prompts."""
    console.print(Panel("[bold]Prompts prédéfinis SILK[/bold]", border_style="purple"))

    table = Table(show_header=True, header_style="bold cyan")
    table.add_column("Nom", style="cyan", width=12)
    table.add_column("Description")

    for name, text in PREDEFINED_PROMPTS.items():
        # Truncate long descriptions
        desc = text[:80] + "..." if len(text) > 80 else text
        table.add_row(name, desc)

    console.print(table)
    console.print("\n[dim]Usage: silk context -p <nom> [options][/dim]")


def _show_report(result, options: ContextOptions) -> None:
    """Display generation report."""
    console.print()
    console.print(
        f"[green]Contexte unifié généré en {result.duration_ms}ms[/green]"
    )

    console.print()
    console.print("[bold]RÉSUMÉ:[/bold]")
    console.print(f"   Prompt: {options.prompt_source}")
    console.print(f"   Mode: {result.mode.value}")
    console.print(f"   Chapitres inclus: {result.chapters_included}")
    console.print(f"   Chapitres exclus: {result.chapters_excluded}")
    console.print(f"   Taille: {result.total_words:,} mots, {result.total_lines:,} lignes")

    console.print()
    console.print("[bold]FICHIER GÉNÉRÉ:[/bold]")
    console.print(f"   {result.output_file}")

    console.print()
    console.print("[dim]Copiez le contenu du fichier dans votre LLM préféré.[/dim]")
