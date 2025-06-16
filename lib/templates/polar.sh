#!/bin/bash
# lib/templates/polar.sh - SILK Templates - Polar psychologique (version finale)

# Charger les fonctions communes
if [[ "${SILK_TEMPLATES_COMMON_LOADED:-false}" != "true" ]]; then
    source "${SILK_LIB_DIR}/templates/common.sh"
fi

# === CONTENU SPÉCIALISÉ POLAR ===
create_polar_psychologique_content() {
    local project_name="$1"
    local author_name="$2"
    local author_pseudo="$3"

    log_debug "Création contenu polar psychologique"

    # Instructions LLM spécialisées polar
    create_polar_instructions "$project_name" "$author_name" "$author_pseudo"

    # Concepts mécaniques polar
    create_polar_concepts

    # Premier chapitre exemple polar
    create_polar_sample_chapter

    log_debug "Contenu polar psychologique créé"
}

# === INSTRUCTIONS LLM POLAR ===
create_polar_instructions() {
    local project_name="$1"
    local author_name="$2"
    local author_pseudo="$3"

    local instructions_template
    instructions_template=$(find_template "instructions" "polar-psychologique") || {
        log_error "Template instructions polar requis"
        return 1
    }

    substitute_template "$instructions_template" "00-instructions-llm/instructions.md" \
        "PROJECT_NAME" "$project_name" \
        "AUTHOR_NAME" "$author_name" \
        "AUTHOR_PSEUDO" "${author_pseudo:-}"

    log_debug "Instructions LLM polar créées"
}

# === CONCEPTS POLAR ===
create_polar_concepts() {
    log_debug "Création concepts polar"

    # Structure d'enquête
    local enquete_template
    enquete_template=$(find_template "polar-enquete.md" "polar-psychologique")
    if [[ -n "$enquete_template" ]]; then
        substitute_template "$enquete_template" "04-Concepts/Enquête-Structure.md"
    fi

    # Mécaniques suspense
    local suspense_template
    suspense_template=$(find_template "Mécaniques-Suspense" "polar-psychologique")
    if [[ -n "$suspense_template" ]]; then
        substitute_template "$suspense_template" "04-Concepts/Mécaniques-Suspense.md"
    fi

    # Révélations timeline
    local revelations_template
    revelations_template=$(find_template "Révélations-Timeline" "polar-psychologique")
    if [[ -n "$revelations_template" ]]; then
        substitute_template "$revelations_template" "04-Concepts/Révélations-Timeline.md"
    fi

    # Psychologie personnages
    local psycho_template
    psycho_template=$(find_template "Psychologie-Personnages" "polar-psychologique")
    if [[ -n "$psycho_template" ]]; then
        substitute_template "$psycho_template" "04-Concepts/Psychologie-Personnages.md"
    fi

    # Techniques investigation
    local techniques_template
    techniques_template=$(find_template "Techniques-Investigation" "polar-psychologique")
    if [[ -n "$techniques_template" ]]; then
        substitute_template "$techniques_template" "04-Concepts/Techniques-Investigation.md"
    fi

    log_debug "Concepts polar créés"
}

# === CHAPITRE EXEMPLE POLAR ===
create_polar_sample_chapter() {
    local chapitre_template
    chapitre_template=$(find_template "Premier-Chapitre" "polar-psychologique") || {
        log_warning "Template premier chapitre polar non trouvé, utilisation générique"
        return 0
    }

    substitute_template "$chapitre_template" "01-Manuscrit/Ch01-Premier-Chapitre.md"

    log_debug "Chapitre exemple polar créé"
}

# === EXPORT FONCTIONS ===
export -f create_polar_psychologique_content
export -f create_polar_instructions
export -f create_polar_concepts
export -f create_polar_sample_chapter

# Marquer module comme chargé
readonly SILK_TEMPLATES_POLAR_LOADED=true
