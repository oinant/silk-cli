"""
Context generation for SILK projects.

Generates unified context files for LLM interaction by combining
prompt, project metadata, and manuscript content.
"""

from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Optional

from silk_cli.core.chapters import collect_chapters, extract_manuscript_content
from silk_cli.core.project import (
    get_characters_dir,
    get_concepts_dir,
    get_manuscript_dir,
    get_outputs_dir,
)
from silk_cli.core.statistics import calculate_manuscript_stats
from silk_cli.models.chapter import ChapterRange


class ContextMode(str, Enum):
    """Context inclusion levels."""

    NOCONTEXT = "nocontext"  # Prompt + manuscript only
    NORMAL = "normal"  # + main characters + concepts
    FULL = "full"  # + all characters + locations + worldbuilding + timeline


@dataclass
class ContextOptions:
    """Options for context generation."""

    prompt_text: str
    prompt_source: str  # e.g., "predefined:coherence", "file:prompt.md", "direct"
    chapter_range: Optional[ChapterRange] = None
    mode: ContextMode = ContextMode.NORMAL
    include_timeline: bool = False
    include_wordcount: bool = False
    timeline_file: Optional[Path] = None
    backstory_file: Optional[Path] = None


@dataclass
class ContextResult:
    """Result of context generation."""

    output_file: Path
    total_words: int
    total_lines: int
    chapters_included: int
    chapters_excluded: int
    mode: ContextMode
    duration_ms: int = 0


