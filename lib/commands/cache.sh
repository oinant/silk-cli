#!/bin/bash
# lib/commands/cache.sh - Commande SILK cache

# Vérification dépendances
if [[ "${SILK_CORE_UTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/utils requis" >&2
    exit 1
fi

if [[ "${SILK_CORE_CACHEUTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/cache requis" >&2
    exit 1
fi

# === FONCTION PRINCIPALE ===
cmd_cache() {
    ensure_silk_context

    local subcommand="${1:-help}"
    shift 2>/dev/null || true

    case "$subcommand" in
        stats|stat)
            cache_command_stats "$@"
            ;;
        list|ls)
            cache_command_list "$@"
            ;;
        clean)
            cache_command_clean "$@"
            ;;
        clear)
            cache_command_clear "$@"
            ;;
        help|--help|-h)
            show_cache_help
            ;;
        *)
            log_error "Sous-commande inconnue: $subcommand"
            echo
            show_cache_help
            return 1
            ;;
    esac
}

# === IMPLÉMENTATION SOUS-COMMANDES ===

cache_command_stats() {
    log_info "📊 Analyse du cache SILK..."
    echo

    cache_stats

    # Informations supplémentaires
    echo
    echo "📂 Emplacements:"
    echo "   Cache: $SILK_CACHE_FILE"
    echo "   Fichiers clean: $SILK_CLEAN_FILES_DIR"

    if [[ -f "$SILK_CACHE_FILE" ]]; then
        local file_size=$(ls -lh "$SILK_CACHE_FILE" 2>/dev/null | awk '{print $5}' || echo 'N/A')
        echo "   Taille cache: $file_size"
    fi
}

cache_command_list() {
    local verbose=false

    # Parser options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                show_cache_list_help
                return 0
                ;;
            *)
                log_error "Option inconnue: $1"
                show_cache_list_help
                return 1
                ;;
        esac
    done

    if [[ ! -f "$SILK_CACHE_FILE" ]]; then
        log_info "Cache non initialisé"
        echo "💡 Utilisez 'silk publish' pour créer le cache automatiquement"
        return 0
    fi

    log_info "📋 Contenu du cache SILK..."
    echo

    # En-tête tableau
    if [[ "$verbose" == "true" ]]; then
        printf "%-8s %-15s %-25s %s\n" "Chapitre" "Status" "Hash" "Fichier Clean"
        echo "────────────────────────────────────────────────────────────────────────"
    else
        printf "%-8s %-15s %s\n" "Chapitre" "Status" "Fichier Clean"
        echo "─────────────────────────────────────────────────"
    fi

    # Lire et afficher chaque entrée
    local entries_count=0
    while IFS=',' read -r chapter_key composite_hash clean_file; do
        # Ignorer commentaires et lignes vides
        if [[ "$chapter_key" =~ ^#.*$ ]] || [[ -z "$chapter_key" ]]; then
            continue
        fi

        ((entries_count++))

        # Extraire numéro de chapitre
        local chapter_num=""
        if [[ "$chapter_key" =~ ^Ch([0-9]+)$ ]]; then
            chapter_num="${BASH_REMATCH[1]}"
        else
            chapter_num="$chapter_key"
        fi

        # Vérifier statut
        local status="❓"
        local status_text="Inconnu"

        if [[ "$chapter_key" =~ ^Ch([0-9]+)$ ]]; then
            local ch_num="${BASH_REMATCH[1]}"
            if is_chapter_cached_and_valid "$ch_num"; then
                status="✅"
                status_text="Valide"
            else
                status="❌"
                status_text="Invalide"
            fi
        else
            status="⚠️"
            status_text="Format obsolète"
        fi

        # Affichage selon mode
        if [[ "$verbose" == "true" ]]; then
            local short_hash="${composite_hash:0:12}..."
            printf "%-8s %-15s %-25s %s\n" "$chapter_key" "$status_text" "$short_hash" "$clean_file"
        else
            printf "%-8s %-15s %s\n" "$chapter_key" "$status_text" "$clean_file"
        fi

    done < <(grep -v "^#" "$SILK_CACHE_FILE" 2>/dev/null || true)

    if [[ $entries_count -eq 0 ]]; then
        echo "Cache vide"
        echo "💡 Lancez 'silk publish' pour générer des entrées de cache"
    else
        echo
        echo "📊 Total: $entries_count entrée(s)"
        if [[ "$verbose" == "false" ]]; then
            echo "💡 Utilisez --verbose pour voir les hashs complets"
        fi
    fi
}

cache_command_clean() {
    local dry_run=false

    # Parser options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run|-n)
                dry_run=true
                shift
                ;;
            -h|--help)
                show_cache_clean_help
                return 0
                ;;
            *)
                log_error "Option inconnue: $1"
                show_cache_clean_help
                return 1
                ;;
        esac
    done

    if [[ ! -f "$SILK_CACHE_FILE" ]]; then
        log_info "Cache non initialisé - rien à nettoyer"
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        log_info "🔍 Simulation nettoyage cache (dry-run)..."
        echo

        # Compter ce qui serait supprimé
        local would_clean=0
        while IFS=',' read -r chapter_key composite_hash clean_file; do
            if [[ "$chapter_key" =~ ^#.*$ ]] || [[ -z "$chapter_key" ]]; then
                continue
            fi

            # Vérifier si à supprimer
            local should_remove=false

            if [[ "$chapter_key" =~ ^Ch([0-9]+)$ ]]; then
                local chapter_num="${BASH_REMATCH[1]}"
                if ! get_chapter_source_files "$chapter_num" >/dev/null 2>&1; then
                    should_remove=true
                fi
            else
                # Format obsolète
                should_remove=true
            fi

            if [[ "$should_remove" == "true" ]]; then
                echo "❌ Supprimerait: $chapter_key → $clean_file"
                ((would_clean++))
            fi
        done < <(grep -v "^#" "$SILK_CACHE_FILE")

        if [[ $would_clean -eq 0 ]]; then
            echo "✅ Cache déjà propre - aucune action nécessaire"
        else
            echo
            echo "📊 $would_clean entrée(s) seraient supprimées"
            echo "💡 Relancez sans --dry-run pour effectuer le nettoyage"
        fi
    else
        log_info "🧹 Nettoyage intelligent du cache..."
        cache_cleanup
        log_success "Nettoyage terminé"
    fi
}

cache_command_clear() {
    local force=false

    # Parser options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                force=true
                shift
                ;;
            -h|--help)
                show_cache_clear_help
                return 0
                ;;
            *)
                log_error "Option inconnue: $1"
                show_cache_clear_help
                return 1
                ;;
        esac
    done

    if [[ ! -f "$SILK_CACHE_FILE" ]]; then
        log_info "Cache non initialisé - rien à vider"
        return 0
    fi

    # Confirmation si pas --force
    if [[ "$force" == "false" ]]; then
        log_warning "⚠️  Suppression COMPLÈTE du cache SILK"
        echo
        echo "Cette action va :"
        echo "  • Vider le fichier cache (.silk/cleanedfilescache.csv)"
        echo "  • Supprimer tous les fichiers clean mis en cache"
        echo "  • Forcer la recréation de tous les fichiers lors du prochain publish"
        echo
        read -p "Continuer ? (oui/NON): " confirm
        case "$confirm" in
            "oui"|"OUI"|"yes"|"YES")
                # Continuer
                ;;
            *)
                log_info "Suppression annulée"
                return 0
                ;;
        esac
    fi

    log_info "🗑️  Suppression complète du cache..."
    cache_cleanup --force
    log_success "Cache vidé complètement"
    echo "💡 Le cache sera recréé automatiquement lors du prochain 'silk publish'"
}

