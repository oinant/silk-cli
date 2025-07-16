#!/bin/bash
# lib/commands/publish.sh - Commande SILK publish (Point d'entrée)

# Vérification chargement des dépendances
if [[ "${SILK_CORE_UTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/utils requis" >&2
    exit 1
fi

if [[ "${SILK_CORE_VAULT_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/vault requis" >&2
    exit 1
fi

# === CONSTANTES MODULE ===
readonly PUBLISH_OUTPUT_DIR="outputs/publish"
readonly PUBLISH_TEMP_DIR="outputs/temp"

# === CHARGEMENT SOUS-MODULES PUBLISH ===
load_publish_modules() {
    local required_modules=(
        "commands/publish/validation.sh"
        "commands/publish/metadata.sh"
        "commands/publish/processing.sh"
        "commands/publish/output.sh"
        "commands/publish/cleanup.sh"
        "commands/publish/reporting.sh"
        "commands/config.sh"
    )

    for module in "${required_modules[@]}"; do
        if ! load_module "$module"; then
            log_error "Impossible de charger le module publish: $module"
            return 1
        fi
    done

    log_debug "Tous les modules publish chargés avec succès"
    return 0
}

# === FONCTION PRINCIPALE ===
cmd_publish() {
    ensure_silk_context

    # Charger les sous-modules de publication
    if ! load_publish_modules; then
        log_error "Échec du chargement des modules publish"
        return 1
    fi

    local format="${DEFAULT_FORMAT:-digital}"
    local max_chapters=99
    local output_name=""
    local french_quotes=false
    local auto_dashes=false
    local include_toc=true
    local include_stats=false
    local dry_run=false
    local embeddable=false

    silk_project_config_load

    # === PARSING DES ARGUMENTS ===
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_publish_help
                return 0
                ;;
            -f|--format)
                if [[ $# -lt 2 ]]; then
                    log_error "Option -f/--format nécessite un argument"
                    return 1
                fi
                format="$2"
                shift 2
                ;;
            -ch|--chapters)
                if [[ $# -lt 2 ]]; then
                    log_error "Option -ch/--chapters nécessite un argument"
                    return 1
                fi
                max_chapters="$2"
                shift 2
                ;;
            -o|--output)
                if [[ $# -lt 2 ]]; then
                    log_error "Option -o/--output nécessite un argument"
                    return 1
                fi
                output_name="$2"
                shift 2
                ;;
            --french-quotes)
                french_quotes=true
                shift
                ;;
            --auto-dashes)
                auto_dashes=true
                shift
                ;;
            --no-toc)
                include_toc=false
                shift
                ;;
            --with-stats)
                include_stats=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --embeddable)
                embeddable=true
                shift
                ;;
            -*)
                log_error "Option inconnue: $1"
                show_publish_help
                return 1
                ;;
            *)
                # Si c'est un nombre, traiter comme max_chapters
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    max_chapters="$1"
                fi
                shift
                ;;
        esac
    done

    # === VALIDATION ===
    if ! validate_format "$format"; then
        return 1
    fi

    if [[ "$dry_run" == "false" ]] && ! validate_dependencies "$format"; then
        show_dependency_help
        return 1
    fi

    log_info "🕸️ SILK tisse votre PDF (format: $format, chapitres: $max_chapters)"

    # === EXÉCUTION ===
    if [[ "$dry_run" == "true" ]]; then
        dry_run_publish "$format" "$max_chapters" "$output_name"
    else
        generate_silk_output "$format" "$max_chapters" "$french_quotes" "$auto_dashes" "$output_name" "$include_toc" "$include_stats" "$embeddable"
    fi
}


validate_dependencies() {
    log_header "Validation Dépendances"
    echo "-----------------------"

    # Dépendances obligatoires
    local required_deps=("bash" "git")
    for dep in "${required_deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            log_success "Dépendance: $dep"
        else
            log_fail "Dépendance manquante: $dep"
        fi
    done

    # Dépendances optionnelles
    local optional_deps=("pandoc" "xelatex")
    for dep in "${optional_deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            log_success "Dépendance optionnelle: $dep"
        else
            log_warning "Dépendance optionnelle manquante: $dep"
        fi
    done

    echo
}



# === AIDE PUBLISH ===
show_publish_help() {
    cat << 'HELP'
📖 SILK PUBLISH - Génération PDF manuscrit professionnel

USAGE:
  silk publish [OPTIONS]

OPTIONS:
  -f, --format FORMAT       Format de sortie (digital, iphone, kindle, book)
  -ch, --chapters NUMBER    Limiter aux N premiers chapitres
  -o, --output NAME         Nom fichier de sortie personnalisé
  --french-quotes           Utiliser guillemets français « »
  --auto-dashes             Ajouter tirets cadratins aux dialogues
  --no-toc                  Ne pas inclure table des matières
  --embeddable              Générer fragment HTML sans <html>/<body> (HTML)
  --with-stats              Inclure page de statistiques
  --dry-run                 Simulation sans génération PDF
  -h, --help                Afficher cette aide

EXEMPLES:
  silk publish                           # Format par défaut
  silk publish -f iphone -ch 10          # Format iPhone, 10 chapitres
  silk publish --french-quotes           # Guillemets français
  silk publish -f book --auto-dashes     # Format livre avec tirets
  silk publish --dry-run                 # Test sans génération
  silk publish -f html --embeddable      # Fragment HTML pour intégration
  silk publish -f html-custom --embeddable  # HTML sémantique embeddable

FORMATS SILK DISPONIBLES:
  digital    Format écran (6"×9", marges 0.5") - lecture confortable
  iphone     Format mobile (4.7"×8.3", marges 0.3") - smartphone
  kindle     Format liseuse (5"×7.5", optimisé e-ink) - Kindle/Kobo
  book       Format livre papier (A5, marges optimisées) - impression
  epub       Format EPUB mobile (reflowable, sans LaTeX requis)
  html       Format HTML avec structure sémantique (sections/articles)

CONVENTIONS MANUSCRIT SILK:
  ~          → Blanc typographique (pause narrative)
  ---        → Transition de scène (*** centrés)
  *texte*    → Indications temporelles/lieu (italique centré)
  [[liens]]  → Liens Obsidian (convertis automatiquement)

DÉPENDANCES REQUISES:
  - Pandoc (https://pandoc.org/installing.html)
  - XeLaTeX (https://www.latex-project.org/get/)

EPUB AVANTAGES:
  ✅ Pas de LaTeX nécessaire
  ✅ Texte adaptable à l'écran
  ✅ Support natif mode sombre
  ✅ Recherche et marque-pages intégrés

SILK weaves your manuscript into beautiful PDF.
HELP
}

# === EXPORT FONCTIONS ===
export -f cmd_publish
export -f show_publish_help

# Marquer module comme chargé
readonly SILK_COMMAND_PUBLISH_LOADED=true
