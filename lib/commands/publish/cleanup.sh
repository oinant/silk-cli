#!/bin/bash
# lib/commands/publish/cleanup.sh - Nettoyage et maintenance

# === NETTOYAGE INTELLIGENT TEMP ===
cleanup_temp_directory() {
    local temp_dir="$1"
    local keep_recent_hours="${2:-24}"

    log_debug "🧹 Nettoyage dossier temporaire: $temp_dir"

    if [[ ! -d "$temp_dir" ]]; then
        return 0
    fi

    # CRITIQUE: Désactiver errexit temporairement pour éviter crash
    set +e

    # Compter fichiers avant
    local files_before=$(find "$temp_dir" -type f 2>/dev/null | wc -l)

    if [[ $files_before -eq 0 ]]; then
        log_debug "   📁 Dossier temp déjà vide"
        set -e  # Réactiver errexit
        return 0
    fi

    log_debug "   📊 $files_before fichiers détectés"

    # Nettoyage par âge (fichiers > 24h)
    local deleted_old=0
    if command -v find &> /dev/null; then
        local old_files
        old_files=$(find "$temp_dir" -type f -name "silk_*" -mtime +0 2>/dev/null)
        if [[ -n "$old_files" ]]; then
            while IFS= read -r old_file; do
                if [[ -f "$old_file" ]]; then
                    rm -f "$old_file" 2>/dev/null && ((deleted_old++))
                fi
            done <<< "$old_files"
        fi
    fi

    # Nettoyage par pattern (méthode simple et robuste)
    local deleted_pattern=0
    for pattern in "clean_Ch*.md" "merged_metadata_*.yaml" "temp_*.yaml"; do
        for file in "$temp_dir"/$pattern; do
            if [[ -f "$file" ]]; then
                rm -f "$file" 2>/dev/null && ((deleted_pattern++))
            fi
        done
    done

    # Nettoyage par limite (garder 10 plus récents par type)
    local deleted_excess=0

    # Méthode SIMPLE et ROBUSTE pour silk_clean_*
    local clean_files=("$temp_dir"/silk_clean_*)
    if [[ ${#clean_files[@]} -gt 10 ]]; then
        # Trier par date de modification (plus ancien en premier)
        local sorted_clean_files
        sorted_clean_files=$(ls -t "$temp_dir"/silk_clean_* 2>/dev/null | tail -n +11)
        if [[ -n "$sorted_clean_files" ]]; then
            while IFS= read -r excess_file; do
                if [[ -f "$excess_file" ]]; then
                    rm -f "$excess_file" 2>/dev/null && ((deleted_excess++))
                fi
            done <<< "$sorted_clean_files"
        fi
    fi

    # Même chose pour silk_merged_*
    local merged_files=("$temp_dir"/silk_merged_*)
    if [[ ${#merged_files[@]} -gt 10 ]]; then
        local sorted_merged_files
        sorted_merged_files=$(ls -t "$temp_dir"/silk_merged_* 2>/dev/null | tail -n +11)
        if [[ -n "$sorted_merged_files" ]]; then
            while IFS= read -r excess_file; do
                if [[ -f "$excess_file" ]]; then
                    rm -f "$excess_file" 2>/dev/null && ((deleted_excess++))
                fi
            done <<< "$sorted_merged_files"
        fi
    fi

    # Recompter fichiers après
    local files_after=$(find "$temp_dir" -type f 2>/dev/null | wc -l)
    local total_deleted=$((deleted_old + deleted_pattern + deleted_excess))

    if [[ $total_deleted -gt 0 ]]; then
        log_debug "   🗑️  Supprimés: $total_deleted fichiers ($files_before → $files_after)"
        log_debug "      📅 Anciens: $deleted_old, 🏷️  Pattern: $deleted_pattern, 📊 Excès: $deleted_excess"
    else
        log_debug "   ✨ Aucun nettoyage nécessaire ($files_before fichiers)"
    fi

    # CRITIQUE: Réactiver errexit
    set -e
}

# === COMMANDE DE NETTOYAGE MANUEL ===
cmd_cleanup_temp() {
    ensure_silk_context

    local temp_dir="${PUBLISH_TEMP_DIR:-outputs/temp}"
    local force=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                force=true
                shift
                ;;
            --help|-h)
                show_cleanup_help
                return 0
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ "$force" == "true" ]]; then
        log_warning "🚨 Nettoyage COMPLET du dossier temporaire..."
        read -p "Êtes-vous sûr ? (oui/NON): " confirm
        case "$confirm" in
            "oui"|"OUI"|"yes"|"YES")
                if [[ -d "$temp_dir" ]]; then
                    rm -rf "$temp_dir"/*
                    log_success "Dossier temporaire vidé complètement"
                else
                    log_info "Dossier temporaire n'existe pas"
                fi
                ;;
            *)
                log_info "Nettoyage annulé"
                ;;
        esac
    else
        log_info "🧹 Nettoyage intelligent du dossier temporaire..."
        cleanup_temp_directory "$temp_dir"
        log_success "Nettoyage intelligent terminé"
    fi
}

# === AIDE NETTOYAGE ===
show_cleanup_help() {
    cat << 'HELP'
🧹 SILK CLEANUP - Nettoyage dossier temporaire

USAGE:
  silk cleanup [OPTIONS]

OPTIONS:
  --force, -f    Supprimer TOUS les fichiers temp (attention !)
  --help, -h     Afficher cette aide

EXEMPLES:
  silk cleanup         # Nettoyage intelligent (garde fichiers récents)
  silk cleanup --force # Suppression complète (⚠️  attention)

Le nettoyage intelligent garde les fichiers des dernières 24h
et limite à 10 fichiers par type pour éviter l'accumulation.
HELP
}

# === MAINTENANCE RÉPERTOIRES ===
ensure_publish_directories() {
    mkdir -p "$PUBLISH_OUTPUT_DIR" "$PUBLISH_TEMP_DIR"
    
    if [[ ! -d "$PUBLISH_OUTPUT_DIR" ]] || [[ ! -d "$PUBLISH_TEMP_DIR" ]]; then
        log_error "Impossible de créer les répertoires de publication"
        return 1
    fi
    
    log_debug "Répertoires de publication vérifiés"
    return 0
}

# === NETTOYAGE SESSION ===
cleanup_session_files() {
    local timestamp="$1"
    local keep_debug="${2:-false}"
    
    if [[ "$keep_debug" == "true" ]]; then
        log_debug "Fichiers de session conservés pour debug"
        return 0
    fi
    
    # Supprimer fichiers de cette session uniquement
    find "$PUBLISH_TEMP_DIR" -name "*_${timestamp}*" -type f -delete 2>/dev/null || true
    log_debug "Fichiers temporaires de session supprimés"
}

# === EXPORTS ===
export -f cleanup_temp_directory
export -f cmd_cleanup_temp
export -f show_cleanup_help
export -f ensure_publish_directories
export -f cleanup_session_files

# Marquer module comme chargé
readonly SILK_PUBLISH_CLEANUP_LOADED=true
