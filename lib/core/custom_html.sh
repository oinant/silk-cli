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

# === GÉNÉRATION HTML SIMPLE AVEC PANDOC (VERSION DEBUGGÉE) ===
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

    log_info "🕸️ Génération HTML simple avec Pandoc..."

    # === COLLECTE CHAPITRES ===
    declare -A chapters_content
    if ! collect_chapters_content "$max_chapters" chapters_content; then
        log_error "Échec collecte chapitres"
        return 1
    fi

    local chapters_count=${#chapters_content[@]}
    if [[ $chapters_count -eq 0 ]]; then
        log_error "Aucun chapitre trouvé"
        return 1
    fi

    # === GÉNÉRATION NOM FICHIER ===
    local filename
    if [[ -n "$output_name" ]]; then
        filename="${output_name}.html"
    else
        filename="${project_name}-html-Ch${max_chapters}-${timestamp}.html"
    fi
    local output_file="$PUBLISH_OUTPUT_DIR/$filename"
    mkdir -p "$PUBLISH_OUTPUT_DIR"

    # === CRÉATION MARKDOWN TEMPORAIRE ===
    local temp_md="$PUBLISH_TEMP_DIR/silk_temp_${timestamp}.md"
    mkdir -p "$PUBLISH_TEMP_DIR"

    log_debug "📁 Création fichier temporaire: $temp_md"

    # En-tête du document
    {
        echo "---"
        echo "title: \"$project_name\""
        echo "author: \"${SILK_AUTHOR_NAME:-Auteur}\""
        echo "date: \"$(date '+%Y-%m-%d')\""
        echo "lang: fr-FR"
        echo "---"
        echo ""
    } > "$temp_md"

    # Vérifier que le fichier a été créé
    if [[ ! -f "$temp_md" ]]; then
        log_error "Impossible de créer le fichier temporaire: $temp_md"
        log_error "Répertoire: $PUBLISH_TEMP_DIR"
        log_error "Permissions: $(ls -la "$PUBLISH_TEMP_DIR" 2>/dev/null || echo "Répertoire inexistant")"
        return 1
    fi

    log_debug "✅ Fichier temporaire créé: $(ls -la "$temp_md")"

    # === TRAITEMENT CHAPITRES ===
    for chapter_num in $(printf '%s\n' "${!chapters_content[@]}" | sort -n); do
        local chapter_data="${chapters_content[$chapter_num]}"
        local chapter_title=$(get_chapter_title "$chapter_data")
        local chapter_content=$(get_chapter_content "$chapter_data")

        log_debug "   📝 Ajout Ch$chapter_num: $chapter_title"

        # Ajouter le chapitre au markdown
        {
            echo "# $chapter_title"
            echo ""

            # Traitement simple du contenu
            local processed_content="$chapter_content"

            # Guillemets français si demandé
            if [[ "$french_quotes" == "true" ]]; then
                processed_content=$(echo "$processed_content" | sed 's/"([^"]*)"/« \1 »/g')
            fi

            # Tirets cadratins si demandé
            if [[ "$auto_dashes" == "true" ]]; then
                processed_content=$(echo "$processed_content" | sed 's/^- /— /g')
            fi

            processed_content=$(echo "$processed_content" | sed 's/$/  /')

            echo "$processed_content"
            echo ""
            echo ""
        } >> "$temp_md"
    done

    # === VÉRIFICATION FICHIER FINAL ===
    if [[ ! -f "$temp_md" ]]; then
        log_error "Fichier markdown temporaire non trouvé après génération: $temp_md"
        return 1
    fi

    local file_size=$(wc -c < "$temp_md" 2>/dev/null || echo "0")
    log_debug "📄 Fichier markdown généré: $temp_md ($file_size octets)"

    # Debug: afficher les premières lignes
    log_debug "📋 Contenu (premières lignes):"
    head -10 "$temp_md" | while IFS= read -r line; do
        log_debug "    $line"
    done

    # === GÉNÉRATION PANDOC ===
    local pandoc_args=(
        "$temp_md"
        "-o" "$output_file"
        "-f" "markdown+smart"
        "-t" "html5"
    )

    # Mode embeddable ou standalone
    if [[ "$embeddable" == "true" ]]; then
        log_debug "Mode embeddable: fragment HTML"
    else
        pandoc_args+=("--standalone")
        log_debug "Mode standalone: document complet"
    fi

    # Table des matières si demandée
    if [[ "$include_toc" == "true" ]]; then
        pandoc_args+=("--toc" "--toc-depth=1")
    fi

    # === DIAGNOSTIC AVANT PANDOC ===
    log_debug "🔍 Diagnostic avant Pandoc:"
    log_debug "  - Fichier markdown: $temp_md $(if [[ -f "$temp_md" ]]; then echo "✅ ($(stat -c%s "$temp_md" 2>/dev/null || stat -f%z "$temp_md" 2>/dev/null) octets)"; else echo "❌"; fi)"
    log_debug "  - Répertoire sortie: $PUBLISH_OUTPUT_DIR $(if [[ -d "$PUBLISH_OUTPUT_DIR" ]]; then echo "✅"; else echo "❌"; fi)"
    log_debug "  - Commande: pandoc ${pandoc_args[*]}"

    # === EXÉCUTION PANDOC ===
    log_debug "🔄 Exécution Pandoc..."

    local pandoc_output
    if pandoc_output=$(pandoc "${pandoc_args[@]}" 2>&1); then
        local duration=$(end_timer "$start_time")
        log_success "✅ HTML généré: $output_file ($chapters_count chapitres, ${duration}s)"

        if [[ -f "$output_file" ]]; then
            local file_size=$(du -h "$output_file" | cut -f1)
            log_info "📄 Taille: $file_size"
            log_debug "🔍 Contenu fichier final (100 premiers caractères du body):"
            local html_sample=$(grep -A 10 "<body>" "$output_file" 2>/dev/null | head -c 200 || head -c 200 "$output_file")
            log_debug "🔍 Contenu HTML final: $html_sample"

        else
            log_warning "⚠️ Pandoc s'est terminé sans erreur mais le fichier de sortie n'existe pas"
        fi

        # Nettoyage
        if [[ "${SILK_DEBUG:-false}" != "true" ]]; then
            rm -f "$temp_md" 2>/dev/null
        else
            log_debug "🔍 Fichier temporaire conservé pour debug: $temp_md"
        fi

        return 0
    else
        log_error "❌ Échec génération Pandoc:"
        echo "$pandoc_output" | while IFS= read -r line; do
            log_error "    $line"
        done
        log_error "🔍 Fichier markdown existe: $(if [[ -f "$temp_md" ]]; then echo "OUI"; else echo "NON"; fi)"
        if [[ -f "$temp_md" ]]; then
            log_error "🔍 Taille fichier: $(stat -c%s "$temp_md" 2>/dev/null || stat -f%z "$temp_md" 2>/dev/null) octets"
        fi
        return 1
    fi
}

