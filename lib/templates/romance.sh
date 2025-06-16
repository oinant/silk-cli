#!/bin/bash
# lib/templates/romance.sh - SILK Templates - Romance/Sentimental

# Charger les fonctions communes
if [[ "${SILK_TEMPLATES_COMMON_LOADED:-false}" != "true" ]]; then
    source "${SILK_LIB_DIR}/templates/common.sh"
fi

# === CONTENU SPÉCIALISÉ ROMANCE ===
create_romance_content() {
    local project_name="$1"
    local author_name="$2"
    local author_pseudo="$3"

    log_debug "Création contenu romance"

    # Instructions LLM spécialisées romance
    create_romance_instructions "$project_name" "$author_name" "$author_pseudo"

    # Concepts romance
    create_romance_concepts

    # Premier chapitre exemple romance
    create_romance_sample_chapter

    log_debug "Contenu romance créé"
}

# === INSTRUCTIONS LLM ROMANCE ===
create_romance_instructions() {
    local project_name="$1"
    local author_name="$2"
    local author_pseudo="$3"

    local instructions_template
    instructions_template=$(find_template "instructions" "romance") || {
        log_error "Template instructions romance requis"
        return 1
    }

    substitute_template "$instructions_template" "00-instructions-llm/instructions.md" \
        "PROJECT_NAME" "$project_name" \
        "AUTHOR_NAME" "$author_name" \
        "AUTHOR_PSEUDO" "${author_pseudo:-}"

    log_debug "Instructions LLM romance créées"
}

# === CONCEPTS ROMANCE ===
create_romance_concepts() {
    log_debug "Création concepts romance"

    # Arc relationnel
    local arc_template
    arc_template=$(find_template "Arc-Relationnel" "romance")
    if [[ -n "$arc_template" ]]; then
        substitute_template "$arc_template" "04-Concepts/Arc-Relationnel.md"
    fi

    # Obstacles narratifs
    local obstacles_template
    obstacles_template=$(find_template "Obstacles-Narratifs" "romance")
    if [[ -n "$obstacles_template" ]]; then
        substitute_template "$obstacles_template" "04-Concepts/Obstacles-Narratifs.md"
    fi

    # Tension sexuelle
    local tension_template
    tension_template=$(find_template "Tension-Sexuelle" "romance")
    if [[ -n "$tension_template" ]]; then
        substitute_template "$tension_template" "04-Concepts/Tension-Sexuelle.md"
    fi

    log_debug "Concepts romance créés"
}

# === CHAPITRE EXEMPLE ROMANCE ===
create_romance_sample_chapter() {
    local chapitre_template
    chapitre_template=$(find_template "Premier-Chapitre" "romance") || {
        log_warning "Template premier chapitre romance non trouvé"
        return 0
    }

    substitute_template "$chapitre_template" "01-Manuscrit/Ch01-Premier-Chapitre.md"

    log_debug "Chapitre exemple romance créé"
}

# === EXPORT FONCTIONS ===
export -f create_romance_content
export -f create_romance_instructions
export -f create_romance_concepts
export -f create_romance_sample_chapter

# Marquer module comme chargé
readonly SILK_TEMPLATES_ROMANCE_LOADED=true
