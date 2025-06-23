#!/bin/bash
# lib/core/custom_html.sh - Générateur HTML custom pour SILK

# Vérification dépendances
if [[ "${SILK_CORE_UTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/utils requis" >&2
    exit 1
fi

if [[ "${SILK_CORE_CHAPTERS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/chapters requis" >&2
    exit 1
fi

# === FONCTION PRINCIPALE GÉNÉRATION HTML CUSTOM ===
generate_custom_html() {
    local format="$1"
    local max_chapters="$2"
    local french_quotes="$3"
    local auto_dashes="$4"
    local output_name="$5"
    local include_toc="$6"
    local include_stats="$7"
    local embeddable="$8"

    local start_time=$(start_timer)
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local project_name=$(basename "$PWD")

    log_info "🕸️ Génération HTML custom: collecte chapitres..."

    # === COLLECTE CHAPITRES AVEC FONCTIONS CORE ===
    declare -A chapters_content
    if ! collect_chapters_content "$max_chapters" chapters_content; then
        log_error "Échec collecte chapitres"
        return 1
    fi

    log_debug "🔍 Debug chapitres dans generate_custom_html:"
    for num in "${!chapters_content[@]}"; do
        local preview=$(echo "${chapters_content[$num]}" | head -c 50 | tr '\n' ' ')
        log_debug "   Ch$num disponible: $preview..."
    done

    local chapters_count=${#chapters_content[@]}
    if [[ $chapters_count -eq 0 ]]; then
        log_error "Aucun chapitre trouvé à publier"
        return 1
    fi

    log_debug "📊 $chapters_count chapitres collectés"

    # === GÉNÉRATION NOM FICHIER ===
    local filename
    if [[ -n "$output_name" ]]; then
        filename="${output_name}.html"
    else
        # Logique de nommage basée sur les chapitres collectés
        local chapter_numbers=($(printf '%s\n' "${!chapters_content[@]}" | sort -n))

        if [[ ${#chapter_numbers[@]} -eq 1 ]]; then
            # Chapitre unique
            filename="${project_name}-${format}-Ch${chapter_numbers[0]}-${timestamp}.html"
        elif [[ ${#chapter_numbers[@]} -le 5 ]]; then
            # Peu de chapitres : lister
            local chapters_list=$(IFS='-'; echo "${chapter_numbers[*]}")
            filename="${project_name}-${format}-Ch${chapters_list}-${timestamp}.html"
        else
            # Beaucoup de chapitres : nom générique
            filename="${project_name}-${format}-${timestamp}.html"
        fi
    fi

    local output_file="$PUBLISH_OUTPUT_DIR/$filename"

    # Créer répertoires nécessaires
    mkdir -p "$PUBLISH_OUTPUT_DIR"

    log_info "🕸️ Génération HTML custom: $filename"

    # === GÉNÉRATION STRUCTURE HTML ===
    if create_html_structure "$output_file" "$project_name" "$embeddable" "$include_toc" "$format"; then
        log_debug "Structure HTML créée, début traitement chapitres..."
        log_debug "Chapitres disponibles (clés): ${!chapters_content[@]}"
        log_debug "Chapitres disponibles (debug): $(declare -p chapters_content)"

        # === TRAITEMENT CHAPITRES ===
        local chapter_count=0

        # Utiliser une approche différente pour lister les clés
        local chapter_keys=()
        for key in "${!chapters_content[@]}"; do
            chapter_keys+=("$key")
        done

        # Trier les clés numériquement
        IFS=$'\n' chapter_keys=($(sort -n <<<"${chapter_keys[*]}"))

        log_debug "Clés triées: ${chapter_keys[*]}"

        for chapter_num in "${chapter_keys[@]}"; do
            ((chapter_count++))

            # Vérifier que la clé existe
            if [[ -z "${chapters_content[$chapter_num]:-}" ]]; then
                log_debug "❌ Chapitre $chapter_num non trouvé dans chapters_content"
                continue
            fi

            log_debug "=== DÉBUT TRAITEMENT Ch$chapter_num ==="
            log_debug "Clés disponibles: ${!chapters_content[@]}"
            log_debug "Cherche clé: '$chapter_num'"
            log_debug "Valeur trouvée: '${chapters_content[$chapter_num]:-VIDE}'"

            local chapter_data="${chapters_content[$chapter_num]}"
            local chapter_title=$(get_chapter_title "$chapter_data")
            local chapter_content=$(get_chapter_content "$chapter_data")
            local parts_count=$(get_chapter_parts_count "$chapter_data")

            # Titre avec indication parties multiples
            local display_title
            if [[ "$parts_count" -gt 1 ]]; then
                display_title="$chapter_title ($parts_count parties)"
            else
                display_title="$chapter_title"
            fi

            log_debug "   📖 Ch.$chapter_num: $display_title"

            # Traiter le chapitre vers HTML
            process_chapter_to_html "$output_file" "$chapter_num" "$display_title" "$chapter_content" "$french_quotes" "$auto_dashes"
            log_debug "=== FIN TRAITEMENT Ch$chapter_num ==="
        done

        # === FERMETURE STRUCTURE HTML ===
        if [[ "$embeddable" != "true" ]]; then
            echo "</body>" >> "$output_file"
            echo "</html>" >> "$output_file"
        else
            echo "</div>" >> "$output_file"
        fi

        # === SUCCÈS ===
        local duration=$(end_timer "$start_time")
        log_success "✅ HTML généré: $output_file ($chapter_count chapitres, ${duration}s)"

        # Afficher infos fichier
        if [[ -f "$output_file" ]]; then
            local file_size=$(du -h "$output_file" | cut -f1)
            log_info "📄 Taille: $file_size"

            # Statistiques détaillées
            local total_sections=$(grep -c '<section class="chapter"' "$output_file" 2>/dev/null || echo "0")
            local total_articles=$(grep -c '<article class="narrative-block"' "$output_file" 2>/dev/null || echo "0")
            log_debug "📈 Structure: $total_sections sections, $total_articles blocs narratifs"
        fi

        return 0
    else
        log_error "❌ Échec génération structure HTML"
        return 1
    fi
}

# === CRÉATION STRUCTURE HTML ===
create_html_structure() {
    local output_file="$1"
    local project_name="$2"
    local embeddable="$3"
    local include_toc="$4"
    local format="$5"

    log_debug "📄 Création structure HTML (embeddable: $embeddable)"

    # Récupérer métadonnées depuis YAML
    local format_config="formats/$format.yaml"
    local author_name="${SILK_AUTHOR_NAME:-Auteur}"
    local css_content=""

    # Extraire CSS du YAML
    if [[ -f "$format_config" ]]; then
        css_content=$(extract_yaml_css "$format_config")
    fi

    # === DOCUMENT COMPLET OU FRAGMENT ===
    if [[ "$embeddable" != "true" ]]; then
        # Document HTML complet
        cat > "$output_file" << EOF
<!DOCTYPE html>
<html lang="fr-FR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$project_name</title>
    <meta name="author" content="$author_name">
    <meta name="description" content="Manuscrit généré avec SILK - Intelligence for Literary Kreation">
    <meta name="generator" content="SILK CLI">
    <meta name="keywords" content="fiction, roman, SILK, manuscrit">
EOF

        # Intégrer CSS si disponible
        if [[ -n "$css_content" ]]; then
            echo "    <style>" >> "$output_file"
            echo "$css_content" >> "$output_file"
            echo "    </style>" >> "$output_file"
        fi

        echo "</head>" >> "$output_file"
        echo "<body>" >> "$output_file"

        # Header avec titre et auteur
        echo "    <header>" >> "$output_file"
        echo "        <h1 class=\"main-title\">$project_name</h1>" >> "$output_file"
        echo "        <p class=\"author\">$author_name</p>" >> "$output_file"
        echo "    </header>" >> "$output_file"
        echo "" >> "$output_file"

        # Table des matières si demandée
        if [[ "$include_toc" == "true" ]]; then
            generate_toc_placeholder "$output_file"
        fi
    else
        # Fragment embeddable - juste conteneur
        echo "<!-- Fragment HTML SILK - Mode embeddable -->" > "$output_file"
        echo "<!-- Généré le $(date) -->" >> "$output_file"
        echo "<div class=\"silk-manuscript\">" >> "$output_file"
        echo "" >> "$output_file"
    fi

    return 0
}

# === EXTRACTION CSS DU YAML ===
extract_yaml_css() {
    local yaml_file="$1"
    local in_css=false
    local css_content=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^css:[[:space:]]*\| ]]; then
            in_css=true
            continue
        elif [[ "$in_css" == "true" ]]; then
            if [[ "$line" =~ ^[[:space:]]{2} ]] || [[ -z "$line" ]]; then
                # Ligne du CSS (indentée de 2 espaces) ou ligne vide
                if [[ "$line" =~ ^[[:space:]]{2}(.*)$ ]]; then
                    css_content="${css_content}${BASH_REMATCH[1]}"$'\n'
                else
                    css_content="${css_content}"$'\n'
                fi
            else
                # Fin du bloc CSS (ligne non indentée)
                break
            fi
        fi
    done < "$yaml_file"

    echo "$css_content"
}

# === GÉNÉRATION PLACEHOLDER TOC ===
generate_toc_placeholder() {
    local output_file="$1"

    cat >> "$output_file" << 'TOC_EOF'
    <nav id="TOC" class="table-of-contents">
        <h2>Table des matières</h2>
        <ul>
            <!-- TOC sera générée dynamiquement par JavaScript ou manuellement -->
        </ul>
    </nav>

TOC_EOF
}

# === TRAITEMENT CHAPITRE VERS HTML ===
process_chapter_to_html() {
    local output_file="$1"
    local chapter_num="$2"
    local chapter_title="$3"
    local content="$4"
    local french_quotes="$5"
    local auto_dashes="$6"

    # ID unique pour le chapitre (navigation)
    local chapter_id="ch-$chapter_num"

    # === DÉBUT SECTION CHAPITRE ===
    echo "    <section class=\"chapter\" id=\"$chapter_id\">" >> "$output_file"
    echo "        <h2>$chapter_title</h2>" >> "$output_file"
    echo "" >> "$output_file"

    # === PARSER CONTENU EN BLOCS NARRATIFS ===
    parse_narrative_blocks "$output_file" "$content" "$french_quotes" "$auto_dashes"

    # === FIN SECTION CHAPITRE ===
    echo "    </section>" >> "$output_file"
    echo "" >> "$output_file"
}

# === PARSER BLOCS NARRATIFS ===
parse_narrative_blocks() {
    local output_file="$1"
    local content="$2"
    local french_quotes="$3"
    local auto_dashes="$4"

    local current_block=""
    local block_count=0

    # Traiter ligne par ligne pour détecter séparateurs ---
    while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            # Fin du bloc narratif actuel
            if [[ -n "$current_block" ]]; then
                ((block_count++))
                output_narrative_block "$output_file" "$current_block" "$french_quotes" "$auto_dashes"
                current_block=""
            fi
        else
            # Ajouter ligne au bloc actuel
            if [[ -n "$current_block" ]]; then
                current_block="${current_block}"$'\n'"$line"
            else
                current_block="$line"
            fi
        fi
    done <<< "$content"

    # Traiter le dernier bloc s'il existe
    if [[ -n "$current_block" ]]; then
        ((block_count++))
        output_narrative_block "$output_file" "$current_block" "$french_quotes" "$auto_dashes"
    fi

    log_debug "      🎯 $block_count blocs narratifs générés"
}

# === SORTIE BLOC NARRATIF ===
output_narrative_block() {
    local output_file="$1"
    local block_content="$2"
    local french_quotes="$3"
    local auto_dashes="$4"

    echo "        <article class=\"narrative-block\">" >> "$output_file"

    # Traiter chaque ligne du bloc
    while IFS= read -r line; do
        process_line_to_html "$output_file" "$line" "$french_quotes" "$auto_dashes"
    done <<< "$block_content"

    echo "        </article>" >> "$output_file"
    echo "" >> "$output_file"
}

# === TRAITEMENT LIGNE VERS HTML ===
process_line_to_html() {
    local output_file="$1"
    local line="$2"
    local french_quotes="$3"
    local auto_dashes="$4"

    # Ignorer lignes vides (seront gérées par CSS)
    if [[ -z "$line" ]]; then
        return
    fi

    # === CONVENTIONS SILK ===
    if [[ "$line" == "~" ]]; then
        # Blanc typographique
        echo "            <div class=\"blank-space\"></div>" >> "$output_file"

    elif [[ "$line" =~ ^\*.*\*$ ]]; then
        # Indications temporelles/lieu *texte*
        local indication="${line:1:-1}"  # Supprimer * début et fin
        echo "            <p class=\"time-location\"><em>$indication</em></p>" >> "$output_file"

    else
        # === LIGNE DE TEXTE NORMALE ===
        local processed_line="$line"

        # Traitement guillemets français
        if [[ "$french_quotes" == "true" ]]; then
            # Remplacer "texte" par « texte »
            processed_line=$(echo "$processed_line" | sed 's/"([^"]*)"/« \1 »/g')
        fi

        # Traitement tirets cadratins
        if [[ "$auto_dashes" == "true" ]]; then
            # Remplacer — par vrai tiret cadratin
            processed_line=$(echo "$processed_line" | sed 's/—/—/g')
            # Ajouter tirets aux dialogues commençant par -
            processed_line=$(echo "$processed_line" | sed 's/^- /— /g')
        fi

        # Conversion Markdown basique vers HTML
        processed_line=$(process_markdown_to_html "$processed_line")

        # === DÉTECTION TYPE DE PARAGRAPHE ===
        if [[ "$processed_line" =~ ^[\"«—] ]] || [[ "$processed_line" =~ ^[[:space:]]*— ]]; then
            # Dialogue détecté
            echo "            <p class=\"dialogue\">$processed_line</p>" >> "$output_file"
        else
            # Paragraphe normal
            echo "            <p>$processed_line</p>" >> "$output_file"
        fi
    fi
}

# === CONVERSION MARKDOWN BASIQUE VERS HTML ===
process_markdown_to_html() {
    local text="$1"

    # Italique *texte* -> <em>texte</em> (mais pas **texte**)
    text=$(echo "$text" | sed 's/\*\([^*]*\)\*/<em>\1<\/em>/g')

    # Gras **texte** -> <strong>texte</strong>
    text=$(echo "$text" | sed 's/\*\*\([^*]*\)\*\*/<strong>\1<\/strong>/g')

    # Liens Obsidian [[liens|texte]] -> texte
    text=$(echo "$text" | sed -e 's/\[\[\([^|]*\)|\([^]]*\)\]\]/\2/g')

    # Liens Obsidian [[liens]] -> liens
    text=$(echo "$text" | sed -e 's/\[\[\([^]]*\)\]\]/\1/g')

    echo "$text"
}

# === EXPORTS ===
export -f generate_custom_html
export -f create_html_structure
export -f extract_yaml_css
export -f generate_toc_placeholder
export -f process_chapter_to_html
export -f parse_narrative_blocks
export -f output_narrative_block
export -f process_line_to_html
export -f process_markdown_to_html

# === MODULE CHARGÉ ===
readonly SILK_CORE_CUSTOM_HTML_LOADED=true
