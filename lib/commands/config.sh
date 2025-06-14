#!/bin/bash
# lib/commands/config.sh - Commande SILK config

# Vérification chargement des dépendances
if [[ "${SILK_CORE_CONFIG_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/config requis" >&2
    exit 1
fi

# === FONCTION PRINCIPALE ===
cmd_config() {
    local action=""
    local key=""
    local value=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_config_help
                return 0
                ;;
            --set)
                action="set"
                if [[ "$2" == *"="* ]]; then
                    key="${2%%=*}"
                    value="${2#*=}"
                    shift 2
                else
                    log_error "Format invalide. Utilisez: --set KEY=VALUE"
                    return 1
                fi
                ;;
            --get)
                action="get"
                key="$2"
                shift 2
                ;;
            --list|--show)
                action="list"
                shift
                ;;
            --reset)
                action="reset"
                shift
                ;;
            --export)
                action="export"
                value="${2:-env}"  # format par défaut
                shift 2
                ;;
            --validate)
                action="validate"
                shift
                ;;
            --profile-save)
                action="profile-save"
                value="$2"
                shift 2
                ;;
            --profile-load)
                action="profile-load"
                value="$2"
                shift 2
                ;;
            --profile-list)
                action="profile-list"
                shift
                ;;
            --edit)
                action="edit"
                shift
                ;;
            *)
                log_error "Option inconnue: $1"
                show_config_help
                return 1
                ;;
        esac
    done
    
    # Si aucune action spécifiée, afficher la config
    if [[ -z "$action" ]]; then
        action="list"
    fi
    
    # Exécuter l'action
    case "$action" in
        "set")
            silk_config_set "$key" "$value"
            ;;
        "get")
            silk_config_get "$key"
            ;;
        "list")
            silk_config_list
            ;;
        "reset")
            confirm_reset_config
            ;;
        "export")
            silk_config_export "$value"
            ;;
        "validate")
            silk_config_validate
            ;;
        "profile-save")
            silk_config_profile_save "$value"
            ;;
        "profile-load")
            silk_config_profile_load "$value"
            ;;
        "profile-list")
            silk_config_profile_list
            ;;
        "edit")
            edit_config_interactive
            ;;
        *)
            log_error "Action inconnue: $action"
            return 1
            ;;
    esac
}

# === AIDE CONFIG ===
show_config_help() {
    cat << 'HELP'
⚙️ SILK CONFIG - Configuration globale

USAGE:
  silk config [OPTIONS]

OPTIONS:
  --set KEY=VALUE           Définir une configuration
  --get KEY                 Afficher une configuration
  --list                    Afficher toute la configuration (défaut)
  --reset                   Réinitialiser configuration
  --export [FORMAT]         Exporter config (env, json)
  --validate                Valider la configuration
  --edit                    Édition interactive
  --profile-save NAME       Sauvegarder profil
  --profile-load NAME       Charger profil
  --profile-list            Lister profils
  -h, --help                Afficher cette aide

CLÉS SILK DISPONIBLES:
  SILK_DEFAULT_GENRE         Genre par défaut (polar-psychologique)
  SILK_DEFAULT_LANGUAGE      Langue par défaut (fr)
  SILK_DEFAULT_TARGET_WORDS  Objectif mots par défaut (80000)
  SILK_DEFAULT_CHAPTERS      Nombre chapitres par défaut (30)
  SILK_DEFAULT_FORMAT        Format publication par défaut (digital)
  SILK_AUTHOR_NAME           Nom auteur
  SILK_AUTHOR_PSEUDO         Pseudonyme auteur

EXEMPLES:
  silk config --list
  silk config --set SILK_AUTHOR_NAME="Jane Doe"
  silk config --get SILK_DEFAULT_GENRE
  silk config --export json
  silk config --profile-save polar-setup
  silk config --reset

SILK Smart Integrated Literary Kit
Structured Intelligence for Literary Kreation
HELP
}

