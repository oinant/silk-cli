"""
SILK init command - Create new literary projects.
"""

import subprocess
from pathlib import Path
from typing import Annotated, Optional

import typer
from rich.console import Console
from rich.panel import Panel
from rich.prompt import Confirm, IntPrompt, Prompt
from rich.table import Table

from silk_cli import __version__
from silk_cli.models.config import SilkConfig
from silk_cli.templates.loader import (
    AVAILABLE_GENRES,
    create_project_structure,
    get_genre_description,
    sanitize_directory_name,
)

console = Console()


def init(
    project_name: Annotated[
        Optional[str],
        typer.Argument(help="Name of the project"),
    ] = None,
    genre: Annotated[
        str,
        typer.Option("--genre", "-g", help="Literary genre"),
    ] = "polar-psychologique",
    language: Annotated[
        str,
        typer.Option("--language", "-l", help="Language (fr, en, es, de)"),
    ] = "fr",
    target_words: Annotated[
        int,
        typer.Option("--words", "-w", help="Target word count"),
    ] = 80000,
    target_chapters: Annotated[
        int,
        typer.Option("--chapters", "-c", help="Target number of chapters"),
    ] = 30,
    author_name: Annotated[
        Optional[str],
        typer.Option("--author", "-a", help="Author name"),
    ] = None,
    author_pseudo: Annotated[
        Optional[str],
        typer.Option("--pseudo", "-p", help="Author pseudonym"),
    ] = None,
    yes: Annotated[
        bool,
        typer.Option("--yes", "-y", help="Skip interactive prompts"),
    ] = False,
) -> None:
    """
    Create a new SILK literary project.

    Creates a complete project structure with directories for manuscript,
    characters, concepts, and more. Optionally initializes a git repository.

    Examples:
        silk init "L'Araignée"                    # Interactive mode
        silk init "Dark Mystery" --genre fantasy  # Fantasy project
        silk init "Love Story" -w 60000 -c 25 -y # Non-interactive
    """
    # Interactive mode if needed
    if not yes:
        project_name, genre, language, target_words, target_chapters, author_name, author_pseudo = (
            _run_interactive_setup(
                project_name, genre, language, target_words,
                target_chapters, author_name, author_pseudo
            )
        )

    # Validate project name
    if not project_name:
        console.print("[red]Project name is required[/red]")
        raise typer.Exit(1)

    # Validate genre
    if genre not in AVAILABLE_GENRES:
        console.print(f"[red]Invalid genre:[/red] {genre}")
        console.print(f"[dim]Available: {', '.join(AVAILABLE_GENRES)}[/dim]")
        raise typer.Exit(1)

    # Create project
    try:
        _create_project(
            project_name=project_name,
            genre=genre,
            language=language,
            target_words=target_words,
            target_chapters=target_chapters,
            author_name=author_name or "",
            author_pseudo=author_pseudo or "",
        )
    except Exception as e:
        console.print(f"[red]Error creating project:[/red] {e}")
        raise typer.Exit(1)


def _run_interactive_setup(
    project_name: Optional[str],
    genre: str,
    language: str,
    target_words: int,
    target_chapters: int,
    author_name: Optional[str],
    author_pseudo: Optional[str],
) -> tuple:
    """Run interactive project setup."""
    console.print(
        Panel(
            "[bold purple]SILK INIT[/bold purple]\n"
            "[dim]Smart Integrated Literary Kit[/dim]\n\n"
            "Tissons ensemble votre nouveau projet littéraire...",
            border_style="purple",
        )
    )
    console.print()

    # Project name
    if not project_name:
        project_name = Prompt.ask("[cyan]Nom du projet[/cyan]")

    # Genre selection
    console.print("\n[bold]Genres disponibles:[/bold]")
    table = Table(show_header=False, box=None)
    table.add_column("Genre", style="cyan")
    table.add_column("Description")
    for g in AVAILABLE_GENRES:
        marker = "→" if g == genre else " "
        table.add_row(f"{marker} {g}", get_genre_description(g))
    console.print(table)

    genre_input = Prompt.ask(
        "[cyan]Genre[/cyan]",
        default=genre,
        choices=AVAILABLE_GENRES,
    )
    genre = genre_input

    # Target words
    target_words = IntPrompt.ask(
        "[cyan]Objectif mots[/cyan]",
        default=target_words,
    )

    # Target chapters
    target_chapters = IntPrompt.ask(
        "[cyan]Nombre de chapitres[/cyan]",
        default=target_chapters,
    )

    # Author info
    author_name = Prompt.ask(
        "[cyan]Nom de l'auteur[/cyan]",
        default=author_name or "",
    )

    author_pseudo = Prompt.ask(
        "[cyan]Pseudonyme (optionnel)[/cyan]",
        default=author_pseudo or "",
    )

    # Confirmation
    console.print()
    console.print("[bold]Résumé:[/bold]")
    console.print(f"  Projet: [cyan]{project_name}[/cyan]")
    console.print(f"  Genre: [cyan]{genre}[/cyan]")
    console.print(f"  Objectif: [cyan]{target_words:,} mots[/cyan]")
    console.print(f"  Chapitres: [cyan]{target_chapters}[/cyan]")
    if author_name:
        console.print(f"  Auteur: [cyan]{author_name}[/cyan]")
    if author_pseudo:
        console.print(f"  Pseudonyme: [cyan]{author_pseudo}[/cyan]")
    console.print()

    if not Confirm.ask("Créer le projet ?", default=True):
        console.print("[yellow]Création annulée[/yellow]")
        raise typer.Exit(0)

    return project_name, genre, language, target_words, target_chapters, author_name, author_pseudo


