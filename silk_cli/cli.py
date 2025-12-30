"""
SILK CLI - Main entry point.

Smart Integrated Literary Kit - Modern CLI for authors with LLM integration.
"""

from typing import Optional

import typer
from rich.console import Console
from rich.panel import Panel

from silk_cli import __version__
from silk_cli.commands import config
from silk_cli.commands.cache import cache
from silk_cli.commands.context import context
from silk_cli.commands.init import init
from silk_cli.commands.publish import publish
from silk_cli.commands.wordcount import wordcount
from silk_cli.core.project import find_silk_root


def version_callback(value: bool) -> None:
    """Print version and exit."""
    if value:
        print(f"SILK CLI v{__version__}")
        raise typer.Exit()


app = typer.Typer(
    name="silk",
    help="SILK - Smart Integrated Literary Kit. Modern CLI for authors with LLM integration.",
    no_args_is_help=True,
    pretty_exceptions_enable=True,
)

console = Console()

# Register subcommands
app.add_typer(config.app, name="config")
app.command(name="wordcount")(wordcount)
app.command(name="context")(context)
app.command(name="cache")(cache)
app.command(name="init")(init)
app.command(name="publish")(publish)


@app.command()
def version() -> None:
    """Display SILK version and system information."""
    console.print(
        Panel(
            f"[bold purple]SILK[/bold purple] v{__version__}\n\n"
            "[dim]Smart Integrated Literary Kit[/dim]\n"
            "[dim]Structured Intelligence for Literary Kreation[/dim]",
            title="Version",
            border_style="purple",
        )
    )

    # Check if we're in a SILK project
    root = find_silk_root()
    if root:
        console.print(f"\n[green]Project:[/green] {root.name}")
        console.print(f"[dim]Location:[/dim] {root}")
    else:
        console.print("\n[yellow]Not in a SILK project[/yellow]")


@app.callback()
def main(
    version: Optional[bool] = typer.Option(
        None, "--version", "-V", callback=version_callback, is_eager=True,
        help="Show version and exit."
    ),
) -> None:
    """
    SILK - Smart Integrated Literary Kit.

    Modern CLI workflow for authors with LLM integration.
    """
    pass


if __name__ == "__main__":
    app()
