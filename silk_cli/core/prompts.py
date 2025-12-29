"""
Predefined prompts for SILK context generation.

These prompts are designed for common LLM-assisted writing tasks.
"""

# Predefined prompts for context generation
PREDEFINED_PROMPTS = {
    "coherence": (
        "Analyse la cohérence narrative, temporelle et psychologique de ces chapitres. "
        "Identifie les incohérences, contradictions ou éléments qui nécessitent une harmonisation."
    ),
    "revision": (
        "Révise ces chapitres en te concentrant sur l'amélioration du style, du rythme narratif "
        "et de la fluidité. Propose des améliorations concrètes pour enrichir le texte."
    ),
    "characters": (
        "Analyse le développement des personnages dans ces chapitres. Évalue la crédibilité "
        "psychologique, l'évolution des arcs narratifs et la cohérence des motivations."
    ),
    "dialogue": (
        "Examine les dialogues dans ces chapitres. Améliore l'authenticité, la différenciation "
        "des voix et l'efficacité narrative des échanges."
    ),
    "plot": (
        "Analyse la progression de l'intrigue dans ces chapitres. Évalue le rythme, les tensions, "
        "les révélations et l'engagement du lecteur."
    ),
    "style": (
        "Analyse le style d'écriture de ces chapitres. Propose des améliorations pour la voix "
        "narrative, les descriptions et l'atmosphère générale."
    ),
    "continuity": (
        "Vérifie la continuité narrative entre ces chapitres. Identifie les ruptures de rythme, "
        "les transitions abruptes ou les éléments manquants."
    ),
    "editing": (
        "Effectue une révision éditoriale complète de ces chapitres : syntaxe, grammaire, "
        "répétitions, clarté et impact."
    ),
}


def get_predefined_prompt(name: str) -> str | None:
    """Get a predefined prompt by name."""
    return PREDEFINED_PROMPTS.get(name)


def list_predefined_prompts() -> list[str]:
    """List all available predefined prompt names."""
    return list(PREDEFINED_PROMPTS.keys())
