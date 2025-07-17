#!/bin/bash
# lib/core/cache.sh - Gestion cache SILK pour chapitres multi-parties

# Vérification dépendances
if [[ "${SILK_CORE_UTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/utils requis" >&2
    exit 1
fi

if [[ "${SILK_CORE_CHAPTERS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/chapters requis" >&2
    exit 1
fi

# === CONSTANTES CACHE ===
readonly SILK_CACHE_DIR=".silk"
readonly SILK_CACHE_FILE="$SILK_CACHE_DIR/cleanedfilescache.csv"
readonly SILK_CLEAN_FILES_DIR="outputs/temp"

# === INITIALISATION CACHE ===
cache_init() {
    # Créer répertoire cache si nécessaire
    if [[ ! -d "$SILK_CACHE_DIR" ]]; then
        mkdir -p "$SILK_CACHE_DIR"
        log_debug "Répertoire cache créé: $SILK_CACHE_DIR"
    fi

    # Créer fichier cache avec en-tête si nécessaire
    if [[ ! -f "$SILK_CACHE_FILE" ]]; then
        {
            echo "# SILK Cache - Chapitres multi-parties"
            echo "# format: chapter_key,composite_hash,clean_file"
        } > "$SILK_CACHE_FILE"
        log_debug "Fichier cache initialisé: $SILK_CACHE_FILE"
    fi

    # Créer répertoire des fichiers clean si nécessaire
    if [[ ! -d "$SILK_CLEAN_FILES_DIR" ]]; then
        mkdir -p "$SILK_CLEAN_FILES_DIR"
        log_debug "Répertoire fichiers clean créé: $SILK_CLEAN_FILES_DIR"
    fi
}

# === CALCUL HASH SIMPLE ===
calculate_file_hash() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        log_error "Fichier introuvable pour hash: $file_path"
        return 1
    fi

    # Utiliser md5sum et extraire seulement le hash
    if command -v md5sum >/dev/null 2>&1; then
        md5sum "$file_path" | cut -d' ' -f1
    elif command -v md5 >/dev/null 2>&1; then
        # macOS
        md5 -q "$file_path"
    else
        log_error "Aucune commande md5 disponible (md5sum ou md5)"
        return 1
    fi
}

# === COLLECTE FICHIERS D'UN CHAPITRE ===
get_chapter_source_files() {
    local chapter_num="$1"
    local chapter_files=()

    # Collecter tous les fichiers sources pour ce chapitre
    for file in 01-Manuscrit/Ch*.md; do
        if [[ -f "$file" ]] && grep -q "## manuscrit" "$file"; then
            local file_chapter_num=$(extract_chapter_number_from_filename "$file")
            if [[ "$file_chapter_num" == "$chapter_num" ]]; then
                chapter_files+=("$file")
            fi
        fi
    done

    if [[ ${#chapter_files[@]} -eq 0 ]]; then
        return 1
    fi

    # Trier pour garantir ordre reproductible
    IFS=$'\n' chapter_files=($(sort <<<"${chapter_files[*]}"))

    # Retourner la liste via stdout
    printf '%s\n' "${chapter_files[@]}"
    return 0
}

# === CALCUL HASH COMPOSITE CHAPITRE ===
calculate_chapter_composite_hash() {
    local chapter_num="$1"
    local chapter_files_output

    # Récupérer fichiers du chapitre
    chapter_files_output=$(get_chapter_source_files "$chapter_num")
    if [[ $? -ne 0 ]]; then
        log_error "Aucun fichier trouvé pour chapitre $chapter_num"
        return 1
    fi

    # Convertir en array
    local chapter_files=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && chapter_files+=("$file")
    done <<< "$chapter_files_output"

    log_debug "Hash composite Ch$chapter_num: ${#chapter_files[@]} fichier(s)"

    # Calculer hash composite de tous les fichiers du chapitre
    local composite_input=""
    for file in "${chapter_files[@]}"; do
        local file_hash
        file_hash=$(calculate_file_hash "$file")
        if [[ $? -ne 0 ]]; then
            log_error "Impossible de calculer hash pour: $file"
            return 1
        fi
        composite_input="${composite_input}${file_hash}"
    done

    # Hash du hash composite
    echo "$composite_input" | if command -v md5sum >/dev/null 2>&1; then
        md5sum | cut -d' ' -f1
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q
    else
        log_error "Aucune commande md5 disponible"
        return 1
    fi
}

# === LECTURE CACHE ===
cache_get_chapter_entry() {
    local chapter_num="$1"
    local chapter_key="Ch${chapter_num}"

    if [[ ! -f "$SILK_CACHE_FILE" ]]; then
        return 1
    fi

    # Chercher la ligne correspondant au chapitre (ignorer commentaires)
    grep -v "^#" "$SILK_CACHE_FILE" | grep "^${chapter_key}," | head -n1
}

cache_get_chapter_hash() {
    local chapter_num="$1"
    local entry

    entry=$(cache_get_chapter_entry "$chapter_num")
    if [[ $? -eq 0 && -n "$entry" ]]; then
        echo "$entry" | cut -d',' -f2
    else
        return 1
    fi
}

cache_get_chapter_clean_file() {
    local chapter_num="$1"
    local entry

    entry=$(cache_get_chapter_entry "$chapter_num")
    if [[ $? -eq 0 && -n "$entry" ]]; then
        echo "$entry" | cut -d',' -f3
    else
        return 1
    fi
}

# === ÉCRITURE CACHE ===
cache_update_chapter() {
    local chapter_num="$1"
    local clean_filename="$2"

    cache_init

    # Calculer hash composite du chapitre
    local chapter_hash
    chapter_hash=$(calculate_chapter_composite_hash "$chapter_num")
    if [[ $? -ne 0 ]]; then
        log_error "Impossible de calculer hash composite pour chapitre $chapter_num"
        return 1
    fi

    local chapter_key="Ch${chapter_num}"
    local new_entry="${chapter_key},${chapter_hash},${clean_filename}"

    # Créer fichier temporaire pour remplacement
    local temp_file=$(mktemp)

    # Copier toutes les lignes sauf celle à remplacer
    if [[ -f "$SILK_CACHE_FILE" ]]; then
        grep -v "^${chapter_key}," "$SILK_CACHE_FILE" > "$temp_file"
    fi

    # Ajouter nouvelle entrée
    echo "$new_entry" >> "$temp_file"

    # Remplacer fichier original
    mv "$temp_file" "$SILK_CACHE_FILE"

    log_debug "Cache mis à jour: $chapter_key → $chapter_hash"
}

# === VALIDATION CACHE ===
is_chapter_cached_and_valid() {
    local chapter_num="$1"

    # Vérifier qu'au moins un fichier source existe
    local chapter_files_output
    chapter_files_output=$(get_chapter_source_files "$chapter_num")
    if [[ $? -ne 0 ]]; then
        log_debug "Aucun fichier source pour chapitre $chapter_num"
        return 1
    fi

    # Vérifier si entrée existe dans cache
    local cached_hash
    cached_hash=$(cache_get_chapter_hash "$chapter_num")
    if [[ $? -ne 0 ]]; then
        log_debug "Pas d'entrée cache pour: Ch$chapter_num"
        return 1
    fi

    # Calculer hash composite actuel du chapitre
    local current_hash
    current_hash=$(calculate_chapter_composite_hash "$chapter_num")
    if [[ $? -ne 0 ]]; then
        log_debug "Impossible de calculer hash composite pour chapitre $chapter_num"
        return 1
    fi

    # Comparer les hashs
    if [[ "$cached_hash" != "$current_hash" ]]; then
        log_debug "Hash différent pour Ch$chapter_num (cache: $cached_hash, actuel: $current_hash)"
        return 1
    fi

    # Vérifier que le fichier clean existe physiquement
    local clean_file
    clean_file=$(cache_get_chapter_clean_file "$chapter_num")
    if [[ $? -ne 0 ]]; then
        log_debug "Impossible de récupérer nom fichier clean pour: Ch$chapter_num"
        return 1
    fi

    local clean_path="$SILK_CLEAN_FILES_DIR/$clean_file"
    if [[ ! -f "$clean_path" ]]; then
        log_debug "Fichier clean manquant: $clean_path"
        return 1
    fi

    log_debug "Cache valide pour: Ch$chapter_num → $clean_file"
    return 0
}

# === RÉCUPÉRATION FICHIER CLEAN ===
get_cached_chapter_clean_path() {
    local chapter_num="$1"

    if ! is_chapter_cached_and_valid "$chapter_num"; then
        return 1
    fi

    local clean_file
    clean_file=$(cache_get_chapter_clean_file "$chapter_num")
    if [[ $? -eq 0 ]]; then
        echo "$SILK_CLEAN_FILES_DIR/$clean_file"
        return 0
    else
        return 1
    fi
}

# === NETTOYAGE CACHE ===
cache_cleanup() {
    local force="${1:-false}"

    # CORRECTION: Désactiver le mode strict pour éviter les crashes
    set +e

    if [[ "$force" == "true" ]] || [[ "$1" == "--force" ]]; then
        log_debug "Mode suppression complète activé"

        # Suppression complète du fichier cache
        if [[ -f "$SILK_CACHE_FILE" ]]; then
            rm -f "$SILK_CACHE_FILE" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                log_info "Fichier cache supprimé: $SILK_CACHE_FILE"
            else
                log_error "Échec suppression fichier cache"
            fi
        else
            log_debug "Fichier cache déjà absent"
        fi

        # Supprimer tous les fichiers clean en masse
        if [[ -d "$SILK_CLEAN_FILES_DIR" ]]; then
            local deleted_count=0

            # Méthode robuste : compter d'abord
            local clean_files_found=$(find "$SILK_CLEAN_FILES_DIR" -name "clean_Ch*.md" -type f 2>/dev/null | wc -l)

            if [[ $clean_files_found -gt 0 ]]; then
                # Supprimer avec find (plus fiable que rm avec patterns)
                find "$SILK_CLEAN_FILES_DIR" -name "clean_Ch*.md" -type f -delete 2>/dev/null

                # Vérifier combien reste
                local remaining_files=$(find "$SILK_CLEAN_FILES_DIR" -name "clean_Ch*.md" -type f 2>/dev/null | wc -l)
                deleted_count=$((clean_files_found - remaining_files))

                if [[ $deleted_count -gt 0 ]]; then
                    log_info "Fichiers clean supprimés: $deleted_count"
                else
                    log_warning "Aucun fichier clean supprimé (problème de permissions ?)"
                fi
            else
                log_debug "Aucun fichier clean à supprimer"
            fi
        else
            log_debug "Répertoire clean files absent: $SILK_CLEAN_FILES_DIR"
        fi

        # Réinitialiser le cache après suppression complète
        cache_init

    else
        # Nettoyage intelligent : supprimer entrées avec chapitres manquants
        if [[ ! -f "$SILK_CACHE_FILE" ]]; then
            log_debug "Fichier cache absent, rien à nettoyer"
            set -e  # Réactiver le mode strict
            return 0
        fi

        local temp_file=$(mktemp)
        local cleaned=0

        # Copier en-tête
        grep "^#" "$SILK_CACHE_FILE" > "$temp_file" 2>/dev/null || {
            echo "# SILK Cache - Chapitres multi-parties" > "$temp_file"
            echo "# format: chapter_key,composite_hash,clean_file" >> "$temp_file"
        }

        # Vérifier chaque entrée
        while IFS=',' read -r chapter_key composite_hash clean_file; do
            # Ignorer commentaires et lignes vides
            if [[ "$chapter_key" =~ ^#.*$ ]] || [[ -z "$chapter_key" ]]; then
                continue
            fi

            # Extraire numéro de chapitre de la clé (format: Ch12)
            local chapter_num=""
            if [[ "$chapter_key" =~ ^Ch([0-9]+)$ ]]; then
                chapter_num="${BASH_REMATCH[1]}"
            else
                # Format non reconnu, supprimer
                local clean_path="$SILK_CLEAN_FILES_DIR/$clean_file"
                if [[ -f "$clean_path" ]]; then
                    rm -f "$clean_path" 2>/dev/null
                fi
                ((cleaned++))
                log_debug "Supprimé du cache: $chapter_key (format non reconnu)"
                continue
            fi

            # CORRECTION: Utiliser la logique corrigée pour vérifier l'existence des fichiers
            local chapter_files_found=false

            # Pattern corrigé : chercher Ch01, Ch02, etc.
            local padded_num=$(printf "%02d" "$chapter_num")
            for file in 01-Manuscrit/Ch${padded_num}*.md; do
                if [[ -f "$file" ]] && grep -q "## manuscrit" "$file" 2>/dev/null; then
                    chapter_files_found=true
                    break
                fi
            done

            # Si pas trouvé avec zéros, essayer sans zéros
            if [[ "$chapter_files_found" == "false" ]]; then
                for file in 01-Manuscrit/Ch${chapter_num}-*.md; do
                    if [[ -f "$file" ]] && grep -q "## manuscrit" "$file" 2>/dev/null; then
                        chapter_files_found=true
                        break
                    fi
                done
            fi

            if [[ "$chapter_files_found" == "true" ]]; then
                # Garder l'entrée
                echo "${chapter_key},${composite_hash},${clean_file}" >> "$temp_file"
            else
                # Supprimer fichier clean associé s'il existe
                local clean_path="$SILK_CLEAN_FILES_DIR/$clean_file"
                if [[ -f "$clean_path" ]]; then
                    rm -f "$clean_path" 2>/dev/null
                fi
                ((cleaned++))
                log_debug "Supprimé du cache: $chapter_key (fichiers source manquants)"
            fi
        done < <(grep -v "^#" "$SILK_CACHE_FILE" 2>/dev/null)

        # Remplacer fichier
        mv "$temp_file" "$SILK_CACHE_FILE" 2>/dev/null

        if [[ $cleaned -gt 0 ]]; then
            log_info "Cache nettoyé: $cleaned entrées supprimées"
        else
            log_debug "Cache déjà propre"
        fi
    fi

    # Réactiver le mode strict
    set -e
}

# === STATISTIQUES CACHE ===
cache_stats() {
    if [[ ! -f "$SILK_CACHE_FILE" ]]; then
        echo "Cache non initialisé"
        return
    fi

    local total_entries=$(grep -v "^#" "$SILK_CACHE_FILE" | grep -c "^[^,]*," 2>/dev/null || echo "0")
    local valid_entries=0
    local invalid_entries=0
    local multi_part_chapters=0

    # CORRECTION: Désactiver le mode strict pour éviter que les erreurs cassent la boucle
    set +e

    while IFS=',' read -r chapter_key composite_hash clean_file; do
        if [[ "$chapter_key" =~ ^#.*$ ]] || [[ -z "$chapter_key" ]]; then
            continue
        fi

        # Extraire numéro de chapitre
        local chapter_num=""
        if [[ "$chapter_key" =~ ^Ch([0-9]+)$ ]]; then
            chapter_num="${BASH_REMATCH[1]}"

            # Compter fichiers sources pour ce chapitre - PROTECTION contre erreurs
            local chapter_files_output
            chapter_files_output=$(get_chapter_source_files "$chapter_num" 2>/dev/null)
            local get_files_exit_code=$?

            if [[ $get_files_exit_code -eq 0 ]] && [[ -n "$chapter_files_output" ]]; then
                local files_count=$(echo "$chapter_files_output" | wc -l)
                if [[ $files_count -gt 1 ]]; then
                    ((multi_part_chapters++))
                fi

                # Vérifier validité cache - PROTECTION contre erreurs
                if is_chapter_cached_and_valid "$chapter_num" 2>/dev/null; then
                    ((valid_entries++))
                else
                    ((invalid_entries++))
                fi
            else
                # Fichiers sources manquants/introuvables
                ((invalid_entries++))
            fi
        else
            # Format non reconnu, compter comme invalide
            ((invalid_entries++))
        fi
    done < <(grep -v "^#" "$SILK_CACHE_FILE" 2>/dev/null)

    # Réactiver le mode strict
    set -e

    echo "📊 Statistiques cache SILK:"
    echo "   Total entrées: $total_entries"
    echo "   Valides: $valid_entries"
    echo "   Invalides: $invalid_entries"
    echo "   Chapitres multi-parties: $multi_part_chapters"

    if [[ -d "$SILK_CLEAN_FILES_DIR" ]]; then
        local clean_files_count=$(find "$SILK_CLEAN_FILES_DIR" -name "clean_Ch*.md" 2>/dev/null | wc -l || echo "0")
        echo "   Fichiers clean: $clean_files_count"
    fi
}

# === AIDE CACHE ===
show_cache_help() {
    cat << 'HELP'
🗄️  SILK CACHE - Gestion cache chapitres multi-parties

Le cache SILK accélère la publication en évitant de recréer
les fichiers clean inchangés. Optimisé pour chapitres multi-parties.

FONCTIONS PRINCIPALES:
  cache_init                         Initialiser cache
  is_chapter_cached_and_valid NUM    Vérifier validité cache chapitre
  get_cached_chapter_clean_path NUM  Récupérer chemin fichier clean
  cache_update_chapter NUM CLEAN     Mettre à jour cache chapitre
  cache_cleanup [--force]            Nettoyer cache
  cache_stats                        Afficher statistiques

FONCTIONS UTILITAIRES:
  calculate_chapter_composite_hash NUM   Hash composite du chapitre
  get_chapter_source_files NUM          Liste fichiers source

FICHIERS:
  .silk/cleanedfilescache.csv       Cache des hashs composites
  outputs/temp/clean_Ch*.md         Fichiers clean cachés

FORMAT CACHE:
  # format: chapter_key,composite_hash,clean_file
  Ch01,abc123def456,clean_Ch01.md
  Ch07,789ghi012jkl,clean_Ch07.md   # Ch07-1 + Ch07-2 = hash composite

EXEMPLES:
  cache_stats                        # Voir état du cache
  cache_cleanup                      # Nettoyage intelligent
  cache_cleanup --force              # Vider complètement
HELP
}

# === EXPORTS ===
export -f cache_init
export -f calculate_file_hash
export -f get_chapter_source_files
export -f calculate_chapter_composite_hash
export -f cache_get_chapter_entry
export -f cache_get_chapter_hash
export -f cache_get_chapter_clean_file
export -f cache_update_chapter
export -f is_chapter_cached_and_valid
export -f get_cached_chapter_clean_path
export -f cache_cleanup
export -f cache_stats
export -f show_cache_help

# Marquer module comme chargé
readonly SILK_CORE_CACHEUTILS_LOADED=true

log_debug "Module cache SILK multi-parties chargé"