# === CONFIRMATION RESET ===
confirm_reset_config() {
    echo "🕷️ SILK Configuration Reset"
    echo "=========================="
    echo "⚠️  Cette action va réinitialiser TOUTE la configuration SILK."
    echo "Les profils sauvegardés seront conservés."
    echo
    read -p "Êtes-vous sûr de vouloir continuer ? (oui/NON): " confirm
    
    case "$confirm" in
        "oui"|"OUI"|"yes"|"YES")
            silk_config_reset
            ;;
        *)
            log_info "Reset annulé"
            ;;
    esac
}

# === ÉDITION INTERACTIVE ===
edit_config_interactive() {
    log_header "SILK CONFIG - Édition Interactive"
    echo
    
    # Charger config actuelle
    silk_config_load || true
    
    # Éditer chaque paramètre
    echo "🎭 Configuration Auteur"
    echo "======================="
    read -p "Nom auteur [$SILK_AUTHOR_NAME]: " new_author_name
    SILK_AUTHOR_NAME="${new_author_name:-$SILK_AUTHOR_NAME}"
    
    read -p "Pseudonyme [$SILK_AUTHOR_PSEUDO]: " new_author_pseudo
    SILK_AUTHOR_PSEUDO="${new_author_pseudo:-$SILK_AUTHOR_PSEUDO}"
    
    echo
    echo "📚 Configuration Projets"
    echo "========================"
    
    echo "Genres disponibles: $(get_available_templates | tr '\n' ' ')"
    read -p "Genre par défaut [$SILK_DEFAULT_GENRE]: " new_genre
    if [[ -n "$new_genre" ]]; then
        if is_valid_genre "$new_genre"; then
            SILK_DEFAULT_GENRE="$new_genre"
        else
            log_warning "Genre invalide: $new_genre (ignoré)"
        fi
    fi
    
    read -p "Langue par défaut [$SILK_DEFAULT_LANGUAGE]: " new_language
    SILK_DEFAULT_LANGUAGE="${new_language:-$SILK_DEFAULT_LANGUAGE}"
    
    read -p "Objectif mots par défaut [$SILK_DEFAULT_TARGET_WORDS]: " new_target_words
    if [[ -n "$new_target_words" ]]; then
        if is_valid_word_count "$new_target_words"; then
            SILK_DEFAULT_TARGET_WORDS="$new_target_words"
        else
            log_warning "Objectif mots invalide: $new_target_words (ignoré)"
        fi
    fi
    
    read -p "Chapitres par défaut [$SILK_DEFAULT_CHAPTERS]: " new_chapters  SILK_DEFAULT_CHAPTERS="${new_chapters:-$SILK_DEFAULT_CHAPTERS}"
    
    echo
    echo "📖 Configuration Publication"
    echo "============================"
    echo "Formats disponibles: digital, iphone, kindle, book"
    read -p "Format par défaut [$SILK_DEFAULT_FORMAT]: " new_format
    SILK_DEFAULT_FORMAT="${new_format:-$SILK_DEFAULT_FORMAT}"
    
    # Sauvegarder
    echo
    read -p "Sauvegarder la configuration ? (O/n): " save_confirm
    case "$save_confirm" in
        ""|"o"|"O"|"oui"|"OUI"|"y"|"Y"|"yes"|"YES")
            silk_config_save
            log_success "Configuration SILK mise à jour"
            ;;
        *)
            log_info "Configuration non sauvegardée"
            ;;
    esac
}