# === AIDE PRINCIPALE ===
show_cache_help() {
    cat << 'HELP'
🗄️  SILK CACHE - Gestion du cache de publication

Le cache SILK accélère la publication en évitant de recréer les fichiers
clean inchangés. Optimisé pour chapitres multi-parties.

USAGE:
  silk cache COMMAND [OPTIONS]

COMMANDES:
  stats             Afficher statistiques du cache
  list              Lister le contenu du cache
  clean             Nettoyage intelligent (entrées obsolètes)
  clear             Vider complètement le cache
  help              Afficher cette aide

EXEMPLES:
  silk cache stats                    # Voir état du cache
  silk cache list                     # Contenu du cache
  silk cache list --verbose           # Avec hashs complets
  silk cache clean                    # Nettoyage intelligent
  silk cache clean --dry-run          # Simulation nettoyage
  silk cache clear                    # Vider avec confirmation
  silk cache clear --force            # Vider sans confirmation

FONCTIONNEMENT:
Le cache associe chaque chapitre (simple ou multi-parties) à un hash
composite de tous ses fichiers sources. Si aucun fichier n'a changé,
le fichier clean mis en cache est réutilisé lors de la publication.

FORMAT CACHE:
  Ch01,abc123...,clean_Ch01.md       # Chapitre simple
  Ch07,def456...,clean_Ch07.md       # Multi-parties (Ch07-1 + Ch07-2)

FICHIERS:
  .silk/cleanedfilescache.csv        # Cache des hashs
  outputs/temp/clean_Ch*.md          # Fichiers clean cachés
HELP
}

# === AIDE SPÉCIFIQUES ===
show_cache_list_help() {
    cat << 'HELP'
USAGE: silk cache list [OPTIONS]

Affiche le contenu du cache avec le statut de chaque entrée.

OPTIONS:
  -v, --verbose     Afficher les hashs complets
  -h, --help        Afficher cette aide

STATUTS:
  ✅ Valide         Cache utilisable (fichiers inchangés)
  ❌ Invalide       Cache obsolète (fichiers modifiés/manquants)
  ⚠️  Format obsolète   Entrée ancienne à nettoyer
HELP
}

show_cache_clean_help() {
    cat << 'HELP'
USAGE: silk cache clean [OPTIONS]

Nettoie intelligemment le cache en supprimant les entrées obsolètes.

OPTIONS:
  -n, --dry-run     Simulation sans modification
  -h, --help        Afficher cette aide

SUPPRIME:
  • Entrées dont les fichiers sources n'existent plus
  • Entrées avec format obsolète
  • Fichiers clean orphelins

CONSERVE:
  • Entrées valides avec fichiers sources existants
HELP
}

show_cache_clear_help() {
    cat << 'HELP'
USAGE: silk cache clear [OPTIONS]

Vide complètement le cache (suppression de toutes les entrées).

OPTIONS:
  -f, --force       Supprimer sans confirmation
  -h, --help        Afficher cette aide

⚠️  ATTENTION: Cette action est irréversible et forcera la recréation
de tous les fichiers clean lors de la prochaine publication.
HELP
}

# === EXPORTS ===
export -f cmd_cache
export -f cache_command_stats
export -f cache_command_list
export -f cache_command_clean
export -f cache_command_clear
export -f show_cache_help
export -f show_cache_list_help
export -f show_cache_clean_help
export -f show_cache_clear_help

# Marquer module comme chargé
readonly SILK_COMMAND_CACHE_LOADED=true

log_debug "Module commande cache SILK chargé"
