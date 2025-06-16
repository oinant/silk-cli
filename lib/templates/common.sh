#!/bin/bash
# lib/templates/common.sh - SILK Templates - Fonctions communes (version finale)

# Vérification chargement des dépendances
if [[ "${SILK_CORE_UTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/utils requis" >&2
    exit 1
fi

if [[ "${SILK_CORE_TEMPLATES_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/templates requis" >&2
    exit 1
fi

# === VARIABLES COMMUNES ===
readonly SILK_PROJECT_DIRS=(
    "00-instructions-llm"
    "01-Manuscrit"
    "02-Personnages/Principaux"
    "02-Personnages/Secondaires"
    "03-Lieux"
    "04-Concepts"
    "07-timeline"
    "10-Lore"
    "20-Pitch-Editeurs"
    "21-Planning"
    "50-Sessions-Claude"
    "60-idees-tome-2"
    "99-Templates"
    "formats"
    "outputs/context"
    "outputs/publish"
    "outputs/temp"
)

# === CRÉATION STRUCTURE BASIQUE ===
create_silk_structure() {
    log_debug "Création structure SILK standard"

    for dir in "${SILK_PROJECT_DIRS[@]}"; do
        mkdir -p "$dir"
    done

    log_debug "Structure SILK créée (${#SILK_PROJECT_DIRS[@]} répertoires)"
}

# === INITIALISATION GIT ===
init_git_repository() {
    local project_name="$1"
    local genre="$2"
    local author_name="$3"

    if ! command -v git &> /dev/null; then
        log_debug "Git non disponible, sautera l'initialisation"
        return 0
    fi

    log_debug "Initialisation repository Git"
    git init --quiet

    # Créer .gitignore SILK depuis template
    local gitignore_template
    gitignore_template=$(find_template "gitignore" "common") || {
        log_warning "Template gitignore non trouvé, utilisation par défaut"
        return 0
    }

    substitute_template "$gitignore_template" ".gitignore" \
        "PROJECT_NAME" "$project_name" \
        "GENRE" "$genre" \
        "AUTHOR_NAME" "$author_name"

    # Premier commit
    git add .
    git commit --quiet -m "🕷️ Initial SILK project: $project_name

🕸️ Smart Integrated Literary Kit v${SILK_VERSION}
📚 Projet: $project_name
🎭 Genre: $genre
✍️ Auteur: $author_name

Structure tissée avec templates $genre optimisés.
Ready for: silk context, wordcount, publish"

    log_debug "Repository Git initialisé avec commit initial"
}

# === README PROJET ===
create_project_readme() {
    local project_name="$1"
    local genre="$2"
    local language="$3"
    local target_words="$4"
    local target_chapters="$5"
    local author_name="$6"
    local author_pseudo="$7"

    log_debug "Création README.md projet"

    local readme_template
    readme_template=$(find_template "README" "common") || {
        log_error "Template README requis non trouvé"
        return 1
    }

    substitute_template "$readme_template" "README.md" \
        "PROJECT_NAME" "$project_name" \
        "GENRE" "$genre" \
        "LANGUAGE" "$language" \
        "TARGET_WORDS" "$target_words" \
        "TARGET_CHAPTERS" "$target_chapters" \
        "AUTHOR_NAME" "$author_name" \
        "AUTHOR_PSEUDO" "${author_pseudo:-}" \
        "SILK_VERSION" "$SILK_VERSION"

    log_debug "README.md créé avec substitutions"
}

# === CONFIGURATION PUBLICATION ===
create_publishing_config() {
    local project_name="$1"
    local author_name="$2"

    log_debug "Création configuration publication"

    # Configuration de base YAML depuis template
    local base_yaml_template
    base_yaml_template=$(find_template "base" "formats") || {
        log_warning "Template base.yaml non trouvé"
        return 1
    }

    substitute_template "$base_yaml_template" "formats/base.yaml" \
        "PROJECT_NAME" "$project_name" \
        "AUTHOR_NAME" "$author_name" \
        "DATE" "$(date '+%Y-%m-%d')"

    # Copier autres formats (statiques)
    local formats=("digital" "iphone" "kindle" "book")
    for format in "${formats[@]}"; do
        local format_file="$SILK_LIB_DIR/templates/formats/${format}.yaml"
        if [[ -f "$format_file" ]]; then
            cp "$format_file" "formats/"
            log_debug "Format $format copié"
        fi
    done

    log_debug "Configuration publication créée (${#formats[@]} formats)"
}

# === TEMPLATES UNIVERSELS ===
create_universal_templates() {
    log_debug "Création templates universels"

    # Template chapitre générique
    local chapitre_template
    chapitre_template=$(find_template "Template-Chapitre" "common")
    if [[ -n "$chapitre_template" ]]; then
        substitute_template "$chapitre_template" "99-Templates/Template-Chapitre.md" \
            "SILK_VERSION" "$SILK_VERSION"
    fi

    # Template personnage générique
    local personnage_template
    personnage_template=$(find_template "Template-Personnage" "common")
    if [[ -n "$personnage_template" ]]; then
        substitute_template "$personnage_template" "99-Templates/Template-Personnage.md" \
            "SILK_VERSION" "$SILK_VERSION"
    fi

    # Personnage principal exemple
    local protagoniste_template
    protagoniste_template=$(find_template "Protagoniste" "common")
    if [[ -n "$protagoniste_template" ]]; then
        substitute_template "$protagoniste_template" "02-Personnages/Protagoniste.md" \
            "SILK_VERSION" "$SILK_VERSION"
    fi

    log_debug "Templates universels créés"
}

# === WORKFLOW CRÉATION PROJET COMPLET ===
create_complete_silk_project() {
    local project_name="$1"
    local genre="$2"
    local language="$3"
    local target_words="$4"
    local target_chapters="$5"
    local author_name="$6"
    local author_pseudo="$7"

    # Nom du répertoire sécurisé
    local project_dir
    project_dir=$(sanitize_project_directory_name "$project_name")

    if [[ -d "$project_dir" ]]; then
        log_error "Le répertoire '$project_dir' existe déjà"
        return 1
    fi

    log_info "🕸️ Tissage du projet '$project_name' dans '$project_dir'"

    # Créer et entrer dans le répertoire
    mkdir -p "$project_dir"
    cd "$project_dir"

    # 1. Structure de base
    create_silk_structure

    # 2. Contenu selon le genre (délégué aux modules spécialisés)
    local normalized_genre="${genre//-/_}"  # polar-psychologique → polar_psychologique

    if declare -f "create_${normalized_genre}_content" &>/dev/null; then
        log_debug "Utilisation template spécialisé: $genre"
        "create_${normalized_genre}_content" "$project_name" "$author_name" "$author_pseudo"
    else
        log_debug "Utilisation template générique pour genre: $genre"
        create_generic_content "$project_name" "$author_name" "$author_pseudo"
    fi

    # 3. Templates universels
    create_universal_templates

    # 4. README projet
    create_project_readme "$project_name" "$genre" "$language" "$target_words" "$target_chapters" "$author_name" "$author_pseudo"

    # 5. Configuration publication
    create_publishing_config "$project_name" "$author_name"

    # 6. Git
    init_git_repository "$project_name" "$genre" "$author_name"

    # 7. Validation
    if validate_created_project "$PWD"; then
        log_success "Projet '$project_name' tissé avec succès !"

        echo
        log_info "Prochaines étapes:"
        echo "  cd $project_dir"
        echo "  silk context --help     # Contexte LLM optimisé"
        echo "  silk wordcount          # Suivi progression"
        echo "  silk publish --help     # Publication PDF"
        echo
        echo "🕸️ SILK has woven your literary foundation. Begin writing!"

        return 0
    else
        log_error "Validation projet échouée"
        cd ..
        cleanup_failed_project "$project_dir"
        return 1
    fi
}

# === FONCTIONS UTILITAIRES ===
sanitize_project_directory_name() {
    local project_name="$1"

    # Convertir en nom de répertoire valide
    local dir_name="${project_name// /-}"  # Espaces → tirets
    dir_name="${dir_name,,}"                # Minuscules
    dir_name="${dir_name//[^a-z0-9_-]/}"   # Caractères alphanumériques uniquement

    echo "$dir_name"
}

# === CONTENU GÉNÉRIQUE (fallback) ===
create_generic_content() {
    local project_name="$1"
    local author_name="$2"
    local author_pseudo="$3"

    log_debug "Création contenu générique"

    # Instructions LLM génériques
    local instructions_template
    instructions_template=$(find_template "instructions-generiques" "common")
    if [[ -n "$instructions_template" ]]; then
        substitute_template "$instructions_template" "00-instructions-llm/instructions.md" \
            "PROJECT_NAME" "$project_name" \
            "AUTHOR_NAME" "$author_name" \
            "AUTHOR_PSEUDO" "${author_pseudo:-}"
    fi

    # Concepts génériques
    local structure_template
    structure_template=$(find_template "Structure-Narrative" "common")
    if [[ -n "$structure_template" ]]; then
        substitute_template "$structure_template" "04-Concepts/Structure-Narrative.md"
    fi

    # Premier chapitre exemple
    local chapitre_template
    chapitre_template=$(find_template "Premier-Chapitre-Generique" "common")
    if [[ -n "$chapitre_template" ]]; then
        substitute_template "$chapitre_template" "01-Manuscrit/Ch01-Premier-Chapitre.md" \
            "PROJECT_NAME" "$project_name"
    fi

    log_debug "Contenu générique créé"
}

# === VALIDATION PROJET ===
validate_created_project() {
    local project_dir="$1"

    if [[ ! -d "$project_dir" ]]; then
        log_error "Projet non créé: $project_dir"
        return 1
    fi

    log_debug "Validation projet dans $project_dir"

    # Vérifier fichiers essentiels
    local required_files=(
        "README.md"
        "01-Manuscrit"
        "02-Personnages"
        "99-Templates"
        "formats"
    )

    local missing_files=()
    for file in "${required_files[@]}"; do
        if [[ ! -e "$project_dir/$file" ]]; then
            missing_files+=("$file")
        fi
    done

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_warning "Fichiers manquants: ${missing_files[*]}"
        return 1
    fi

    log_debug "Validation projet terminée"
    return 0
}

# === NETTOYAGE ERREUR ===
cleanup_failed_project() {
    local project_dir="$1"

    if [[ -n "$project_dir" && -d "$project_dir" ]]; then
        log_warning "Nettoyage projet incomplet: $project_dir"
        rm -rf "$project_dir"
        log_debug "Projet $project_dir supprimé"
    fi
}

# === SETUP INTERACTIF (commun à tous genres) ===
run_interactive_setup() {
    local -n proj_name=$1
    local -n proj_genre=$2
    local -n proj_language=$3
    local -n proj_target_words=$4
    local -n proj_target_chapters=$5
    local -n proj_author_name=$6
    local -n proj_author_pseudo=$7

    log_header "SILK INIT - Smart Integrated Literary Kit"
    echo -e "${CYAN}Tissons ensemble votre nouveau projet littéraire...${NC}"
    echo

    # Nom du projet
    if [[ -z "$proj_name" ]]; then
        read -p "📖 Nom du projet: " proj_name
    fi

    # Genre avec liste des disponibles
    echo -e "\n🎭 Genres disponibles:"
    get_available_templates | while read -r template; do
        local desc=$(get_template_description "$template")
        echo "   $template - $desc"
    done
    echo
    read -p "🎭 Genre [$proj_genre]: " input_genre
    proj_genre="${input_genre:-$proj_genre}"

    # Autres paramètres
    read -p "🌍 Langue [$proj_language]: " input_language
    proj_language="${input_language:-$proj_language}"

    read -p "📊 Objectif mots [$proj_target_words]: " input_words
    proj_target_words="${input_words:-$proj_target_words}"

    read -p "📚 Nombre chapitres [$proj_target_chapters]: " input_chapters
    proj_target_chapters="${input_chapters:-$proj_target_chapters}"

    read -p "✍️  Nom auteur [$proj_author_name]: " input_author
    proj_author_name="${input_author:-$proj_author_name}"

    read -p "🎭 Pseudonyme [$proj_author_pseudo]: " input_pseudo
    proj_author_pseudo="${input_pseudo:-$proj_author_pseudo}"
}

# === EXPORT FONCTIONS ===
export -f create_silk_structure init_git_repository create_project_readme
export -f create_publishing_config create_universal_templates
export -f create_complete_silk_project sanitize_project_directory_name
export -f create_generic_content validate_created_project cleanup_failed_project
export -f run_interactive_setup

# Marquer module comme chargé
readonly SILK_TEMPLATES_COMMON_LOADED=true
