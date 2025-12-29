"""
Rich console utilities for SILK CLI.

Provides consistent logging and output formatting across all commands.
"""

from rich.console import Console
from rich.theme import Theme

# Custom theme for SILK
SILK_THEME = Theme({
    "info": "blue",
    "success": "green",
    "warning": "yellow",
    "error": "red bold",
    "header": "purple bold",
    "debug": "cyan dim",
    "highlight": "magenta",
})

# Global console instance
console = Console(theme=SILK_THEME)


def log_info(message: str) -> None:
    """Log an info message."""
    console.print(f"[info][INFO][/info] {message}")


def log_success(message: str) -> None:
    """Log a success message."""
    console.print(f"[success][OK][/success] {message}")


def log_warning(message: str) -> None:
    """Log a warning message."""
    console.print(f"[warning][WARN][/warning] {message}")


def log_error(message: str) -> None:
    """Log an error message."""
    console.print(f"[error][ERROR][/error] {message}")


def log_header(message: str) -> None:
    """Log a header message."""
    console.print(f"[header][SILK][/header] {message}")


def log_debug(message: str, *, debug: bool = False) -> None:
    """Log a debug message (only if debug mode is enabled)."""
    if debug:
        console.print(f"[debug][DEBUG][/debug] {message}")
