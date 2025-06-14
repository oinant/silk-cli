#!/bin/bash
# lib/core/config.sh - Gestion configuration SILK

# === VARIABLES CONFIGURATION ===
SILK_DEFAULT_GENRE="${SILK_DEFAULT_GENRE:-polar-psychologique}"
SILK_DEFAULT_LANGUAGE="${SILK_DEFAULT_LANGUAGE:-fr}"
SILK_DEFAULT_TARGET_WORDS="${SILK_DEFAULT_TARGET_WORDS:-80000}"
SILK_DEFAULT_CHAPTERS="${SILK_DEFAULT_CHAPTERS:-30}"
SILK_DEFAULT_FORMAT="${SILK_DEFAULT_FORMAT:-digital}"
SILK_AUTHOR_NAME="${SILK_AUTHOR_NAME:-}"
SILK_AUTHOR_PSEUDO="${SILK_AUTHOR_PSEUDO:-}"

# === GESTION CONFIGURATION ===
silk_config_load() {
    if [[ -f "$SILK_CONFIG" ]]; then
        source "$SILK_CONFIG"
        log_debug "Configuration chargée: $SILK_CONFIG"
        return 0
    else
        log_debug "Aucune configuration trouvée: $SILK_CONFIG"
        return 1
    fi
}

silk_config_save() {
    ensure_directory "$(dirname "$SILK_CONFIG")"
    
    cat > "$SILK_CONFIG" << EOF
# SILK Configuration - Smart Integrated Literary Kit
# Généré automatiquement le $(date)

SILK_DEFAULT_GENRE="${SILK_DEFAULT_GENRE}"
SILK_DEFAULT_LANGUAGE="${SILK_DEFAULT_LANGUAGE}"
SILK_DEFAULT_TARGET_WORDS="${SILK_DEFAULT_TARGET_WORDS}"
SILK_DEFAULT_CHAPTERS="${SILK_DEFAULT_CHAPTERS}"
SILK_DEFAULT_FORMAT="${SILK_DEFAULT_FORMAT}"
SILK_AUTHOR_NAME="${SILK_AUTHOR_NAME}"
SILK_AUTHOR_PSEUDO="${SILK_AUTHOR_PSEUDO}"

# Variables d'environnement
SILK_DEBUG="${SILK_DEBUG:-false}"
SILK_HOME="$SILK_HOME"
SILK_LIB_DIR="$SILK_LIB_DIR"
EOF
    
    log_debug "Configuration sauvegardée: $SILK_CONFIG"
}

silk_config_init() {
    # Initialiser avec valeurs par défaut
    SILK_DEFAULT_GENRE="polar-psychologique"
    SILK_DEFAULT_LANGUAGE="fr"
    SILK_DEFAULT_TARGET_WORDS="80000"
    SILK_DEFAULT_CHAPTERS="30"
    SILK_DEFAULT_FORMAT="digital"
    SILK_AUTHOR_NAME=""
    SILK_AUTHOR_PSEUDO=""
    
    silk_config_save
}

silk_config_reset() {
    if [[ -f "$SILK_CONFIG" ]]; then
        backup_file "$SILK_CONFIG"
    fi
    
    silk_config_init
    log_success "Configuration SILK réinitialisée"
}

# === GETTERS/SETTERS ===
silk_config_get() {
    local key="$1"
    
    case "$key" in
        SILK_DEFAULT_GENRE) echo "$SILK_DEFAULT_GENRE" ;;
        SILK_DEFAULT_LANGUAGE) echo "$SILK_DEFAULT_LANGUAGE" ;;
        SILK_DEFAULT_TARGET_WORDS) echo "$SILK_DEFAULT_TARGET_WORDS" ;;
        SILK_DEFAULT_CHAPTERS) echo "$SILK_DEFAULT_CHAPTERS" ;;
        SILK_DEFAULT_FORMAT) echo "$SILK_DEFAULT_FORMAT" ;;
        SILK_AUTHOR_NAME) echo "$SILK_AUTHOR_NAME" ;;
        SILK_AUTHOR_PSEUDO) echo "$SILK_AUTHOR_PSEUDO" ;;
        *)
            log_error "Clé configuration inconnue: $key"
            return 1
            ;;
    esac
}