def _create_project(
    project_name: str,
    genre: str,
    language: str,
    target_words: int,
    target_chapters: int,
    author_name: str,
    author_pseudo: str,
) -> None:
    """Create the SILK project."""
    # Sanitize directory name
    dir_name = sanitize_directory_name(project_name)
    project_dir = Path.cwd() / dir_name

    if project_dir.exists():
        console.print(f"[red]Directory already exists:[/red] {dir_name}")
        raise typer.Exit(1)

    console.print(f"\n[purple]Tissage du projet '{project_name}' dans '{dir_name}'...[/purple]")

    # Create directory structure
    project_dir.mkdir(parents=True)
    create_project_structure(project_dir)

    # Create .silk/config
    silk_dir = project_dir / ".silk"
    silk_dir.mkdir(exist_ok=True)

    config = SilkConfig(
        title=project_name,
        genre=genre,
        language=language,
        target_words=target_words,
        target_chapters=target_chapters,
        author_name=author_name or "",
        author_pseudo=author_pseudo,
    )
    config.save(silk_dir / "config")

    # Create README.md
    _create_readme(project_dir, project_name, genre, target_words, target_chapters, author_name)

    # Create instructions LLM
    _create_instructions(project_dir, project_name, genre, author_name, author_pseudo)

    # Create first chapter template
    _create_first_chapter(project_dir, project_name)

    # Create character template
    _create_character_template(project_dir)

    # Copy format files
    _copy_formats(project_dir)

    # Initialize git
    _init_git(project_dir, project_name, genre, author_name)

    # Success message
    console.print()
    console.print(f"[green]Projet '{project_name}' créé avec succès ![/green]")
    console.print()
    console.print("[bold]Prochaines étapes:[/bold]")
    console.print(f"  cd {dir_name}")
    console.print("  silk config --list          # Voir configuration")
    console.print("  silk wordcount              # Suivi progression")
    console.print("  silk context -p coherence   # Contexte LLM")
    console.print()
    console.print("[purple]SILK has woven your literary foundation. Begin writing![/purple]")


def _create_readme(
    project_dir: Path,
    project_name: str,
    genre: str,
    target_words: int,
    target_chapters: int,
    author_name: str,
) -> None:
    """Create project README."""
    readme_content = f"""# {project_name}

*Projet SILK - Smart Integrated Literary Kit*

## Informations

- **Genre**: {genre}
- **Objectif**: {target_words:,} mots
- **Chapitres prévus**: {target_chapters}
- **Auteur**: {author_name or "Non défini"}

## Structure SILK

```
01-Manuscrit/       # Chapitres du roman
02-Personnages/     # Fiches personnages
03-Lieux/           # Descriptions des lieux
04-Concepts/        # Mécaniques narratives
07-timeline/        # Chronologie
outputs/            # Fichiers générés (PDF, EPUB, contexte LLM)
```

## Commandes SILK

```bash
silk wordcount              # Statistiques manuscrit
silk context -p coherence   # Génération contexte LLM
silk publish -f digital     # Publication PDF
silk config --list          # Configuration projet
```

## Workflow recommandé

1. Rédiger les chapitres dans `01-Manuscrit/`
2. Utiliser `silk wordcount` pour suivre la progression
3. Générer des contextes LLM avec `silk context`
4. Publier avec `silk publish`

---
*Généré par SILK v{__version__}*
"""
    (project_dir / "README.md").write_text(readme_content, encoding="utf-8")