# === FONCTION PRINCIPALE GÉNÉRATION HTML CUSTOM ===
#generate_custom_html() {
#    local format="$1"
#    local max_chapters="$2"
#    local french_quotes="$3"
#    local auto_dashes="$4"
#    local output_name="$5"
#    local include_toc="$6"
#    local include_stats="$7"
#    local embeddable="$8"
#
#    local start_time=$(start_timer)
#    local timestamp=$(date +%Y%m%d-%H%M%S)
#    local project_name=$(basename "$PWD")
#
#    log_info "🕸️ Génération HTML custom: extraction directe chapitres..."
#
#    # === COLLECTE CHAPITRES DIRECTS (SANS PASSER PAR chapters_content) ===
#    local requested_chapters=()
#    parse_chapter_range "$max_chapters" requested_chapters
#
#    if [[ ${#requested_chapters[@]} -eq 0 ]]; then
#        log_error "Aucun chapitre valide trouvé pour: $max_chapters"
#        return 1
#    fi
#
#    log_debug "📊 ${#requested_chapters[@]} chapitres demandés"
#
#    # === GÉNÉRATION NOM FICHIER ===
#    local filename
#    if [[ -n "$output_name" ]]; then
#        filename="${output_name}.html"
#    else
#        local chapter_numbers=($(printf '%s\n' "${requested_chapters[@]}" | sort -n))
#
#        if [[ ${#chapter_numbers[@]} -eq 1 ]]; then
#            filename="${project_name}-${format}-Ch${chapter_numbers[0]}-${timestamp}.html"
#        elif [[ ${#chapter_numbers[@]} -le 5 ]]; then
#            local chapters_list=$(IFS='-'; echo "${chapter_numbers[*]}")
#            filename="${project_name}-${format}-Ch${chapters_list}-${timestamp}.html"
#        else
#            filename="${project_name}-${format}-${timestamp}.html"
#        fi
#    fi
#
#    local output_file="$PUBLISH_OUTPUT_DIR/$filename"
#    mkdir -p "$PUBLISH_OUTPUT_DIR"
#    log_info "🕸️ Génération HTML custom: $filename"
#
#    # === GÉNÉRATION STRUCTURE HTML ===
#    if create_html_structure "$output_file" "$project_name" "$embeddable" "$include_toc" "$format"; then
#        log_debug "Structure HTML créée, extraction directe chapitres..."
#
#        # === TRAITEMENT DIRECT DES CHAPITRES ===
#        local processed_count=0
#        for chapter_num in $(printf '%s\n' "${requested_chapters[@]}" | sort -n); do
#            log_debug "   📝 Extraction directe Ch$chapter_num..."
#
#            # Extraction directe depuis les fichiers
#            local chapter_title=""
#            local chapter_content=""
#            local found_file=false
#
#            for file in 01-Manuscrit/Ch*.md; do
#                if [[ -f "$file" ]] && grep -q "## manuscrit" "$file"; then
#                    local file_chapter_num=$(extract_chapter_number_from_filename "$file")
#                    if [[ "$file_chapter_num" == "$chapter_num" ]]; then
#                        chapter_title=$(head -n1 "$file" | sed 's/^#*\s*//')
#                        chapter_content=$(extract_manuscript_content "$file")
#                        found_file=true
#                        log_debug "   📄 Extrait depuis: $file"
#                        break
#                    fi
#                fi
#            done
#
#            if [[ "$found_file" == "true" && -n "$chapter_content" ]]; then
#                log_debug "   📊 Ch$chapter_num: '$chapter_title' ($(echo "$chapter_content" | wc -l) lignes)"
#                process_chapter_to_html "$output_file" "$chapter_num" "$chapter_title" "$chapter_content" "$french_quotes" "$auto_dashes"
#                ((processed_count++))
#                log_debug "   ✅ Ch$chapter_num traité"
#            else
#                log_warning "   ⚠️ Ch$chapter_num: fichier non trouvé ou contenu vide"
#            fi
#        done
#
#        # === FERMETURE STRUCTURE HTML ===
#        if [[ "$embeddable" != "true" ]]; then
#            echo "    </main>" >> "$output_file"
#            echo "</body>" >> "$output_file"
#            echo "</html>" >> "$output_file"
#        else
#            echo "</div>" >> "$output_file"
#        fi
#
#        local duration=$(end_timer "$start_time")
#        log_success "✅ HTML généré: $output_file ($processed_count chapitres, ${duration}s)"
#
#        if [[ -f "$output_file" ]]; then
#            local file_size=$(du -h "$output_file" | cut -f1)
#            log_info "📄 Taille: $file_size"
#        fi
#
#        return 0
#    else
#        log_error "❌ Échec génération structure HTML"
#        return 1
#    fi
#}
#
## === CRÉATION STRUCTURE HTML ===
#create_html_structure() {
#    local output_file="$1"
#    local project_name="$2"
#    local embeddable="$3"
#    local include_toc="$4"
#    local format="$5"
#
#    log_debug "📄 Création structure HTML (embeddable: $embeddable)"
#
#    # Récupérer métadonnées depuis YAML
#    local format_config="formats/$format.yaml"
#    local author_name="${SILK_AUTHOR_NAME:-Auteur}"
#    local css_content=""
#
#    # Extraire CSS du YAML
#    if [[ -f "$format_config" ]]; then
#        css_content=$(extract_yaml_css "$format_config")
#    fi
#
#    # === DOCUMENT COMPLET OU FRAGMENT ===
#    if [[ "$embeddable" != "true" ]]; then
#        # Document HTML complet
#        cat > "$output_file" << EOF
#<!DOCTYPE html>
#<html lang="fr-FR">
#<head>
#    <meta charset="UTF-8">
#    <meta name="viewport" content="width=device-width, initial-scale=1.0">
#    <title>$project_name</title>
#    <meta name="author" content="$author_name">
#    <meta name="description" content="Manuscrit généré avec SILK - Intelligence for Literary Kreation">
#    <meta name="generator" content="SILK CLI">
#    <meta name="keywords" content="fiction, roman, SILK, manuscrit">
#EOF
#
#        # Intégrer CSS si disponible
#        if [[ -n "$css_content" ]]; then
#            echo "    <style>" >> "$output_file"
#            echo "$css_content" >> "$output_file"
#            echo "    </style>" >> "$output_file"
#        fi
#
#        echo "</head>" >> "$output_file"
#        echo "<body>" >> "$output_file"
#
#        # Header avec titre et auteur
#        echo "    <header>" >> "$output_file"
#        echo "        <h1 class=\"main-title\">$project_name</h1>" >> "$output_file"
#        echo "        <p class=\"author\">$author_name</p>" >> "$output_file"
#        echo "    </header>" >> "$output_file"
#        echo "" >> "$output_file"
#
#        # Table des matières si demandée
#        if [[ "$include_toc" == "true" ]]; then
#            generate_toc_placeholder "$output_file"
#        fi
#    else
#        # Fragment embeddable - juste conteneur
#        echo "<!-- Fragment HTML SILK - Mode embeddable -->" > "$output_file"
#        echo "<!-- Généré le $(date) -->" >> "$output_file"
#        echo "<div class=\"silk-manuscript\">" >> "$output_file"
#        echo "" >> "$output_file"
#    fi
#
#    return 0
#}
#
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

