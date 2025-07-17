#!/bin/bash
# lib/commands/config.sh - Commande SILK config (version locale par projet)

# Vérification chargement des dépendances
if [[ "${SILK_CORE_UTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/utils requis" >&2
    exit 1
fi

# === CONFIGURATION PROJET ===
SILK_CONFIG_FILE=".silk/config"
SILK_CONFIG_KEYS=(
    "TITLE"
    "GENRE"
    "LANGUAGE"
    "TARGET_WORDS"
    "TARGET_CHAPTERS"
    "DEFAULT_FORMAT"
    "AUTHOR_NAME"
    "AUTHOR_PSEUDO"
    "COVER"
)

# === FONCTIONS CONFIGURATION ===
silk_project_config_load() {
    # Valeurs par défaut
    TITLE=""
    GENRE="polar-psychologique"
    LANGUAGE="fr"
    TARGET_WORDS="80000"
    TARGET_CHAPTERS="30"
    DEFAULT_FORMAT="digital"
    AUTHOR_NAME=""
    AUTHOR_PSEUDO=""
    COVER=""

    # Charger depuis fichier si existe
    if [[ -f "$SILK_CONFIG_FILE" ]]; then
        source "$SILK_CONFIG_FILE"
        log_debug "Configuration projet chargée: $SILK_CONFIG_FILE"
        return 0
    else
        log_debug "Aucune configuration projet trouvée: $SILK_CONFIG_FILE"
        return 1
    fi
}

silk_project_config_save() {
    # Créer le répertoire .silk si nécessaire
    mkdir -p "$(dirname "$SILK_CONFIG_FILE")"

    cat > "$SILK_CONFIG_FILE" << EOF
# SILK Project Configuration
# Generated: $(date)

TITLE="$TITLE"
GENRE="$GENRE"
LANGUAGE="$LANGUAGE"
TARGET_WORDS="$TARGET_WORDS"
TARGET_CHAPTERS="$TARGET_CHAPTERS"
DEFAULT_FORMAT="$DEFAULT_FORMAT"
AUTHOR_NAME="$AUTHOR_NAME"
AUTHOR_PSEUDO="$AUTHOR_PSEUDO"
COVER="$COVER"
EOF

    log_debug "Configuration projet sauvegardée: $SILK_CONFIG_FILE"
}

silk_project_config_init() {
    # Créer config avec valeurs par défaut
    silk_project_config_load || true  # Ignorer si pas de fichier
    silk_project_config_save
    log_success "Configuration projet initialisée dans $SILK_CONFIG_FILE"
}

silk_project_config_set() {
    local key="$1"
    local value="$2"

    # Valider la clé
    if [[ ! " ${SILK_CONFIG_KEYS[*]} " =~ " ${key} " ]]; then
        log_error "Clé configuration inconnue: $key"
        echo "Clés disponibles: ${SILK_CONFIG_KEYS[*]}"
        return 1
    fi

    # Charger config actuelle
    silk_project_config_load || true

    # Validation spécifique selon la clé
    case "$key" in
        TITLE)
            if [[ -z "$value" ]]; then
                log_error "Le titre ne peut pas être vide"
                return 1
            fi
            TITLE="$value"
            ;;
        GENRE)
            # TODO: Validation genre si nécessaire
            GENRE="$value"
            ;;
        LANGUAGE)
            if [[ ! "$value" =~ ^[a-z]{2}$ ]]; then
                log_error "Code langue invalide: $value (format: fr, en, es...)"
                return 1
            fi
            LANGUAGE="$value"
            ;;
        TARGET_WORDS)
            if [[ ! "$value" =~ ^[0-9]+$ ]] || [[ "$value" -lt 1000 ]]; then
                log_error "Nombre de mots invalide: $value (minimum 1000)"
                return 1
            fi
            TARGET_WORDS="$value"
            ;;
        TARGET_CHAPTERS)
            if [[ ! "$value" =~ ^[0-9]+$ ]] || [[ "$value" -lt 1 ]] || [[ "$value" -gt 100 ]]; then
                log_error "Nombre de chapitres invalide: $value (1-100)"
                return 1
            fi
            TARGET_CHAPTERS="$value"
            ;;
        DEFAULT_FORMAT)
            if [[ ! "$value" =~ ^(digital|print|ebook|pdf)$ ]]; then
                log_error "Format invalide: $value (digital, print, ebook, pdf)"
                return 1
            fi
            DEFAULT_FORMAT="$value"
            ;;
        AUTHOR_NAME)
            AUTHOR_NAME="$value"
            ;;
        AUTHOR_PSEUDO)
            AUTHOR_PSEUDO="$value"
            ;;
        COVER)
            COVER="$value"
            ;;
    esac

    # Sauvegarder
    silk_project_config_save
    log_success "Configuration mise à jour: $key=$value"
}

