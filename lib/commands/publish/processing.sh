#!/bin/bash
# lib/commands/publish/processing.sh - Traitement contenu SILK

# === EXTRACTION CONTENU MANUSCRIT ===
extract_manuscript_content() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    # Extraire tout après "## manuscrit"
    sed -n '/## manuscrit/,$p' "$file" | tail -n +2
}

# === CRÉATION FICHIER NETTOYÉ ===
create_clean_chapter_file() {
    local output_file="$1"
    local chapter_num="$2"
    local chapter_title="$3"
    local content="$4"
    local french_quotes="$5"
    local auto_dashes="$6"
    local output_type="${7:-pdf}"

    log_debug "📝 Création fichier nettoyé: $output_file (type: $output_type)"

    # En-tête selon le type de sortie
    case "$output_type" in
        "epub"|"html")
            # Pour EPUB/HTML, pas de commandes LaTeX
            if [[ $chapter_num -gt 1 ]]; then
                echo "" > "$output_file"
            else
                echo "" > "$output_file"
            fi
            ;;
        "pdf")
            # Pour PDF, commandes LaTeX OK
            if [[ $chapter_num -gt 1 ]]; then
                echo "\\newpage" > "$output_file"
                echo "" >> "$output_file"
            else
                echo "" > "$output_file"
            fi
            ;;
    esac

    # Titre du chapitre
    echo "# $chapter_title" >> "$output_file"
    echo "" >> "$output_file"

    # Traitement du contenu ligne par ligne
    while IFS= read -r line; do
        line_with_break="${line}  "
        process_silk_line "$line_with_break" "$output_file" "$french_quotes" "$auto_dashes" "$output_type"
    done <<< "$content"

    log_debug "✅ Fichier nettoyé créé: $output_file"
    return 0
}

