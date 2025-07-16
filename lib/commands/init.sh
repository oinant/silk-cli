#!/bin/bash
# lib/commands/init.sh - Commande SILK init (version config locale)

# Vérification chargement des dépendances
if [[ "${SILK_CORE_UTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/utils requis" >&2
    exit 1
fi

if [[ "${SILK_CORE_TEMPLATES_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/templates requis" >&2
    exit 1
fi

# Charger fonctions communes templates
if [[ "${SILK_TEMPLATES_COMMON_LOADED:-false}" != "true" ]]; then
    load_module "templates/common.sh"
fi

# === FONCTION PRINCIPALE ===
cmd_init() {
    local project_name=""
    local genre="polar-psychologique"
    local language="fr"
    local target_words="80000"
    local target_chapters="30"
    local author_name=""
    local author_pseudo=""
    local interactive=true

    # Parser arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_init_help
                return 0
                ;;
            -g|--genre)
                genre="$2"
                shift 2
                ;;
            -l|--language)
                language="$2"
                shift 2
                ;;
            -w|--words)
                target_words="$2"
                shift 2
                ;;
            -c|--chapters)
                target_chapters="$2"
                shift 2
                ;;
            -a|--author)
                author_name="$2"
                shift 2
                ;;
            -p|--pseudo)
                author_pseudo="$2"
                shift 2
                ;;
            -y|--yes)
                interactive=false
                shift
                ;;
            -*)
                log_error "Option inconnue: $1"
                return 1
                ;;
            *)
                if [[ -z "$project_name" ]]; then
                    project_name="$1"
                fi
                shift
                ;;
        esac
    done

    # Mode interactif
    if [[ "$interactive" == "true" ]]; then
        run_interactive_setup project_name genre language target_words target_chapters author_name author_pseudo
    fi

    # Validation des paramètres
    if [[ -z "$project_name" ]]; then
        log_error "Nom de projet requis"
        show_init_help
        return 1
    fi

    if ! is_valid_project_name "$project_name"; then
        log_error "Nom de projet invalide: $project_name"
        return 1
    fi

    if ! is_valid_genre "$genre"; then
        log_error "Genre invalide: $genre"
        echo "💡 Genres disponibles: $(get_available_templates | tr '\n' ' ')"
        return 1
    fi

    if ! is_valid_word_count "$target_words"; then
        log_error "Objectif mots invalide: $target_words"
        return 1
    fi

    # Charger le module de template spécialisé selon le genre
    load_genre_template "$genre"

    # Création du projet
    create_silk_project "$project_name" "$genre" "$language" "$target_words" "$target_chapters" "$author_name" "$author_pseudo"
}

# === CRÉATION PROJET ===
create_silk_project() {
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

    # 1. Création de la configuration locale du projet
    create_project_config "$project_name" "$genre" "$language" "$target_words" "$target_chapters" "$author_name" "$author_pseudo"

    # 2. Structure de base
    create_silk_structure

    # 3. Contenu selon le genre (délégué aux modules spécialisés)
    local normalized_genre="${genre//-/_}"  # polar-psychologique → polar_psychologique

    if declare -f "create_${normalized_genre}_content" &>/dev/null; then
        log_debug "Utilisation template spécialisé: $genre"
        "create_${normalized_genre}_content" "$project_name" "$author_name" "$author_pseudo"
    else
        log_debug "Utilisation template générique pour genre: $genre"
        create_generic_content "$project_name" "$author_name" "$author_pseudo"
    fi

    # 4. Templates universels
    create_universal_templates

    # 5. README projet
    create_project_readme "$project_name" "$genre" "$language" "$target_words" "$target_chapters" "$author_name" "$author_pseudo"

    # 6. Configuration publication
    create_publishing_config "$project_name" "$author_name"

    # 7. Git
    init_git_repository "$project_name" "$genre" "$author_name"

    # 8. Validation
    if validate_created_project "$PWD"; then
        log_success "Projet '$project_name' tissé avec succès !"

        echo
        log_info "Prochaines étapes:"
        echo "  cd $project_dir"
        echo "  silk config --list          # Voir configuration projet"
        echo "  silk context --help         # Contexte LLM optimisé"
        echo "  silk wordcount              # Suivi progression"
        echo "  silk publish --help         # Publication PDF"
        echo
        echo "🕸️ SILK has woven your literary foundation. Begin writing!"

        return 0
    else
        log_error "Erreur lors de la validation du projet"
        return 1
    fi
}

# === CRÉATION CONFIGURATION PROJET ===
create_project_config() {
    local project_name="$1"
    local genre="$2"
    local language="$3"
    local target_words="$4"
    local target_chapters="$5"
    local author_name="$6"
    local author_pseudo="$7"

    # Créer le répertoire .silk
    mkdir -p ".silk"

    # Créer le fichier de configuration locale
    cat > ".silk/config" << EOF
# SILK Project Configuration
# Generated: $(date)
# Project: $project_name

TITLE="$project_name"
GENRE="$genre"
LANGUAGE="$language"
TARGET_WORDS="$target_words"
TARGET_CHAPTERS="$target_chapters"
DEFAULT_FORMAT="digital"
AUTHOR_NAME="$author_name"
AUTHOR_PSEUDO="$author_pseudo"
EOF

    log_success "Configuration projet créée dans .silk/config"
}

