# SILK CLI - Smart Integrated Literary Kit

Modern CLI workflow for authors with LLM integration.

## What is SILK?

SILK weaves together all aspects of modern novel writing:
- **Smart** templates adapted by genre and market
- **Integrated** workflow from concept to publication
- **Literary** focus on sophisticated fiction
- **Kit** complete toolbox for authors

Just like a spider weaves its web, SILK helps you weave together characters, plot, and narrative into compelling fiction.

## Installation

```bash
pip install silk-cli
```

**Requirements:**
- Python 3.11+
- Pandoc (for publishing)
- XeLaTeX (for PDF generation)

## Quick Start

```bash
# Create new project
silk init "My Novel" --genre polar-psychologique

# Track progress
silk wordcount 80000

# Generate LLM context
silk context -p coherence --chapters 1-10

# Publish professional PDF
silk publish -f digital
```

## Commands

### `silk init`

Create a new SILK project with genre-specific templates.

```bash
silk init "My Novel"                           # Interactive mode
silk init "My Novel" --genre polar --yes       # Non-interactive
```

### `silk wordcount`

Track writing progress with intelligent statistics.

```bash
silk wordcount                    # Default target from config
silk wordcount 100000             # Custom target
silk wordcount --summary          # Quick overview
silk wordcount --json             # Export data
```

Features:
- Automatic chapter grouping (Ch23 + Ch23-1 = Ch23)
- Editorial threshold positioning (40k-120k words)
- Regularity analysis with recommendations
- Priority chapters identification

### `silk context`

Generate unified context for LLM assistance.

```bash
silk context "Analyze character development" --chapters 1-5
silk context -p coherence --chapters 10-15    # Predefined prompt
silk context -p revision --mode full          # Full context mode
```

Modes:
- **nocontext**: Prompt + manuscript only
- **normal**: + main characters + concepts
- **full**: + all characters + locations + timeline + worldbuilding

### `silk publish`

Generate professional publications in multiple formats.

```bash
silk publish -f digital           # PDF for digital reading
silk publish -f print             # PDF for print
silk publish -f epub              # EPUB format
silk publish -f html              # HTML format
silk publish --dry-run            # Preview without generating
```

### `silk config`

Manage project configuration.

```bash
silk config --list                # Show all settings
silk config get title             # Get specific value
silk config set author_name "Me"  # Set value
```

### `silk cache`

Manage the chapter cache system.

```bash
silk cache                        # Show cache stats
silk cache --stats                # Detailed statistics
silk cache --cleanup              # Clean invalid entries
```

## Project Structure

SILK projects follow this structure:

```
my-novel/
├── .silk/
│   └── config                    # Project configuration
├── 01-Manuscrit/
│   ├── Ch01.md                   # Chapter files
│   ├── Ch01-1.md                 # Multi-part chapters
│   └── ...
├── 02-Personnages/               # Character files
├── 03-Lieux/                     # Location files
├── 04-Concepts/                  # Concept files
├── 05-Timeline/                  # Timeline
└── outputs/                      # Generated files
```

## SILK Manuscript Format

Chapters use a special separator to distinguish metadata from content:

```markdown
# Ch.15 : Title

## SILK Objectives
- Metadata for planning...

## manuscrit
[Pure content - this is what gets published and analyzed]
```

## Supported Genres

- **polar-psychologique**: French psychological thriller
- **fantasy**: Fantasy with worldbuilding support
- **romance**: Romance with relationship arcs
- **literary**: Literary fiction
- **thriller**: Action thriller

## Development

### Setup

```bash
git clone https://github.com/oinant/silk-cli
cd silk-cli
poetry install
```

### Testing

```bash
poetry run pytest                           # Run tests
poetry run pytest --cov=silk_cli            # With coverage
poetry run pytest silk_cli/tests/unit/      # Unit tests only
poetry run pytest silk_cli/tests/e2e/       # E2E tests only
```

### Type Checking

```bash
poetry run mypy silk_cli/
```

### Linting

```bash
poetry run ruff check silk_cli/
```

## License

MIT

## Author

Antoine Sauvinet

---

*SILK weaves your story together.*