# === TRAITEMENT LIGNE SILK ===
process_silk_line() {
    local line="$1"
    local output="$2"
    local french_quotes="$3"
    local auto_dashes="$4"
    local output_type="${5:-pdf}"

    # Traitement des séparateurs spéciaux SILK
    if [[ "$line" == "---" ]]; then
        # Transition de scène
        echo "" >> "$output"
        case "$output_type" in
            "epub"|"html")
                echo "***" >> "$output"
                ;;
            "pdf")
                echo "\\begin{center}" >> "$output"
                echo "\\vspace{1cm}" >> "$output"
                echo "***" >> "$output"
                echo "\\vspace{1cm}" >> "$output"
                echo "\\end{center}" >> "$output"
                ;;
        esac
        echo "" >> "$output"

    elif [[ "$line" == "~" ]]; then
        # Blanc typographique
        echo "" >> "$output"
        case "$output_type" in
            "epub"|"html")
                echo "" >> "$output"
                ;;
            "pdf")
                echo "\\vspace{0.5cm}" >> "$output"
                ;;
        esac
        echo "" >> "$output"

    elif [[ "$line" =~ ^\*.*\*$ ]] && [[ "$line" =~ \- ]]; then
        # Indications temporelles (*Lundi matin - Bureau*)
        echo "" >> "$output"
        case "$output_type" in
            "epub"|"html")
                echo "*${line:1:-1}*" >> "$output"
                ;;
            "pdf")
                echo "\\begin{center}" >> "$output"
                echo "\\textit{${line:1:-1}}" >> "$output"
                echo "\\end{center}" >> "$output"
                ;;
        esac
        echo "" >> "$output"

    elif [[ -z "$line" ]]; then
        echo "" >> "$output"

    else
        # Ligne normale
        local processed_line="$line"

        # Conversion guillemets français si demandé
        if [[ "$french_quotes" == "true" ]]; then
            processed_line=$(echo "$processed_line" | sed 's/"([^"]*)"/« \1 »/g')
        fi

        # Ajout tirets cadratins si demandé
        if [[ "$auto_dashes" == "true" ]]; then
            case "$output_type" in
                "epub"|"html")
                    # Pour EPUB/HTML, utiliser le vrai caractère em-dash
                    processed_line=$(echo "$processed_line" | sed 's/—/—/g')
                    processed_line=$(echo "$processed_line" | sed 's/^- /— /g')
                    ;;
                "pdf")
                    # Pour PDF, utiliser la commande LaTeX
                    processed_line=$(echo "$processed_line" | sed 's/—/---/g')
                    processed_line=$(echo "$processed_line" | sed 's/^- /--- /g')
                    ;;
            esac
        fi

        # Conversion liens Obsidian [[liens]]
        processed_line=$(echo "$processed_line" | sed -e 's/\[\[\([^|]*\)|\([^]]*\)\]\]/\2/g' -e 's/\[\[\([^]]*\)\]\]/\1/g')

        # Gestion indentation dialogues selon le type
        case "$output_type" in
            "epub"|"html")
                echo "$processed_line" >> "$output"
                ;;
            "pdf")
                if [[ "$processed_line" =~ ^[\"«—] ]]; then
                    echo "\\noindent $processed_line  " >> "$output"
                else
                    echo "$processed_line  " >> "$output"
                fi
                ;;
        esac
    fi
}


# === PRÉPARATION CONTENU CHAPITRES ===
prepare_chapter_content() {
    local max_chapters="$1"
    local french_quotes="$2"
    local auto_dashes="$3"
    local output_type="$4"

    local clean_files=()

    # Initialiser le cache
    cache_init

    # Collecte des chapitres avec fonctions core
    declare -A chapters_content
    if ! collect_chapters_content "$max_chapters" chapters_content; then
        log_error "Échec collecte chapitres"
        return 1
    fi

    local chapters_count=${#chapters_content[@]}
    if [[ $chapters_count -eq 0 ]]; then
        log_error "Aucun chapitre trouvé à publier"
        return 1
    fi

    log_debug "📊 $chapters_count chapitres collectés"

    # Traiter chaque chapitre collecté
    for chapter_num in $(printf '%s\n' "${!chapters_content[@]}" | sort -n); do
        local chapter_data="${chapters_content[$chapter_num]}"
        local chapter_title=$(get_chapter_title "$chapter_data")
        local chapter_content=$(get_chapter_content "$chapter_data")
        local parts_count=$(get_chapter_parts_count "$chapter_data")

        # Titre avec indication des parties multiples
        local display_title=$(format_chapter_title_with_parts "$chapter_data")

        # Nom pour cache (sans caractères spéciaux)
        local clean_filename="clean_Ch${chapter_num}.md"
        local clean_file="$PUBLISH_TEMP_DIR/$clean_filename"

        # Vérifier cache d'abord (système chapitre multi-parties)
        if is_chapter_cached_and_valid "$chapter_num"; then
            local cached_path
            cached_path=$(get_cached_chapter_clean_path "$chapter_num")
            clean_files+=("$cached_path")
            log_debug "   🚀 Ch$chapter_num réutilisé (cache): $display_title"
        else
            # Créer nouveau fichier clean
            if create_clean_chapter_file "$clean_file" "$chapter_num" "$display_title" "$chapter_content" "$french_quotes" "$auto_dashes" "$output_type"; then
                # Mettre à jour cache (système chapitre)
                cache_update_chapter "$chapter_num" "$clean_filename"
                clean_files+=("$clean_file")
                log_debug "   ✅ Ch$chapter_num créé: $display_title"
            fi
        fi
    done

    # Retourner la liste des fichiers via stdout (technique bash pour retourner array)
    printf '%s\n' "${clean_files[@]}"
    return 0
}

# === CRÉATION PAGE STATISTIQUES ===
create_stats_page() {
    local output_file="$1"
    local chapters_included="$2"
    local output_type="${3:-pdf}"

    {
        case "$output_type" in
            "epub"|"html")
                echo ""
                ;;
            "pdf")
                echo "\\newpage"
                echo ""
                ;;
        esac

        echo "# 📊 Statistiques de Publication SILK"
        echo ""
        echo "**Généré le:** $(date '+%d/%m/%Y à %H:%M:%S')"
        echo ""
        echo "**Projet:** $(basename "$PWD")"
        echo ""
        echo "**Chapitres inclus:** $chapters_included"
        echo ""

        # Calcul statistiques basiques
        local total_words=0
        for file in 01-Manuscrit/Ch*.md; do
            if [[ -f "$file" ]] && grep -q "## manuscrit" "$file"; then
                local words=$(sed -n '/## manuscrit/,$p' "$file" | tail -n +2 | wc -w)
                total_words=$((total_words + words))
            fi
        done

        echo "**Total mots:** $total_words"
        echo ""
        echo "**Pages estimées:** $((total_words / 250))"
        echo ""
        echo "---"
        echo ""
        echo "*Généré par SILK CLI v${SILK_VERSION:-1.0} - Smart Integrated Literary Kit*"
        echo ""
        echo "*Structured Intelligence for Literary Kreation*"

    } > "$output_file"
}

# === EXPORTS ===
export -f extract_manuscript_content
export -f create_clean_chapter_file
export -f process_silk_line
export -f prepare_chapter_content
export -f create_stats_page

# Marquer module comme chargé
readonly SILK_PUBLISH_PROCESSING_LOADED=true
