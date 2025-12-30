"""
SILK config command - Manage project configuration.
"""


import typer
from rich.console import Console
from rich.table import Table

from silk_cli.core.project import get_config_dir, load_project_config

app = typer.Typer(help="Manage SILK project configuration.")
console = Console()


@app.callback(invoke_without_command=True)
def config_callback(
    list_all: bool = typer.Option(False, "--list", "-l", help="List all configuration values"),
) -> None:
    """
    Manage project configuration.

    Without arguments, shows current configuration.
    """
    if list_all:
        _show_config()


def _show_config() -> None:
    """Display current configuration."""
    try:
        root, config = load_project_config()
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(1)

    console.print("\n[bold purple]SILK Project Configuration[/bold purple]")
    console.print(f"[dim]Location: {root}[/dim]\n")

    table = Table(show_header=True, header_style="bold")
    table.add_column("Key", style="cyan")
    table.add_column("Value")

    table.add_row("title", config.title)
    table.add_row("genre", config.genre)
    table.add_row("language", config.language)
    table.add_row("target_words", str(config.target_words))
    table.add_row("target_chapters", str(config.target_chapters))
    table.add_row("author_name", config.author_name or "[dim]not set[/dim]")
    table.add_row("author_pseudo", config.author_pseudo or "[dim]not set[/dim]")
    table.add_row("manuscript_separator", f'"{config.manuscript_separator}"')
    table.add_row("default_format", config.default_format)
    if config.cover:
        table.add_row("cover", str(config.cover))

    console.print(table)


@app.command("get")
def get_value(
    key: str = typer.Argument(..., help="Configuration key to get"),
) -> None:
    """Get a specific configuration value."""
    try:
        _, config = load_project_config()
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(1)

    key_lower = key.lower()
    config_dict = config.model_dump()

    if key_lower in config_dict:
        value = config_dict[key_lower]
        console.print(f"{key}: {value}")
    else:
        console.print(f"[red]Unknown key:[/red] {key}")
        console.print(f"[dim]Available keys: {', '.join(config_dict.keys())}[/dim]")
        raise typer.Exit(1)


@app.command("set")
def set_value(
    key: str = typer.Argument(..., help="Configuration key to set"),
    value: str = typer.Argument(..., help="Value to set"),
) -> None:
    """Set a configuration value."""
    try:
        root, config = load_project_config()
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(1)

    key_lower = key.lower()
    config_dict = config.model_dump()

    if key_lower not in config_dict:
        console.print(f"[red]Unknown key:[/red] {key}")
        console.print(f"[dim]Available keys: {', '.join(config_dict.keys())}[/dim]")
        raise typer.Exit(1)

    # Convert value to appropriate type
    current_value = config_dict[key_lower]
    try:
        if isinstance(current_value, int):
            converted_value = int(value)
        elif isinstance(current_value, bool):
            converted_value = value.lower() in ("true", "1", "yes")
        else:
            converted_value = value

        setattr(config, key_lower, converted_value)
    except ValueError as e:
        console.print(f"[red]Invalid value:[/red] {e}")
        raise typer.Exit(1)

    # Save configuration
    config_path = get_config_dir(root) / "config"
    config.save(config_path)

    console.print(f"[green]Updated:[/green] {key} = {converted_value}")
