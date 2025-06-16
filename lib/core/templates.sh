#!/bin/bash
# lib/core/templates.sh - Système de gestion des templates SILK

# Vérification dépendances
if [[ "${SILK_CORE_UTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/utils requis" >&2
    exit 1
fi

# === INITIALISATION SILK_LIB_DIR ===
init_silk_lib_dir() {
    # Si SILK_LIB_DIR est déjà définie et valide, on garde
    if [[ -n "${SILK_LIB_DIR:-}" && -d "$SILK_LIB_DIR" ]]; then
        log_debug "SILK_LIB_DIR déjà définie: $SILK_LIB_DIR"
        return 0
    fi

    # Auto-détection du répertoire lib/
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local lib_candidates=(
        "$script_dir/.."          # Si on est dans lib/core/
        "$script_dir"             # Si on est dans lib/
        "$PWD/lib"                # Depuis la racine du projet
        "$script_dir/../../lib"   # Si on est dans lib/core/templates/
    )

    for candidate in "${lib_candidates[@]}"; do
        if [[ -d "$candidate" && -d "$candidate/templates" ]]; then
            export SILK_LIB_DIR="$candidate"
            log_debug "SILK_LIB_DIR auto-détectée: $SILK_LIB_DIR"
            return 0
        fi
    done

    # Fallback final
    export SILK_LIB_DIR="lib"
    log_debug "SILK_LIB_DIR fallback: $SILK_LIB_DIR"
}

# Initialiser dès le chargement du module
init_silk_lib_dir

# === FONCTION PRINCIPALE SUBSTITUTION ===
substitute_template() {
    local template_file="$1"
    local output_file="$2"
    shift 2

    # Vérifications de base
    if [[ ! -f "$template_file" ]]; then
        log_error "Template introuvable: $template_file"
        return 1
    fi

    if [[ -z "$output_file" ]]; then
        log_error "Fichier de sortie requis"
        return 1
    fi

    log_debug "📝 Substitution template: $template_file → $output_file"

    # Lecture du template
    local template_content
    template_content=$(cat "$template_file") || {
        log_error "Impossible de lire le template: $template_file"
        return 1
    }

    # Application des substitutions
    local result="$template_content"

    # Substitution par paires key=value
    while [[ $# -ge 2 ]]; do
        local key="$1"
        local value="$2"

        log_debug "  Substitution: {{$key}} → $value"

        # Utiliser sed avec support des espaces optionnels
        result=$(echo "$result" | sed "s/{{[[:space:]]*${key}[[:space:]]*}}/${value}/g")

        shift 2
    done

    # Créer le répertoire de sortie si nécessaire
    local output_dir=$(dirname "$output_file")
    if [[ ! -d "$output_dir" ]]; then
        mkdir -p "$output_dir" || {
            log_error "Impossible de créer le répertoire: $output_dir"
            return 1
        }
    fi

    # Écrire le résultat
    echo "$result" > "$output_file" || {
        log_error "Impossible d'écrire le fichier: $output_file"
        return 1
    }

    log_success "✅ Template substitué: $output_file"
    return 0
}

# === FONCTION AUXILIAIRE AVEC VARIABLES PRÉDÉFINIES ===
substitute_template_with_defaults() {
    local template_file="$1"
    local output_file="$2"
    local project_name="${3:-$PROJECT_NAME}"
    local author_name="${4:-$SILK_AUTHOR_NAME}"
    local project_subtitle="${5:-}"
    local genre="${6:-$SILK_DEFAULT_GENRE}"

    substitute_template "$template_file" "$output_file" \
        "PROJECT_NAME" "$project_name" \
        "AUTHOR_NAME" "$author_name" \
        "PROJECT_SUBTITLE" "$project_subtitle" \
        "GENRE" "$genre"
}

# === RECHERCHE HIÉRARCHIQUE DES TEMPLATES ===
find_template() {
    local template_name="$1"
    local genre="${2:-}"

    # Déterminer le répertoire de base SILK
    local silk_base_dir="${SILK_LIB_DIR:-}"

    # Si SILK_LIB_DIR est vide, utiliser détection automatique
    if [[ -z "$silk_base_dir" ]]; then
        # Chercher lib/ depuis le script courant ou PWD
        if [[ -d "lib" ]]; then
            silk_base_dir="lib"
        elif [[ -d "../lib" ]]; then
            silk_base_dir="../lib"
        elif [[ -d "$PWD/lib" ]]; then
            silk_base_dir="$PWD/lib"
        else
            # Fallback: chercher depuis le répertoire du script principal
            local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            if [[ -d "$script_dir/../lib" ]]; then
                silk_base_dir="$script_dir/../lib"
            elif [[ -d "$script_dir/lib" ]]; then
                silk_base_dir="$script_dir/lib"
            else
                silk_base_dir="lib"  # Fallback final
            fi
        fi
    fi

    log_debug "Recherche template avec base_dir: $silk_base_dir"

    # Recherche hiérarchique: genre-spécifique → common → formats
    # Support pour .template, .yaml, .md et sans extension
    local search_paths=(
        "${silk_base_dir}/templates/${genre}/${template_name}.template"
        "${silk_base_dir}/templates/common/${template_name}.template"
        "${silk_base_dir}/templates/formats/${template_name}.template"
        "${silk_base_dir}/templates/formats/${template_name}.yaml"
        "${silk_base_dir}/templates/formats/${template_name}.md"
        "formats/${template_name}.template"
        "formats/${template_name}.yaml"
        "formats/${template_name}.md"
        "${silk_base_dir}/templates/${genre}/${template_name}"
        "${silk_base_dir}/templates/common/${template_name}"
        "formats/${template_name}"
        # Fallbacks absolus pour compatibilité
        "lib/templates/${genre}/${template_name}.template"
        "lib/templates/common/${template_name}.template"
        "lib/templates/formats/${template_name}.yaml"
    )

    log_debug "Chemins de recherche pour '$template_name' (genre: ${genre:-aucun}):"
    for path in "${search_paths[@]}"; do
        log_debug "  - $path"
        if [[ -f "$path" ]]; then
            log_debug "  ✅ Trouvé: $path"
            echo "$path"
            return 0
        fi
    done

    log_debug "❌ Template non trouvé: $template_name (genre: ${genre:-aucun})"
    return 1
}

# === VALIDATION TEMPLATE ===
validate_template() {
    local template_file="$1"

    if [[ ! -f "$template_file" ]]; then
        log_error "Template inexistant: $template_file"
        return 1
    fi

    if [[ ! -r "$template_file" ]]; then
        log_error "Template non lisible: $template_file"
        return 1
    fi

    # Vérifier présence de variables de substitution
    local vars_count=$(grep -c "{{.*}}" "$template_file" 2>/dev/null || echo "0")
    log_debug "Variables trouvées dans template: $vars_count"

    return 0
}

# === LISTAGE TEMPLATES DISPONIBLES ===
list_available_templates() {
    local search_dir="${1:-${SILK_LIB_DIR:-lib}/templates}"

    if [[ ! -d "$search_dir" ]]; then
        log_warning "Répertoire templates inexistant: $search_dir"
        return 1
    fi

    log_info "📚 Templates disponibles dans $search_dir:"
    find "$search_dir" -name "*.template" -o -name "*.yaml" | while read -r template; do
        local relative_path="${template#$search_dir/}"
        echo "  - $relative_path"
    done
}

# === EXTRACTION VARIABLES D'UN TEMPLATE ===
extract_template_variables() {
    local template_file="$1"

    if [[ ! -f "$template_file" ]]; then
        log_error "Template inexistant: $template_file"
        return 1
    fi

    # Extraire toutes les variables {{VARIABLE}}
    grep -o "{{[^}]*}}" "$template_file" 2>/dev/null | \
        sed 's/{{[[:space:]]*//g' | \
        sed 's/[[:space:]]*}}//g' | \
        sort -u
}

# === SUBSTITUTION BATCH (PLUSIEURS TEMPLATES) ===
substitute_template_batch() {
    local template_dir="$1"
    local output_dir="$2"
    shift 2
    local template_vars=("$@")

    if [[ ! -d "$template_dir" ]]; then
        log_error "Répertoire template inexistant: $template_dir"
        return 1
    fi

    local processed=0
    local failed=0

    while IFS= read -r -d '' template_file; do
        local relative_path="${template_file#$template_dir/}"
        local output_file="$output_dir/${relative_path%.template}"

        log_debug "Traitement batch: $relative_path"

        if substitute_template "$template_file" "$output_file" "${template_vars[@]}"; then
            ((processed++))
        else
            ((failed++))
            log_warning "Échec substitution: $relative_path"
        fi
    done < <(find "$template_dir" -name "*.template" -type f -print0)

    log_info "📊 Substitution batch terminée: $processed réussis, $failed échecs"
    return $failed
}

# === HELPERS POUR TYPES DE TEMPLATES SPÉCIFIQUES ===

# Templates YAML (formats de publication)
substitute_yaml_template() {
    local template_name="$1"
    local output_file="$2"
    shift 2

    local template_file
    template_file=$(find_template "$template_name" "formats")

    if [[ $? -eq 0 ]]; then
        substitute_template "$template_file" "$output_file" "$@"
    else
        log_warning "Template YAML non trouvé: $template_name"
        return 1
    fi
}

# Templates Markdown
substitute_markdown_template() {
    local template_name="$1"
    local output_file="$2"
    local genre="${3:-}"
    shift 3

    local template_file
    template_file=$(find_template "$template_name" "$genre")

    if [[ $? -eq 0 ]]; then
        substitute_template "$template_file" "$output_file" "$@"
    else
        log_warning "Template Markdown non trouvé: $template_name"
        return 1
    fi
}

# === AUTO-TEST MODULE ===
templates_self_test() {
    log_debug "Auto-test module templates.sh..."

    # Test basique de substitution
    local test_content="Hello {{NAME}}, welcome to {{PROJECT}}!"
    local test_file="/tmp/silk_template_test.$$"
    local test_output="/tmp/silk_output_test.$$"

    echo "$test_content" > "$test_file"

    if substitute_template "$test_file" "$test_output" "NAME" "SILK" "PROJECT" "Testing"; then
        local result=$(cat "$test_output")
        if [[ "$result" == "Hello SILK, welcome to Testing!" ]]; then
            log_debug "Auto-test templates.sh réussi"
            rm -f "$test_file" "$test_output"
            return 0
        fi
    fi

    log_error "Auto-test templates.sh échoué"
    rm -f "$test_file" "$test_output"
    return 1
}

# === EXPORT FONCTIONS ===
export -f substitute_template substitute_template_with_defaults
export -f find_template validate_template
export -f list_available_templates extract_template_variables
export -f substitute_template_batch
export -f substitute_yaml_template substitute_markdown_template
export -f templates_self_test init_silk_lib_dir

# Marquer module comme chargé
readonly SILK_CORE_TEMPLATES_LOADED=true

log_debug "Module templates.sh chargé avec SILK_LIB_DIR=${SILK_LIB_DIR:-non définie}"
