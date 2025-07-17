#!/bin/bash
# lib/core/chapters.sh - Module core gestion chapitres SILK

# Vérification dépendances
if [[ "${SILK_CORE_UTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/utils requis" >&2
    exit 1
fi

# === PARSING FLAG -ch EN NUMÉROS DE CHAPITRES ===
parse_chapter_range() {
    local chapter_spec="$1"
    local -n chapter_numbers_ref="$2"  # Référence au tableau de sortie

    chapter_numbers_ref=()

    if [[ "$chapter_spec" == "99" ]]; then
        # Tous les chapitres - scanner le répertoire
        for file in 01-Manuscrit/Ch*.md; do
            if [[ -f "$file" ]]; then
                local chapter_num=$(extract_chapter_number_from_filename "$file")
                if [[ -n "$chapter_num" && "$chapter_num" != "0" ]]; then
                    # Éviter doublons pour chapitres multi-parties
                    if [[ ! " ${chapter_numbers_ref[*]} " =~ " ${chapter_num} " ]]; then
                        chapter_numbers_ref+=("$chapter_num")
                    fi
                fi
            fi
        done

    elif [[ "$chapter_spec" == *","* ]]; then
        # Liste spécifique: 1,5,10,15-18
        IFS=',' read -ra parts <<< "$chapter_spec"
        for part in "${parts[@]}"; do
            part=$(echo "$part" | xargs)  # trim whitespace
            if [[ "$part" == *"-"* ]]; then
                # Range dans la liste: 15-18
                local start_ch=$(echo "$part" | cut -d'-' -f1)
                local end_ch=$(echo "$part" | cut -d'-' -f2)
                for ((i=start_ch; i<=end_ch; i++)); do
                    chapter_numbers_ref+=("$i")
                done
            else
                # Numéro simple
                chapter_numbers_ref+=("$part")
            fi
        done

    elif [[ "$chapter_spec" == *"-"* ]]; then
        # Range simple: 5-10
        local start_ch=$(echo "$chapter_spec" | cut -d'-' -f1)
        local end_ch=$(echo "$chapter_spec" | cut -d'-' -f2)

        for ((i=start_ch; i<=end_ch; i++)); do
            chapter_numbers_ref+=("$i")
        done
    else
        # Nombre simple: chapitre unique seulement
        if [[ "$chapter_spec" =~ ^[0-9]+$ ]]; then
            chapter_numbers_ref+=("$chapter_spec")
            log_debug "Chapitre unique: $chapter_spec"
        fi
    fi

    log_debug "📋 Chapitres demandés: ${chapter_numbers_ref[*]}"
}

# === EXTRACTION NUMÉRO CHAPITRE DEPUIS NOM FICHIER ===
extract_chapter_number_from_filename() {
    local filename="$1"
    local basename=$(basename "$filename" .md)

    if [[ "$basename" =~ ^[Cc]h([0-9]+) ]]; then
        local chapter_num="${BASH_REMATCH[1]}"
        # Supprimer zéros de tête mais garder au moins un chiffre
        chapter_num=$(echo "$chapter_num" | sed 's/^0*\([0-9]\)/\1/')
        echo "$chapter_num"
    else
        echo "0"
    fi
}

# === FONCTIONS D'ENCODAGE/DÉCODAGE POUR NEWLINES ===
encode_newlines() {
    local content="$1"
    echo "$content" | base64 -w 0
}

decode_newlines() {
    local encoded_content="$1"
    # CORRECTION: Utiliser base64 standard (pas base64 -w 0)
    echo "$encoded_content" | base64 -d 2>/dev/null
}

# === COLLECTE CHAPITRES AVEC CONSOLIDATION MULTI-PARTIES ===
collect_chapters_content() {
    local chapter_spec="$1"
    local -n chapters_content_ref="$2"  # Référence au tableau associatif de sortie

    chapters_content_ref=()

    # Parser la spécification des chapitres
    local requested_chapters=()
    parse_chapter_range "$chapter_spec" requested_chapters

    if [[ ${#requested_chapters[@]} -eq 0 ]]; then
        log_error "Aucun chapitre valide trouvé pour: $chapter_spec"
        return 1
    fi

    log_debug "🔍 Collecte contenu pour ${#requested_chapters[@]} chapitres..."

    # Pour chaque chapitre demandé, collecter toutes ses parties
    for chapter_num in "${requested_chapters[@]}"; do
        local chapter_files=()
        local chapter_title=""
        local combined_content=""

        # Trouver tous les fichiers pour ce chapitre (parties multiples)
        for file in 01-Manuscrit/Ch*.md; do
            if [[ -f "$file" ]] && grep -q "$MANUSCRIPT_SEPARATOR" "$file"; then
                local file_chapter_num=$(extract_chapter_number_from_filename "$file")
                if [[ "$file_chapter_num" == "$chapter_num" ]]; then
                    chapter_files+=("$file")
                fi
            fi
        done

        if [[ ${#chapter_files[@]} -eq 0 ]]; then
            log_debug "   ⚠️  Ch$chapter_num: aucun fichier trouvé"
            continue
        fi

        # Trier les fichiers par nom pour traitement ordonné
        IFS=$'\n' chapter_files=($(sort <<<"${chapter_files[*]}"))

        log_debug "   📚 Ch$chapter_num: ${#chapter_files[@]} partie(s)"

        # Combiner toutes les parties du chapitre
        for file in "${chapter_files[@]}"; do
            # Extraire titre (prendre le premier trouvé ou le fichier principal)
            if [[ -z "$chapter_title" ]] || [[ "$(basename "$file")" != *"-"* ]]; then
                local file_title=$(head -n1 "$file" | sed 's/^#*\s*//')
                if [[ -n "$file_title" ]]; then
                    chapter_title="$file_title"
                fi
            fi

            # Extraire contenu après "$MANUSCRIPT_SEPARATOR"
            local part_content
            if part_content=$(extract_manuscript_content "$file"); then
                if [[ -n "$part_content" ]]; then
                    combined_content+="$part_content"
                    combined_content+=$'\n\n'
                fi
            fi
        done

        # Stocker le chapitre consolidé avec contenu encodé
        if [[ -n "$combined_content" ]]; then
            log_debug "   🎯 STOCKAGE: titre='$chapter_title' contenu='$(echo "$combined_content" | head -c 50 | tr '\n' ' ')...' parties='${#chapter_files[@]}'"

            # CORRECTION: Encoder le contenu avant stockage pour éviter que les newlines cassent le format
            local encoded_content=$(encode_newlines "$combined_content")

            # Format: "titre|contenu_encodé|nb_parties"
            chapters_content_ref["$chapter_num"]="$chapter_title|$encoded_content|${#chapter_files[@]}"

            log_debug "   🔍 VÉRIFICATION STOCKAGE: contenu encodé ($(echo "$encoded_content" | wc -c) caractères)"
            log_debug "   ✅ Ch$chapter_num: $chapter_title (${#chapter_files[@]} parties)"
        else
            log_debug "   ❌ Ch$chapter_num: aucun contenu manuscrit"
        fi
    done

    log_debug "📊 Collecte terminée: ${#chapters_content_ref[@]} chapitres avec contenu"

    log_debug "🔍 Debug contenu chapitres collectés:"
    for num in "${!chapters_content_ref[@]}"; do
        local chapter_data="${chapters_content_ref[$num]}"
        local title=$(get_chapter_title "$chapter_data")
        local parts=$(get_chapter_parts_count "$chapter_data")
        log_debug "   Ch$num: '$title' ($parts parties)"
    done
    return 0
}

# === EXTRACTION TITRE/CONTENU/PARTIES DEPUIS DONNÉES CONSOLIDÉES ===
get_chapter_title() {
    local data="$1"
    echo "${data%%|*}"  # Tout avant le premier |
}

get_chapter_content() {
    local data="$1"

    # Protection contre données vides
    if [[ -z "$data" ]]; then
        log_debug "get_chapter_content: données vides"
        return 1
    fi

    # Extraction du contenu encodé (partie du milieu)
    local temp="${data#*|}"      # Supprimer tout jusqu'au premier |
    local encoded_content="${temp%|*}"   # Supprimer tout après le dernier |

    log_debug "get_chapter_content: extraction contenu encodé (${#encoded_content} caractères)"

    # CORRECTION CRITIQUE: Décoder le contenu base64 pour restaurer les newlines
    local decoded_content
    if decoded_content=$(echo "$encoded_content" | base64 -d 2>/dev/null); then
        log_debug "get_chapter_content: décodage réussi (${#decoded_content} caractères décodés)"
        echo "$decoded_content"
    else
        log_error "get_chapter_content: échec décodage base64 - contenu peut-être pas encodé"
        # Fallback: retourner le contenu tel quel si pas encodé
        echo "$encoded_content"
    fi
}

get_chapter_parts_count() {
    local chapter_data="$1"

    # CORRECTION: Maintenant que le contenu est encodé, cut fonctionne correctement
    local parts_count=$(echo "$chapter_data" | cut -d'|' -f3)

    log_debug "get_chapter_parts_count: extrait '$parts_count' depuis '$(echo "$chapter_data" | head -c 100)...'"

    # Validation que c'est bien un nombre
    if [[ -n "$parts_count" ]] && [[ "$parts_count" =~ ^[0-9]+$ ]]; then
        echo "$parts_count"
    else
        log_debug "get_chapter_parts_count: '$parts_count' invalide, défaut à 1"
        echo "1"
    fi
}

# === FONCTION HELPER POUR AFFICHAGE ===
format_chapter_title_with_parts() {
    local chapter_data="$1"
    local title=$(get_chapter_title "$chapter_data")
    local parts_count=$(get_chapter_parts_count "$chapter_data")

    log_debug "format_chapter_title_with_parts: parts_count='$parts_count' title='$title'"

    # Protection : s'assurer que parts_count est un nombre valide
    if [[ -z "$parts_count" ]] || ! [[ "$parts_count" =~ ^[0-9]+$ ]]; then
        log_debug "parts_count invalide, défaut à 1"
        parts_count=1  # Valeur par défaut
    fi

    if (( parts_count > 1 )); then
        echo "$title ($parts_count parties)"
    else
        echo "$title"
    fi
}

# === VALIDATION CHAPITRE DANS RANGE (fonction existante à adapter) ===
is_chapter_in_requested_list() {
    local chapter_num="$1"
    local -n requested_list_ref="$2"

    for requested_ch in "${requested_list_ref[@]}"; do
        if [[ "$chapter_num" == "$requested_ch" ]]; then
            return 0
        fi
    done
    return 1
}

# === EXPORTS ===
export -f parse_chapter_range
export -f extract_chapter_number_from_filename
export -f encode_newlines
export -f decode_newlines
export -f collect_chapters_content
export -f get_chapter_title
export -f get_chapter_content
export -f get_chapter_parts_count
export -f format_chapter_title_with_parts
export -f is_chapter_in_requested_list

# === MODULE CHARGÉ ===
readonly SILK_CORE_CHAPTERS_LOADED=true