## === GÉNÉRATION PLACEHOLDER TOC ===
#generate_toc_placeholder() {
#    local output_file="$1"
#
#    cat >> "$output_file" << 'TOC_EOF'
#    <nav id="TOC" class="table-of-contents">
#        <h2>Table des matières</h2>
#        <ul>
#            <!-- TOC sera générée dynamiquement par JavaScript ou manuellement -->
#        </ul>
#    </nav>
#
#TOC_EOF
#}
#
## === TRAITEMENT CHAPITRE VERS HTML ===
#process_chapter_to_html() {
#    local output_file="$1"
#    local chapter_num="$2"
#    local chapter_title="$3"
#    local content="$4"
#    local french_quotes="$5"
#    local auto_dashes="$6"
#
#    # ID unique pour le chapitre (navigation)
#    local chapter_id="ch-$chapter_num"
#
#    # === DÉBUT SECTION CHAPITRE ===
#    echo "    <section class=\"chapter\" id=\"$chapter_id\">" >> "$output_file"
#    echo "        <h2>$chapter_title</h2>" >> "$output_file"
#    echo "" >> "$output_file"
#
#    # === PARSER CONTENU EN BLOCS NARRATIFS ===
#    log_debug "   🔍 Contenu reçu: $(echo "$content" | wc -l) lignes"
#    parse_narrative_blocks "$output_file" "$content" "$french_quotes" "$auto_dashes"
#
#    # === FIN SECTION CHAPITRE ===
#    echo "    </section>" >> "$output_file"
#    echo "" >> "$output_file"
#}
#
## === PARSER BLOCS NARRATIFS ===
#parse_narrative_blocks() {
#    local output_file="$1"
#    local content="$2"
#    local french_quotes="$3"
#    local auto_dashes="$4"
#
#    log_debug "      📝 Parser blocs narratifs..."
#    # SÉCURISATION : Vérifier que le contenu existe et n'est pas vide
#    if [[ -z "$content" ]]; then
#        log_debug "      ⚠️ Contenu vide dans parse_narrative_blocks"
#        return 0
#    fi
#
#    local current_block=""
#    local block_count=0
#    local block_has_content=false
#
#    log_debug "      📝 Parser blocs narratifs - Contenu: $(echo "$content" | wc -l) lignes"
#
#    # PROTECTION : Utiliser un fichier temporaire au lieu de heredoc
#    local temp_file=$(mktemp)
#    echo "$content" > "$temp_file"
#
#    while IFS= read -r line; do
#        # TEST : Vérifier que la ligne est lisible
#        if ! printf '%s\n' "$line" > /dev/null 2>&1; then
#            log_debug "      ⚠️ Ligne problématique ignorée"
#            continue
#        fi
#
#        log_debug "      📝 line: '$(printf '%q' "$line")'"  # Échapper les caractères spéciaux
#
#        if [[ "$line" == "---" ]]; then
#            # Fin du bloc narratif actuel
#            if [[ "$block_has_content" == "true" ]]; then
#                ((block_count++))
#                log_debug "      📝 Traitement bloc #$block_count"
#                output_narrative_block "$output_file" "$current_block" "$french_quotes" "$auto_dashes"
#                current_block=""
#                block_has_content=false
#            fi
#        else
#            # Ajouter ligne au bloc actuel
#            if [[ ${#current_block} -gt 0 ]]; then
#                current_block="${current_block}"$'\n'"$line"
#            else
#                current_block="$line"
#            fi
#
#            # Marquer le bloc comme ayant du contenu si la ligne n'est pas vide
#            if [[ -n "$line" ]]; then
#                block_has_content=true
#            fi
#        fi
#    done < "$temp_file"
#
#    # Nettoyage
#    rm -f "$temp_file"
#
#    # Traiter le dernier bloc s'il existe
#    if [[ "$block_has_content" == "true" ]]; then
#        ((block_count++))
#        log_debug "      📝 Bloc final #$block_count"
#        output_narrative_block "$output_file" "$current_block" "$french_quotes" "$auto_dashes"
#    fi
#
#    log_debug "      🎯 $block_count blocs narratifs générés"
#}
#
## === SORTIE BLOC NARRATIF ===
#output_narrative_block() {
#    local output_file="$1"
#    local block_content="$2"
#    local french_quotes="$3"
#    local auto_dashes="$4"
#
#    echo "        <article class=\"narrative-block\">" >> "$output_file"
#
#    # Traiter chaque ligne du bloc
#    while IFS= read -r line; do
#        process_line_to_html "$output_file" "$line" "$french_quotes" "$auto_dashes"
#    done <<< "$block_content"
#
#    echo "        </article>" >> "$output_file"
#    echo "" >> "$output_file"
#}
#
## === TRAITEMENT LIGNE VERS HTML ===
#process_line_to_html() {
#    local output_file="$1"
#    local line="$2"
#    local french_quotes="$3"
#    local auto_dashes="$4"
#
#    # Ignorer lignes vides (seront gérées par CSS)
#    if [[ -z "$line" ]]; then
#        return
#    fi
#
#    # === CONVENTIONS SILK ===
#    if [[ "$line" == "~" ]]; then
#        # Blanc typographique
#        echo "            <div class=\"blank-space\"></div>" >> "$output_file"
#
#    elif [[ "$line" =~ ^\*+.*\*+$ ]]; then
#        # Indications temporelles/lieu avec * ou **
#        local indication=$(echo "$line" | sed 's/^\*\+//; s/\*\+$//')
#        echo "            <p class=\"time-location\"><em>$indication</em></p>" >> "$output_file"
#
#    else
#        # === LIGNE DE TEXTE NORMALE ===
#        local processed_line="$line"
#
#        # Traitement guillemets français
#        if [[ "$french_quotes" == "true" ]]; then
#            processed_line=$(echo "$processed_line" | sed 's/"([^"]*)"/« \1 »/g')
#        fi
#
#        # Traitement tirets cadratins
#        if [[ "$auto_dashes" == "true" ]]; then
#            processed_line=$(echo "$processed_line" | sed 's/—/—/g')
#            processed_line=$(echo "$processed_line" | sed 's/^- /— /g')
#        fi
#
#        # Conversion Markdown basique vers HTML
#        processed_line=$(process_markdown_to_html "$processed_line")
#
#        # === DÉTECTION TYPE DE PARAGRAPHE ===
#        if [[ "$processed_line" =~ ^[\"«—] ]] || [[ "$processed_line" =~ ^[[:space:]]*— ]]; then
#            # Dialogue détecté
#            echo "            <p class=\"dialogue\">$processed_line</p>" >> "$output_file"
#        else
#            # Paragraphe normal
#            echo "            <p>$processed_line</p>" >> "$output_file"
#        fi
#    fi
#}
#
## === CONVERSION MARKDOWN BASIQUE VERS HTML ===
#process_markdown_to_html() {
#    local text="$1"
#
#    # Gras **texte** -> <strong>texte</strong>
#    text=$(echo "$text" | sed 's/\*\*\([^*]*\)\*\*/<strong>\1<\/strong>/g')
#
#    # Italique *texte* -> <em>texte</em> (mais pas **texte**)
#    text=$(echo "$text" | sed 's/\*\([^*]*\)\*/<em>\1<\/em>/g')
#
#    # Liens Obsidian [[liens|texte]] -> texte
#    text=$(echo "$text" | sed -e 's/\[\[\([^|]*\)|\([^]]*\)\]\]/\2/g')
#
#    # Liens Obsidian [[liens]] -> liens
#    text=$(echo "$text" | sed -e 's/\[\[\([^]]*\)\]\]/\1/g')
#
#    echo "$text"
#}

# === EXPORTS ===
export -f generate_custom_html
#export -f create_html_structure
export -f extract_yaml_css
#export -f generate_toc_placeholder
#export -f process_chapter_to_html
#export -f parse_narrative_blocks
#export -f output_narrative_block
#export -f process_line_to_html
#export -f process_markdown_to_html

# === MODULE CHARGÉ ===
readonly SILK_CORE_CUSTOM_HTML_LOADED=true
