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


# === EXPORTS ===
export -f generate_custom_html
export -f extract_yaml_css

# === MODULE CHARGÉ ===
readonly SILK_CORE_CUSTOM_HTML_LOADED=true