silk_project_config_get() {
    local key="$1"

    # Charger config
    silk_project_config_load || true

    case "$key" in
        TITLE) echo "$TITLE" ;;
        GENRE) echo "$GENRE" ;;
        LANGUAGE) echo "$LANGUAGE" ;;
        TARGET_WORDS) echo "$TARGET_WORDS" ;;
        TARGET_CHAPTERS) echo "$TARGET_CHAPTERS" ;;
        DEFAULT_FORMAT) echo "$DEFAULT_FORMAT" ;;
        AUTHOR_NAME) echo "$AUTHOR_NAME" ;;
        AUTHOR_PSEUDO) echo "$AUTHOR_PSEUDO" ;;
        COVER) echo "$COVER" ;;
        *)
            log_error "Clé inconnue: $key"
            return 1
            ;;
    esac
}

silk_project_config_list() {
    # Charger config
    silk_project_config_load || true

    echo "🕷️ SILK Configuration Projet"
    echo "============================"
    echo "Titre                   : ${TITLE:-non défini}"
    echo "Genre                   : ${GENRE}"
    echo "Langue                  : ${LANGUAGE}"
    echo "Objectif mots           : ${TARGET_WORDS}"
    echo "Nombre chapitres        : ${TARGET_CHAPTERS}"
    echo "Format par défaut       : ${DEFAULT_FORMAT}"
    echo "Nom auteur              : ${AUTHOR_NAME:-non défini}"
    echo "Pseudonyme auteur       : ${AUTHOR_PSEUDO:-non défini}"
    echo "Image de couverture     : ${COVER:-non définie}"
    echo ""
    echo "📁 Fichier config       : $SILK_CONFIG_FILE"

    if [[ -f "$SILK_CONFIG_FILE" ]]; then
        echo "📅 Dernière modification : $(date -r "$SILK_CONFIG_FILE" 2>/dev/null || echo 'inconnu')"
    else
        echo "⚠️  Fichier non trouvé. Utilisez 'silk config --init' pour créer."
    fi
}

# === COMMANDE PRINCIPALE ===
cmd_config() {
    local action="list"
    local key=""
    local value=""

    # Parser les arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --init)
                action="init"
                shift
                ;;
            --set)
                action="set"
                if [[ "$2" == *"="* ]]; then
                    key="${2%%=*}"
                    value="${2#*=}"
                    shift 2
                else
                    log_error "Format: silk config --set KEY=VALUE"
                    return 1
                fi
                ;;
            --get)
                action="get"
                key="$2"
                if [[ -z "$key" ]]; then
                    log_error "Format: silk config --get KEY"
                    return 1
                fi
                shift 2
                ;;
            --list)
                action="list"
                shift
                ;;
            --help|-h)
                show_config_help
                return 0
                ;;
            *)
                log_error "Option inconnue: $1"
                show_config_help
                return 1
                ;;
        esac
    done

    # Exécuter l'action
    case "$action" in
        init)
            silk_project_config_init
            ;;
        set)
            silk_project_config_set "$key" "$value"
            ;;
        get)
            silk_project_config_get "$key"
            ;;
        list)
            silk_project_config_list
            ;;
        *)
            log_error "Action inconnue: $action"
            return 1
            ;;
    esac
}

# === AIDE ===
show_config_help() {
    cat << 'HELP'
⚙️ SILK CONFIG - Configuration projet

USAGE:
  silk config [OPTIONS]

OPTIONS:
  --init                    Créer fichier config dans projet existant
  --set KEY=VALUE           Définir une configuration
  --get KEY                 Afficher une configuration
  --list                    Afficher toute la configuration (défaut)
  -h, --help                Afficher cette aide

CLÉS DISPONIBLES:
  TITLE                     Titre du roman
  GENRE                     Genre (défaut: polar-psychologique)
  LANGUAGE                  Langue (défaut: fr)
  TARGET_WORDS              Objectif mots (défaut: 80000)
  TARGET_CHAPTERS           Nombre chapitres (défaut: 30)
  DEFAULT_FORMAT            Format publication (défaut: digital)
  AUTHOR_NAME               Nom auteur
  AUTHOR_PSEUDO             Pseudonyme auteur
  COVER                     Cover image path

EXEMPLES:
  silk config --init
  silk config --list
  silk config --set TITLE="Mon Roman Noir"
  silk config --set AUTHOR_NAME="Jane Doe"
  silk config --get TITLE
  silk config --set TARGET_WORDS=120000

FICHIER:
  Configuration stockée dans: .silk/config
  Le fichier est versionné avec le projet.

SILK Smart Integrated Literary Kit
Structured Intelligence for Literary Kreation
HELP
}

# === EXPORT FONCTIONS ===
export -f cmd_config
export -f show_config_help
export -f silk_project_config_load
export -f silk_project_config_save
export -f silk_project_config_set
export -f silk_project_config_get

# Marquer module comme chargé
readonly SILK_COMMAND_CONFIG_LOADED=true