# === MODE INTERACTIF ===
run_interactive_setup() {
    local -n _project_name=$1
    local -n _genre=$2
    local -n _language=$3
    local -n _target_words=$4
    local -n _target_chapters=$5
    local -n _author_name=$6
    local -n _author_pseudo=$7

    echo "🕷️ Configuration Interactive SILK"
    echo "================================="
    echo

    # Nom du projet
    if [[ -z "$_project_name" ]]; then
        read -p "📖 Nom du projet: " _project_name
    fi

    # Genre
    echo "🎭 Genres disponibles:"
    echo "  1. polar-psychologique (défaut)"
    echo "  2. fantasy"
    echo "  3. romance"
    echo "  4. literary"
    echo "  5. thriller"
    read -p "Genre [1]: " genre_choice
    case "$genre_choice" in
        2) _genre="fantasy" ;;
        3) _genre="romance" ;;
        4) _genre="literary" ;;
        5) _genre="thriller" ;;
        *) _genre="polar-psychologique" ;;
    esac

    # Objectif mots
    read -p "📊 Objectif mots [$_target_words]: " words_input
    if [[ -n "$words_input" ]]; then
        _target_words="$words_input"
    fi

    # Nombre chapitres
    read -p "📑 Nombre de chapitres [$_target_chapters]: " chapters_input
    if [[ -n "$chapters_input" ]]; then
        _target_chapters="$chapters_input"
    fi

    # Auteur
    read -p "✍️  Nom de l'auteur: " _author_name
    read -p "🎭 Pseudonyme (optionnel): " _author_pseudo

    echo
    echo "📋 Résumé:"
    echo "  Projet: $_project_name"
    echo "  Genre: $_genre"
    echo "  Objectif: $_target_words mots"
    echo "  Chapitres: $_target_chapters"
    echo "  Auteur: $_author_name"
    [[ -n "$_author_pseudo" ]] && echo "  Pseudonyme: $_author_pseudo"
    echo

    read -p "Confirmer la création ? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[Nn] ]]; then
        log_info "Création annulée"
        exit 0
    fi
}

# === CHARGEMENT TEMPLATE GENRE ===
load_genre_template() {
    local genre="$1"

    # Normaliser le nom du genre pour le nom de fichier
    local template_file="${genre}.sh"

    # Essayer de charger le template spécialisé
    if [[ -f "$SILK_LIB_DIR/templates/$template_file" ]]; then
        log_debug "Chargement template spécialisé: $template_file"
        load_module "templates/$template_file"
    else
        log_debug "Template spécialisé non trouvé pour '$genre', utilisation générique"
        # Le contenu générique est géré par common.sh
    fi
}

# === AIDE INIT ===
show_init_help() {
    cat << 'HELP'
🕷️ SILK INIT - Créer un nouveau projet littéraire

USAGE:
  silk init [PROJECT_NAME] [OPTIONS]

OPTIONS:
  -g, --genre GENRE          Genre du projet
  -l, --language LANG        Langue (fr, en, es, de)
  -w, --words NUMBER         Objectif mots (défaut: 80000)
  -c, --chapters NUMBER      Nombre de chapitres (défaut: 30)
  -a, --author NAME          Nom auteur
  -p, --pseudo PSEUDO        Pseudonyme auteur
  -y, --yes                  Mode non-interactif
  -h, --help                 Afficher cette aide

EXEMPLES:
  silk init "L'Araignée"                         # Mode interactif
  silk init "Dark Mystery" --genre fantasy       # Projet fantasy
  silk init "Love Story" -w 60000 -c 25 -y      # Romance courte

GENRES SILK DISPONIBLES:
  polar-psychologique    Polar sophistiqué avec éléments psychologiques
  fantasy               Fantasy/fantastique avec worldbuilding
  romance               Romance/sentiment avec développement relationnel
  literary              Littérature générale/contemporaine
  thriller              Thriller/suspense action

CONFIGURATION:
  La configuration du projet est stockée dans .silk/config
  Elle peut être modifiée avec 'silk config --set KEY=VALUE'

SILK = Smart Integrated Literary Kit
Tisse ensemble tous les éléments de votre roman comme une araignée tisse sa toile.

🕸️ SILK weaves your story together.
HELP
}

# === EXPORT FONCTIONS ===
export -f cmd_init
export -f show_init_help
export -f load_genre_template
export -f create_silk_project
export -f create_project_config
export -f run_interactive_setup

# Marquer module comme chargé
readonly SILK_COMMAND_INIT_LOADED=true
