"""
SILK cache command - Manage chapter cache for publish operations.
"""

from typing import Annotated

import typer
from rich.console import Console
from rich.table import Table

from silk_cli.core.cache import SilkCache
from silk_cli.core.project import load_project_config

console = Console()


def cache(
    stats: Annotated[
        bool,
        typer.Option("--stats", "-s", help="Show cache statistics"),
    ] = False,
    cleanup: Annotated[
        bool,
        typer.Option("--cleanup", "-c", help="Clean up invalid cache entries"),
    ] = False,
    force: Annotated[
        bool,
        typer.Option("--force", "-f", help="Force complete cache clear (with --cleanup)"),
    ] = False,
) -> None:
    """
    Manage SILK chapter cache.

    The cache stores processed chapter files to speed up publish operations.
    Uses composite MD5 hashes for multi-part chapter detection.

    Examples:
        silk cache --stats      # Show cache statistics
        silk cache --cleanup    # Clean invalid entries
        silk cache -c --force   # Clear entire cache
    """
    try:
        root, _ = load_project_config()
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(1)

    silk_cache = SilkCache(root)

    if cleanup:
        _run_cleanup(silk_cache, force)
    elif stats or not (cleanup):
        # Default: show stats
        _show_stats(silk_cache)


def _show_stats(silk_cache: SilkCache) -> None:
    """Display cache statistics."""
    stats = silk_cache.stats()

    console.print("[bold purple]SILK Cache Statistics[/bold purple]\n")

    table = Table(show_header=False)
    table.add_column("Key", style="cyan")
    table.add_column("Value", justify="right")

    table.add_row("Total entries", str(stats["total_entries"]))
    table.add_row("Valid entries", f"[green]{stats['valid_entries']}[/green]")
    table.add_row("Invalid entries", f"[yellow]{stats['invalid_entries']}[/yellow]")
    table.add_row("Clean files", str(stats["clean_files"]))
    table.add_row("Cache file", stats["cache_file"])

    console.print(table)

    if stats["invalid_entries"] > 0:
        console.print(
            "\n[dim]Run 'silk cache --cleanup' to remove invalid entries[/dim]"
        )


def _run_cleanup(silk_cache: SilkCache, force: bool) -> None:
    """Run cache cleanup."""
    if force:
        console.print("[yellow]Clearing entire cache...[/yellow]")
    else:
        console.print("[yellow]Cleaning up invalid cache entries...[/yellow]")

    entries_removed, files_removed = silk_cache.cleanup(force=force)

    if force:
        console.print(
            f"[green]Cache cleared:[/green] {entries_removed} entries, {files_removed} files"
        )
    elif entries_removed > 0:
        console.print(f"[green]Cleaned up:[/green] {entries_removed} invalid entries")
    else:
        console.print("[green]Cache is already clean[/green]")
