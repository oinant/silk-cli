#!/bin/bash
# lib/commands/init.sh - Commande SILK init (version modulaire)

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
    local genre="${SILK_DEFAULT_GENRE:-polar-psychologique}"
    local language="${SILK_DEFAULT_LANGUAGE:-fr}"
    local target_words="${SILK_DEFAULT_TARGET_WORDS:-80000}"
    local target_chapters="${SILK_DEFAULT_CHAPTERS:-30}"
    local author_name="${SILK_AUTHOR_NAME:-}"
    local author_pseudo="${SILK_AUTHOR_PSEUDO:-}"
    local interactive=true

    # Parse arguments
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

    # Création du projet via common.sh
    create_complete_silk_project "$project_name" "$genre" "$language" "$target_words" "$target_chapters" "$author_name" "$author_pseudo"
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

SILK = Smart Integrated Literary Kit
Tisse ensemble tous les éléments de votre roman comme une araignée tisse sa toile.
HELP
}

# === EXPORT FONCTIONS ===
export -f cmd_init
export -f show_init_help
export -f load_genre_template

# Marquer module comme chargé
readonly SILK_COMMAND_INIT_LOADED=true
