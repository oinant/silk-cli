# SILK CLI - Claude Code Context

## Project Overview

SILK (Smart Integrated Literary Kit) is a CLI tool for fiction authors with LLM integration. It helps manage novel writing projects: chapter organization, word count tracking, context generation for LLMs, and multi-format publishing.

**Current state:** Legacy Bash implementation (~5000 lines) with Bash 4+ features incompatible with macOS default Bash 3.2.

**Target state:** Modern Python CLI using Typer, following the architecture style of [local-sd-generator](https://github.com/oinant/local-sd-generator).

## Migration Context

We are migrating from Bash to Python/Typer because:
- Bash 3.2 compatibility issues on macOS (associative arrays, namerefs, case conversion)
- Better maintainability, testability, and cross-platform support
- Alignment with owner's Python development style

## Architecture Target

```
silk_cli/
├── cli.py                    # Typer entry point
├── commands/                 # CLI commands
│   ├── init.py              # silk init - create new project
│   ├── config.py            # silk config - manage project config
│   ├── context.py           # silk context - generate LLM context
│   ├── wordcount.py         # silk wordcount - manuscript statistics
│   ├── publish.py           # silk publish - generate PDF/EPUB/HTML
│   └── cache.py             # silk cache - manage content cache
├── core/                    # Business logic
│   ├── project.py           # Project detection/validation
│   ├── chapters.py          # Multi-part chapter handling
│   ├── manuscript.py        # Content extraction (## manuscrit separator)
│   ├── cache.py             # MD5-based caching system
│   └── statistics.py        # Word count calculations
├── publishing/              # Output generation
│   ├── pandoc.py            # Pandoc interface
│   ├── transformers.py      # Text transformations (quotes, dashes)
│   ├── formats.py           # Format configurations
│   └── metadata.py          # YAML metadata handling
├── templates/               # Project templates by genre
│   ├── base.py
│   ├── polar.py
│   ├── fantasy.py
│   └── romance.py
├── models/                  # Pydantic models
│   ├── config.py            # SilkConfig
│   ├── chapter.py           # Chapter, ChapterRange
│   └── project.py           # SilkProject
└── utils/                   # Utilities
    ├── console.py           # Rich console, logging
    └── files.py             # File operations
```

## Key Concepts

### Manuscript Separator
Chapters use `## manuscrit` (configurable) to separate metadata from pure content:
```markdown
# Ch.15 : Title

## SILK Objectives
- Planning metadata...

## manuscrit
[Pure content sent to LLM / published]
```

### Multi-part Chapters
Chapters can be split: Ch01.md, Ch01-1.md, Ch01-2.md are consolidated as "Ch01" in wordcount/context.

### Chapter Ranges
Commands accept flexible ranges: `1-10`, `5,12,18-20`, `all`

## Tech Stack

- **CLI Framework:** Typer
- **Validation:** Pydantic
- **Console:** Rich
- **Testing:** pytest
- **Package Manager:** Poetry
- **External deps:** Pandoc (PDF/EPUB), XeLaTeX (PDF)

## Commands Reference

| Command | Description |
|---------|-------------|
| `silk init "Title"` | Create new project with genre templates |
| `silk config --list` | Manage .silk/config |
| `silk context "prompt" --chapters 1-5` | Generate LLM context |
| `silk wordcount [target]` | Manuscript statistics |
| `silk publish -f digital` | Generate PDF/EPUB/HTML |
| `silk cache --status` | Manage content cache |

## Development Guidelines

- Follow patterns from local-sd-generator repo
- Type hints required (mypy strict)
- Tests required for new features (pytest, >80% coverage)
- Use Pydantic for all config/data models
- Rich for all console output
- Pathlib for file operations

## Current Priority

Migration from Bash to Python - phased approach:
1. Core + Config + Wordcount (foundation)
2. Init + Cache + Context (project management)
3. Publish (complex, Pandoc integration)
4. Tests + Documentation (finalization)