# === VALIDATION AVANCÉE ===
advanced_config_validation() {
    local errors=0
    local warnings=0
    
    log_info "Validation avancée configuration SILK..."
    
    # Validation author info
    if [[ -z "$SILK_AUTHOR_NAME" ]]; then
        log_warning "Nom auteur non défini"
        ((warnings++))
    elif [[ ${#SILK_AUTHOR_NAME} -lt 2 ]]; then
        log_warning "Nom auteur très court: $SILK_AUTHOR_NAME"
        ((warnings++))
    fi
    
    # Validation target words cohérence
    if [[ -n "$SILK_DEFAULT_TARGET_WORDS" && -n "$SILK_DEFAULT_CHAPTERS" ]]; then
        local avg_per_chapter=$((SILK_DEFAULT_TARGET_WORDS / SILK_DEFAULT_CHAPTERS))
        if [[ $avg_per_chapter -lt 1000 ]]; then
            log_warning "Moyenne mots/chapitre faible: $avg_per_chapter mots"
            ((warnings++))
        elif [[ $avg_per_chapter -gt 5000 ]]; then
            log_warning "Moyenne mots/chapitre élevée: $avg_per_chapter mots"
            ((warnings++))
        fi
    fi
    
    # Validation format
    case "$SILK_DEFAULT_FORMAT" in
        digital|iphone|kindle|book) ;;
        *)
            log_error "Format par défaut invalide: $SILK_DEFAULT_FORMAT"
            ((errors++))
            ;;
    esac
    
    # Validation langue
    if [[ ! "$SILK_DEFAULT_LANGUAGE" =~ ^[a-z]{2}$ ]]; then
        log_error "Code langue invalide: $SILK_DEFAULT_LANGUAGE"
        ((errors++))
    fi
    
    echo
    if [[ $errors -eq 0 ]]; then
        log_success "Configuration SILK valide ($warnings avertissement(s))"
        return 0
    else
        log_error "Configuration SILK invalide: $errors erreur(s), $warnings avertissement(s)"
        return 1
    fi
}

# === IMPORT/EXPORT AVANCÉ ===
import_config_from_file() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Fichier configuration non trouvé: $config_file"
        return 1
    fi
    
    log_info "Import configuration depuis: $config_file"
    
    # Backup config actuelle
    if [[ -f "$SILK_CONFIG" ]]; then
        backup_file "$SILK_CONFIG"
    fi
    
    # Tenter de charger
    if source "$config_file" 2>/dev/null; then
        silk_config_save
        log_success "Configuration importée"
    else
        log_error "Impossible d'importer la configuration"
        return 1
    fi
}

export_config_to_file() {
    local output_file="$1"
    local format="${2:-env}"
    
    log_info "Export configuration vers: $output_file"
    
    case "$format" in
        "env")
            silk_config_export env > "$output_file"
            ;;
        "json")
            silk_config_export json > "$output_file"
            ;;
        "yaml")
            export_config_yaml > "$output_file"
            ;;
        *)
            log_error "Format export inconnu: $format"
            return 1
            ;;
    esac
    
    log_success "Configuration exportée: $output_file"
}

export_config_yaml() {
    cat << EOF
# Configuration SILK - Smart Integrated Literary Kit
# Généré le $(date)

silk:
  version: "$SILK_VERSION"
  
  author:
    name: "$SILK_AUTHOR_NAME"
    pseudo: "$SILK_AUTHOR_PSEUDO"
  
  defaults:
    genre: "$SILK_DEFAULT_GENRE"
    language: "$SILK_DEFAULT_LANGUAGE"
    target_words: $SILK_DEFAULT_TARGET_WORDS
    chapters: $SILK_DEFAULT_CHAPTERS
    format: "$SILK_DEFAULT_FORMAT"
  
  paths:
    home: "$SILK_HOME"
    lib: "$SILK_LIB_DIR"
    config: "$SILK_CONFIG"
EOF
}

# === MIGRATION CONFIGURATION ===
migrate_legacy_config() {
    local legacy_config="$1"
    
    if [[ ! -f "$legacy_config" ]]; then
        log_warning "Aucune configuration legacy trouvée: $legacy_config"
        return 0
    fi
    
    log_info "Migration configuration legacy..."
    
    # Charger legacy et mapper vers SILK
    if source "$legacy_config" 2>/dev/null; then
        # Mapper anciennes variables vers nouvelles
        SILK_DEFAULT_GENRE="${NBA_DEFAULT_GENRE:-$SILK_DEFAULT_GENRE}"
        SILK_AUTHOR_NAME="${NBA_AUTHOR_NAME:-$SILK_AUTHOR_NAME}"
        # ... autres mappings
        
        silk_config_save
        log_success "Configuration legacy migrée"
    else
        log_warning "Impossible de migrer la configuration legacy"
    fi
}

# === EXPORT FONCTIONS ===
export -f cmd_config
export -f show_config_help
export -f edit_config_interactive

# Marquer module comme chargé
readonly SILK_COMMAND_CONFIG_CMD_LOADED=true