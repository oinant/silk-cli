#!/bin/bash
# lib/templates/fantasy.sh - SILK Templates - Fantasy/Fantastique

# Charger les fonctions communes
if [[ "${SILK_TEMPLATES_COMMON_LOADED:-false}" != "true" ]]; then
    source "${SILK_LIB_DIR}/templates/common.sh"
fi

# === CONTENU SPÉCIALISÉ FANTASY ===
create_fantasy_content() {
    local project_name="$1"
    local author_name="$2"
    local author_pseudo="$3"

    log_debug "Création contenu fantasy"

    # Répertoire worldbuilding spécifique
    mkdir -p "05-Worldbuilding"

    # Instructions LLM spécialisées fantasy
    create_fantasy_instructions "$project_name" "$author_name" "$author_pseudo"

    # Concepts worldbuilding
    create_fantasy_concepts

    # Premier chapitre exemple fantasy
    create_fantasy_sample_chapter

    log_debug "Contenu fantasy créé"
}

# === INSTRUCTIONS LLM FANTASY ===
create_fantasy_instructions() {
    local project_name="$1"
    local author_name="$2"
    local author_pseudo="$3"

    local instructions_template
    instructions_template=$(find_template "instructions" "fantasy") || {
        log_error "Template instructions fantasy requis"
        return 1
    }

    substitute_template "$instructions_template" "00-instructions-llm/instructions.md" \
        "PROJECT_NAME" "$project_name" \
        "AUTHOR_NAME" "$author_name" \
        "AUTHOR_PSEUDO" "${author_pseudo:-}"

    log_debug "Instructions LLM fantasy créées"
}

# === CONCEPTS FANTASY ===
create_fantasy_concepts() {
    log_debug "Création concepts fantasy"

    # Système magique
    local magie_template
    magie_template=$(find_template "Système-Magique" "fantasy")
    if [[ -n "$magie_template" ]]; then
        substitute_template "$magie_template" "05-Worldbuilding/Système-Magique.md"
    fi

    # Économie magique
    local economie_template
    economie_template=$(find_template "Économie-Magique" "fantasy")
    if [[ -n "$economie_template" ]]; then
        substitute_template "$economie_template" "05-Worldbuilding/Économie-Magique.md"
    fi

    # Conflits politiques
    local conflits_template
    conflits_template=$(find_template "Conflits-Politiques" "fantasy")
    if [[ -n "$conflits_template" ]]; then
        substitute_template "$conflits_template" "05-Worldbuilding/Conflits-Politiques.md"
    fi

    log_debug "Concepts fantasy créés"
}

# === CHAPITRE EXEMPLE FANTASY ===
create_fantasy_sample_chapter() {
    local chapitre_template
    chapitre_template=$(find_template "Premier-Chapitre" "fantasy") || {
        log_warning "Template premier chapitre fantasy non trouvé"
        return 0
    }

    substitute_template "$chapitre_template" "01-Manuscrit/Ch01-Premier-Chapitre.md"

    log_debug "Chapitre exemple fantasy créé"
}

# === EXPORT FONCTIONS ===
export -f create_fantasy_content
export -f create_fantasy_instructions
export -f create_fantasy_concepts
export -f create_fantasy_sample_chapter

# Marquer module comme chargé
readonly SILK_TEMPLATES_FANTASY_LOADED=true