class ContextGenerator:
    """
    Generates unified context files for LLM interaction.

    Combines prompt, project context, and manuscript content into
    a single markdown file ready for copy-paste into an LLM.
    """

    def __init__(self, project_root: Path, config):
        self.root = project_root
        self.config = config
        self.manuscript_dir = get_manuscript_dir(project_root)
        self.characters_dir = get_characters_dir(project_root)
        self.concepts_dir = get_concepts_dir(project_root)
        self.outputs_dir = get_outputs_dir(project_root)
        self.context_dir = self.outputs_dir / "context"

    def generate(self, options: ContextOptions) -> ContextResult:
        """
        Generate unified context file.

        Args:
            options: Context generation options.

        Returns:
            ContextResult with generation details.
        """
        import time

        start_time = time.time()

        # Ensure output directory exists
        self.context_dir.mkdir(parents=True, exist_ok=True)
        output_file = self.context_dir / "silk-context.md"

        # Collect chapters
        groups = collect_chapters(
            self.manuscript_dir,
            self.config.manuscript_separator,
            options.chapter_range,
        )

        chapters_included = len(groups)
        all_groups = collect_chapters(
            self.manuscript_dir,
            self.config.manuscript_separator,
        )
        chapters_excluded = len(all_groups) - chapters_included

        # Build content
        content_parts = []

        # Header
        content_parts.append(self._build_header(options))

        # Prompt section
        content_parts.append(self._build_prompt_section(options))

        # Context section (unless nocontext mode)
        if options.mode != ContextMode.NOCONTEXT:
            content_parts.append(self._build_context_section(options, groups))

        # Manuscript section
        content_parts.append(
            self._build_manuscript_section(options, groups)
        )

        # Write output file
        full_content = "\n".join(content_parts)
        output_file.write_text(full_content, encoding="utf-8")

        # Calculate stats
        total_words = len(full_content.split())
        total_lines = full_content.count("\n") + 1

        duration_ms = int((time.time() - start_time) * 1000)

        return ContextResult(
            output_file=output_file,
            total_words=total_words,
            total_lines=total_lines,
            chapters_included=chapters_included,
            chapters_excluded=chapters_excluded,
            mode=options.mode,
            duration_ms=duration_ms,
        )

    def _build_header(self, options: ContextOptions) -> str:
        """Build the header section."""
        now = datetime.now().strftime("%d/%m/%Y à %H:%M:%S")
        range_str = str(options.chapter_range) if options.chapter_range else "all"

        return f"""# SILK CONTEXTE UNIFIÉ

**Généré le:** {now}
**Mode:** {options.mode.value}
**Chapitres:** {range_str}
**Source prompt:** {options.prompt_source}

---
"""

    def _build_prompt_section(self, options: ContextOptions) -> str:
        """Build the prompt section."""
        return f"""# PROMPT

{options.prompt_text}

---
"""

    def _build_context_section(self, options: ContextOptions, groups: dict) -> str:
        """Build the context/metadata section."""
        parts = ["# CONTEXTE PROJET\n"]

        # Project structure summary
        parts.append(self._build_structure_summary())

        # Backstory (normal and full modes)
        if options.backstory_file and options.backstory_file.exists():
            parts.append(self._build_file_section("Backstory", options.backstory_file))

        # Concepts (normal and full modes)
        parts.append(self._build_concepts_section())

        # Characters based on mode
        parts.append(self._build_characters_section(options.mode))

        # Timeline (full mode only)
        if options.mode == ContextMode.FULL:
            if options.timeline_file and options.timeline_file.exists():
                parts.append(self._build_file_section("Timeline complète", options.timeline_file))

            # Locations
            parts.append(self._build_locations_section())

            # Worldbuilding
            parts.append(self._build_worldbuilding_section())

        # Chapter metadata
        parts.append(self._build_chapter_metadata(groups))

        return "\n".join(parts)

    def _build_structure_summary(self) -> str:
        """Build project structure summary."""
        manuscript_count = len(list(self.manuscript_dir.glob("Ch*.md")))
        characters_count = len(list(self.characters_dir.rglob("*.md")))
        concepts_count = len(list(self.concepts_dir.glob("*.md")))

        return f"""## Structure SILK

- **01-Manuscrit/**: {manuscript_count} fichiers chapitres
- **02-Personnages/**: {characters_count} fiches personnages
- **04-Concepts/**: {concepts_count} mécaniques narratives

"""

    def _build_file_section(self, title: str, file_path: Path) -> str:
        """Build a section from a file."""
        try:
            content = file_path.read_text(encoding="utf-8")
            return f"## {title}\n\n{content}\n\n"
        except (OSError, UnicodeDecodeError):
            return ""

    def _build_concepts_section(self) -> str:
        """Build concepts section."""
        if not self.concepts_dir.exists():
            return ""

        concept_files = sorted(self.concepts_dir.glob("*.md"))
        if not concept_files:
            return ""

        parts = ["## Concepts narratifs\n"]
        for f in concept_files:
            try:
                content = f.read_text(encoding="utf-8")
                parts.append(f"### {f.stem}\n\n{content}\n")
            except (OSError, UnicodeDecodeError):
                continue

        return "\n".join(parts) + "\n"

    def _build_characters_section(self, mode: ContextMode) -> str:
        """Build characters section based on mode."""
        if not self.characters_dir.exists():
            return ""

        parts = ["## Personnages\n"]

        # Main trio (Emma, Max, Yasmine) - always included in normal/full
        main_characters = ["Emma", "Max", "Yasmine"]
        main_found = []
        for name in main_characters:
            char_file = self.characters_dir / f"{name}.md"
            if char_file.exists():
                main_found.append(char_file)

        if main_found:
            parts.append("### Trio principal\n")
            for f in main_found:
                try:
                    content = f.read_text(encoding="utf-8")
                    parts.append(f"#### {f.stem}\n\n{content}\n")
                except (OSError, UnicodeDecodeError):
                    continue

        # Main characters folder
        main_dir = self.characters_dir / "Principaux"
        if main_dir.exists() and mode in (ContextMode.NORMAL, ContextMode.FULL):
            main_files = sorted(main_dir.glob("*.md"))
            if main_files:
                parts.append("### Personnages principaux\n")
                for f in main_files:
                    try:
                        content = f.read_text(encoding="utf-8")
                        parts.append(f"#### {f.stem}\n\n{content}\n")
                    except (OSError, UnicodeDecodeError):
                        continue

        # Secondary characters (full mode only)
        if mode == ContextMode.FULL:
            secondary_dir = self.characters_dir / "Secondaires"
            if secondary_dir.exists():
                secondary_files = sorted(secondary_dir.rglob("*.md"))
                if secondary_files:
                    parts.append("### Personnages secondaires\n")
                    for f in secondary_files:
                        try:
                            content = f.read_text(encoding="utf-8")
                            rel_path = f.relative_to(secondary_dir)
                            parts.append(f"#### {rel_path}\n\n{content}\n")
                        except (OSError, UnicodeDecodeError):
                            continue

        return "\n".join(parts) + "\n"

    def _build_locations_section(self) -> str:
        """Build locations section (full mode only)."""
        locations_dir = self.root / "03-Lieux"
        if not locations_dir.exists():
            return ""

        location_files = sorted(locations_dir.glob("*.md"))
        if not location_files:
            return ""

        parts = ["## Lieux\n"]
        for f in location_files:
            try:
                content = f.read_text(encoding="utf-8")
                parts.append(f"### {f.stem}\n\n{content}\n")
            except (OSError, UnicodeDecodeError):
                continue

        return "\n".join(parts) + "\n"

    def _build_worldbuilding_section(self) -> str:
        """Build worldbuilding section (full mode only)."""
        parts = []

        # Worldbuilding directory
        wb_dir = self.root / "05-Worldbuilding"
        if wb_dir.exists():
            wb_files = sorted(wb_dir.glob("*.md"))
            if wb_files:
                parts.append("## Worldbuilding\n")
                for f in wb_files:
                    try:
                        content = f.read_text(encoding="utf-8")
                        parts.append(f"### {f.stem}\n\n{content}\n")
                    except (OSError, UnicodeDecodeError):
                        continue

        # Lore directory
        lore_dir = self.root / "10-Lore"
        if lore_dir.exists():
            lore_files = sorted(lore_dir.glob("*.md"))
            if lore_files:
                parts.append("## Lore\n")
                for f in lore_files:
                    if f.stem == "anciens_chapitres":
                        continue
                    try:
                        content = f.read_text(encoding="utf-8")
                        parts.append(f"### {f.stem}\n\n{content}\n")
                    except (OSError, UnicodeDecodeError):
                        continue

        return "\n".join(parts)

    def _build_chapter_metadata(self, groups: dict) -> str:
        """Build chapter metadata section."""
        if not groups:
            return ""

        parts = ["## Métadonnées chapitres concernés\n"]

        for num in sorted(groups.keys()):
            group = groups[num]
            # Get first chapter for metadata
            if group.chapters:
                chapter = group.chapters[0]
                # Extract metadata (content before manuscript separator)
                try:
                    full_content = chapter.path.read_text(encoding="utf-8")
                    if self.config.manuscript_separator in full_content:
                        metadata = full_content.split(self.config.manuscript_separator)[0]
                        parts.append(f"### {chapter.path.stem}\n\n{metadata.strip()}\n")
                except (OSError, UnicodeDecodeError):
                    continue

        return "\n".join(parts) + "\n"

    def _build_manuscript_section(self, options: ContextOptions, groups: dict) -> str:
        """Build the manuscript section."""
        parts = ["---\n", "# MANUSCRIT\n"]

        # Timeline in manuscript if requested
        if options.include_timeline and options.timeline_file and options.timeline_file.exists():
            parts.append(self._build_file_section("Timeline principale", options.timeline_file))

        # Wordcount if requested
        if options.include_wordcount:
            stats = calculate_manuscript_stats(groups, self.config.target_words)
            parts.append(f"""## Statistiques manuscrit

```
Total: {stats.total_words:,} mots
Chapitres: {stats.total_chapters}
Objectif: {stats.target_words:,} mots
Progression: {stats.completion_percent:.1f}%
Position éditoriale: {stats.editorial_category}
```

""")

        # Chapter content
        parts.append("## Chapitres sélectionnés\n")

        for num in sorted(groups.keys()):
            group = groups[num]
            parts.append(f"### Ch{num:02d} - {group.title}\n")

            # Combine content from all parts
            for chapter in group.chapters:
                content = extract_manuscript_content(
                    chapter.path,
                    self.config.manuscript_separator,
                )
                if content:
                    parts.append(f"\n{content}\n")

        return "\n".join(parts)


def auto_detect_files(root: Path) -> tuple[Optional[Path], Optional[Path]]:
    """
    Auto-detect timeline and backstory files.

    Returns:
        Tuple of (timeline_path, backstory_path).
    """
    timeline_candidates = [
        root / "07-timeline" / "timeline-rebuild-4.md",
        root / "07-timeline" / "timeline.md",
        root / "timeline.md",
        root / "Timeline.md",
    ]

    backstory_candidates = [
        root / "backstory.md",
        root / "Backstory.md",
        root / "04-Concepts" / "backstory.md",
        root / "10-Lore" / "backstory.md",
    ]

    timeline_file = None
    for candidate in timeline_candidates:
        if candidate.exists():
            timeline_file = candidate
            break

    backstory_file = None
    for candidate in backstory_candidates:
        if candidate.exists():
            backstory_file = candidate
            break

    return timeline_file, backstory_file