silk_config_set() {
    local key="$1"
    local value="$2"
    
    # Charger config actuelle
    silk_config_load || true
    
    # Valider et définir
    case "$key" in
        SILK_DEFAULT_GENRE)
            if is_valid_genre "$value"; then
                SILK_DEFAULT_GENRE="$value"
            else
                log_error "Genre invalide: $value"
                return 1
            fi
            ;;
        SILK_DEFAULT_LANGUAGE)
            if [[ "$value" =~ ^[a-z]{2}$ ]]; then
                SILK_DEFAULT_LANGUAGE="$value"
            else
                log_error "Code langue invalide: $value (format: fr, en, es...)"
                return 1
            fi
            ;;
        SILK_DEFAULT_TARGET_WORDS)
            if is_valid_word_count "$value"; then
                SILK_DEFAULT_TARGET_WORDS="$value"
            else
                log_error "Nombre de mots invalide: $value"
                return 1
            fi
            ;;
        SILK_DEFAULT_CHAPTERS)
            if [[ "$value" =~ ^[0-9]+$ && "$value" -gt 0 && "$value" -le 100 ]]; then
                SILK_DEFAULT_CHAPTERS="$value"
            else
                log_error "Nombre de chapitres invalide: $value (1-100)"
                return 1
            fi
            ;;
        SILK_DEFAULT_FORMAT)
            case "$value" in
                digital|iphone|kindle|book)
                    SILK_DEFAULT_FORMAT="$value"
                    ;;
                *)
                    log_error "Format invalide: $value (digital, iphone, kindle, book)"
                    return 1
                    ;;
            esac
            ;;
        SILK_AUTHOR_NAME)
            SILK_AUTHOR_NAME="$value"
            ;;
        SILK_AUTHOR_PSEUDO)
            SILK_AUTHOR_PSEUDO="$value"
            ;;
        *)
            log_error "Clé configuration inconnue: $key"
            return 1
            ;;
    esac
    
    # Sauvegarder
    silk_config_save
    log_success "Configuration mise à jour: $key=$value"
}

silk_config_list() {
    # Charger config actuelle
    silk_config_load || true
    
    echo "🕷️ Configuration SILK - Smart Integrated Literary Kit"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Genre par défaut        : ${SILK_DEFAULT_GENRE:-non défini}"
    echo "Langue par défaut       : ${SILK_DEFAULT_LANGUAGE:-non défini}"
    echo "Objectif mots défaut    : ${SILK_DEFAULT_TARGET_WORDS:-non défini}"
    echo "Chapitres par défaut    : ${SILK_DEFAULT_CHAPTERS:-non défini}"
    echo "Format par défaut       : ${SILK_DEFAULT_FORMAT:-non défini}"
    echo "Nom auteur              : ${SILK_AUTHOR_NAME:-non défini}"
    echo "Pseudonyme auteur       : ${SILK_AUTHOR_PSEUDO:-non défini}"
    echo ""
    echo "📁 Fichier config       : $SILK_CONFIG"
    echo "🏠 Répertoire SILK       : $SILK_HOME"
    echo "📚 Modules SILK          : $SILK_LIB_DIR"
    echo ""
    echo "🕸️ SILK weaves your preferences into every project."
}

# === VALIDATION CONFIGURATION ===
silk_config_validate() {
    local errors=0
    
    # Vérifier genres valides
    if ! is_valid_genre "$SILK_DEFAULT_GENRE"; then
        log_error "Genre par défaut invalide: $SILK_DEFAULT_GENRE"
        ((errors++))
    fi
    
    # Vérifier word count
    if ! is_valid_word_count "$SILK_DEFAULT_TARGET_WORDS"; then
        log_error "Objectif mots invalide: $SILK_DEFAULT_TARGET_WORDS"
        ((errors++))
    fi
    
    # Vérifier nombre chapitres
    if [[ ! "$SILK_DEFAULT_CHAPTERS" =~ ^[0-9]+$ ]] || [[ "$SILK_DEFAULT_CHAPTERS" -lt 1 ]] || [[ "$SILK_DEFAULT_CHAPTERS" -gt 100 ]]; then
        log_error "Nombre chapitres invalide: $SILK_DEFAULT_CHAPTERS"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "Configuration SILK valide"
        return 0
    else
        log_error "$errors erreur(s) de configuration détectée(s)"
        return 1
    fi
}

# === EXPORT CONFIGURATION ===
silk_config_export() {
    local format="${1:-env}"
    
    case "$format" in
        env)
            echo "# SILK Environment Variables"
            echo "export SILK_DEFAULT_GENRE=\"$SILK_DEFAULT_GENRE\""
            echo "export SILK_DEFAULT_LANGUAGE=\"$SILK_DEFAULT_LANGUAGE\""
            echo "export SILK_DEFAULT_TARGET_WORDS=\"$SILK_DEFAULT_TARGET_WORDS\""
            echo "export SILK_DEFAULT_CHAPTERS=\"$SILK_DEFAULT_CHAPTERS\""
            echo "export SILK_DEFAULT_FORMAT=\"$SILK_DEFAULT_FORMAT\""
            echo "export SILK_AUTHOR_NAME=\"$SILK_AUTHOR_NAME\""
            echo "export SILK_AUTHOR_PSEUDO=\"$SILK_AUTHOR_PSEUDO\""
            ;;
        json)
            cat << EOF
{
  "silk_config": {
    "version": "$SILK_VERSION",
    "genre": "$SILK_DEFAULT_GENRE",
    "language": "$SILK_DEFAULT_LANGUAGE",
    "target_words": $SILK_DEFAULT_TARGET_WORDS,
    "chapters": $SILK_DEFAULT_