def _create_instructions(
    project_dir: Path,
    project_name: str,
    genre: str,
    author_name: str,
    author_pseudo: str,
) -> None:
    """Create LLM instructions file."""
    pseudo_line = f" (pseudo: {author_pseudo})" if author_pseudo else ""

    instructions = f"""# Instructions LLM - {project_name}

*Projet SILK - Smart Integrated Literary Kit*

## Contexte projet

- **Genre**: {genre}
- **Auteur**: {author_name}{pseudo_line}
- **Architecture**: SILK - Structured Intelligence for Literary Kreation

## Philosophie SILK

SILK tisse ensemble tous les éléments narratifs comme une araignée tisse sa toile :
- **Smart**: Templates adaptés au genre et marché français
- **Integrated**: Workflow unifié conception → publication
- **Literary**: Focus sur la qualité narrative
- **Kit**: Boîte à outils complète pour auteurs

## Instructions générales

### Style et ton
- Écriture sophistiquée mais accessible
- Développement psychologique des personnages
- Dialogues authentiques et différenciés
- Rythme maîtrisé alternant tension et respiration

### Structure narrative
- Révélations progressives et calculées
- Fausses pistes élégantes sans frustration
- Résolution surprenante mais inévitable rétrospectivement

### Cohérence
- Maintenir la cohérence temporelle
- Respecter les arcs de personnages
- Assurer la continuité entre chapitres

---
*Généré par SILK v{__version__}*
"""
    instructions_dir = project_dir / "00-instructions-llm"
    instructions_dir.mkdir(exist_ok=True)
    (instructions_dir / "instructions.md").write_text(instructions, encoding="utf-8")


def _create_first_chapter(project_dir: Path, project_name: str) -> None:
    """Create first chapter template."""
    chapter_content = """# Ch.01 : Premier chapitre

## Objectifs SILK
- [ ] Introduire le protagoniste
- [ ] Établir le ton et l'atmosphère
- [ ] Poser les premiers éléments d'intrigue
- [ ] Accrocher le lecteur

## Notes
*Ajouter vos notes ici*

## manuscrit

*Commencez à écrire ici...*

"""
    manuscript_dir = project_dir / "01-Manuscrit"
    manuscript_dir.mkdir(exist_ok=True)
    (manuscript_dir / "Ch01.md").write_text(chapter_content, encoding="utf-8")


def _create_character_template(project_dir: Path) -> None:
    """Create character template."""
    template_content = """# Nom du personnage

## Identité
- **Âge**:
- **Profession**:
- **Apparence**:

## Psychologie
- **Traits dominants**:
- **Motivations**:
- **Peurs/faiblesses**:
- **Arc de transformation**:

## Relations
- *Liste des relations avec autres personnages*

## Notes
*Informations complémentaires*
"""
    templates_dir = project_dir / "99-Templates"
    templates_dir.mkdir(exist_ok=True)
    (templates_dir / "Template-Personnage.md").write_text(template_content, encoding="utf-8")


def _copy_formats(project_dir: Path) -> None:
    """Copy format configuration files."""
    formats_dir = project_dir / "formats"
    formats_dir.mkdir(exist_ok=True)

    # Create default digital format
    digital_config = """geometry: "paperwidth=6in,paperheight=9in,margin=0.5in"
fontsize: 12pt
linestretch: 1.3
header-includes: |
  \\setlength{\\parskip}{0.5em}
  \\setlength{\\parindent}{1.2em}
  \\usepackage{microtype}
"""
    (formats_dir / "digital.yaml").write_text(digital_config, encoding="utf-8")

    # Create book format
    book_config = """geometry: "paperwidth=5.5in,paperheight=8.5in,margin=0.75in"
fontsize: 11pt
linestretch: 1.2
header-includes: |
  \\setlength{\\parskip}{0pt}
  \\setlength{\\parindent}{1.5em}
  \\usepackage{microtype}
"""
    (formats_dir / "book.yaml").write_text(book_config, encoding="utf-8")


def _init_git(project_dir: Path, project_name: str, genre: str, author_name: str) -> None:
    """Initialize git repository."""
    try:
        # Check if git is available
        result = subprocess.run(
            ["git", "--version"],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            return

        # Initialize repo
        subprocess.run(
            ["git", "init", "--quiet"],
            cwd=project_dir,
            capture_output=True,
        )

        # Create .gitignore
        gitignore = """# SILK outputs
outputs/temp/
outputs/publish/*.pdf
outputs/publish/*.epub

# OS files
.DS_Store
Thumbs.db

# Editor files
*.swp
*~
.vscode/
.idea/

# Cache
__pycache__/
*.pyc
"""
        (project_dir / ".gitignore").write_text(gitignore, encoding="utf-8")

        # Initial commit
        subprocess.run(["git", "add", "."], cwd=project_dir, capture_output=True)
        commit_msg = f"""Initial SILK project: {project_name}

SILK v{__version__}
Genre: {genre}
Author: {author_name or "Unknown"}

Structure ready for: silk context, wordcount, publish
"""
        subprocess.run(
            ["git", "commit", "--quiet", "-m", commit_msg],
            cwd=project_dir,
            capture_output=True,
        )
    except FileNotFoundError:
        # Git not installed
        pass
