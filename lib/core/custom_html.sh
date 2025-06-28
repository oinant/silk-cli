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

# === FONCTION PRINCIPALE (ORCHESTRATEUR) ===
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

    log_info "🕸️ Génération HTML sémantique directe..."

    # 1. Valider les paramètres et préparer l'environnement
    if ! setup_html_generation_environment "$timestamp"; then
        return 1
    fi

    # 2. Générer le nom de fichier de sortie
    local output_file
    if ! output_file=$(generate_html_output_filename "$project_name" "$max_chapters" "$output_name" "$timestamp"); then
        return 1
    fi

    # 3. Générer directement le HTML final
    if ! generate_direct_html_output "$output_file" "$max_chapters" "$project_name" "$french_quotes" "$auto_dashes" "$format" "$include_toc" "$embeddable"; then
        return 1
    fi

    # 4. Rapport final
    generate_html_success_report "$output_file" "$start_time" "$max_chapters"

    return 0
}

# === PRÉPARATION ENVIRONNEMENT ===
setup_html_generation_environment() {
    local timestamp="$1"

    # Créer les répertoires nécessaires
    mkdir -p "$PUBLISH_OUTPUT_DIR" "$PUBLISH_TEMP_DIR"

    # Valider que les modules requis sont chargés
    if [[ "${SILK_CORE_CHAPTERS_LOADED:-false}" != "true" ]]; then
        log_error "Module core/chapters requis"
        return 1
    fi

    log_debug "✅ Environnement préparé (timestamp: $timestamp)"
    return 0
}

# === GÉNÉRATION NOM FICHIER ===
generate_html_output_filename() {
    local project_name="$1"
    local max_chapters="$2"
    local output_name="$3"
    local timestamp="$4"

    local filename
    if [[ -n "$output_name" ]]; then
        filename="${output_name}.html"
    else
        filename="${project_name}-semantic-Ch${max_chapters}-${timestamp}.html"
    fi

    echo "$PUBLISH_OUTPUT_DIR/$filename"
    return 0
}

# === GÉNÉRATION HTML DIRECTE ===
generate_direct_html_output() {
    local output_file="$1"
    local max_chapters="$2"
    local project_name="$3"
    local french_quotes="$4"
    local auto_dashes="$5"
    local format="$6"
    local include_toc="$7"
    local embeddable="$8"

    log_debug "📄 Création structure HTML directe: $output_file"

    # 1. Collecter les chapitres
    declare -A chapters_content
    if ! collect_chapters_content "$max_chapters" chapters_content; then
        log_error "Échec collecte chapitres"
        return 1
    fi

    # 2. Commencer le fichier HTML
    if ! start_html_document "$output_file" "$project_name" "$format" "$embeddable"; then
        return 1
    fi

    # 3. Ajouter la table des matières si demandée
    if [[ "$include_toc" == "true" ]]; then
        if ! add_table_of_contents "$output_file" chapters_content; then
            return 1
        fi
    fi

    # 4. Traiter chaque chapitre
    if ! process_chapters_to_html "$output_file" chapters_content "$french_quotes" "$auto_dashes"; then
        return 1
    fi

    # 5. Fermer le document HTML
    if ! close_html_document "$output_file" "$embeddable"; then
        return 1
    fi

    # 6. Valider le fichier créé
    if [[ ! -f "$output_file" ]] || [[ ! -s "$output_file" ]]; then
        log_error "Fichier HTML vide ou manquant"
        return 1
    fi

    local file_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null)
    log_debug "✅ HTML sémantique créé ($file_size octets)"

    return 0
}

# === DÉBUT DOCUMENT HTML ===
start_html_document() {
    local output_file="$1"
    local project_name="$2"
    local format="$3"
    local embeddable="$4"

    if [[ "$embeddable" != "true" ]]; then
        # Document HTML complet
        {
            echo '<!DOCTYPE html>'
            echo '<html lang="fr-FR">'
            echo '<head>'
            echo "  <meta charset=\"UTF-8\">"
            echo "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">"
            echo "  <title>$project_name</title>"
            add_embedded_css "$format"
            echo '</head>'
            echo '<body>'
        } > "$output_file"
    fi

    # Conteneur principal
    echo '<div class="silk-manuscript">' >> "$output_file"

    if [[ "$embeddable" != "true" ]]; then
        # En-tête pour document complet
        {
            echo '<header>'
            echo "  <h1 class=\"main-title\">$project_name</h1>"
            echo "  <p class=\"author\">${SILK_AUTHOR_NAME:-Auteur}</p>"
            echo '</header>'
        } >> "$output_file"
    fi

    return 0
}

# === CSS INTÉGRÉ ===
add_embedded_css() {
    local format="$1"

    # CSS depuis le format si disponible
    local format_config="lib/templates/formats/$format.yaml"
    if [[ -f "$format_config" ]]; then
        local css_content=$(extract_yaml_css "$format_config")
        if [[ -n "$css_content" ]]; then
            echo "  <style>"
            echo "$css_content"
            echo "  </style>"
            return 0
        fi
    fi

    # CSS par défaut
    echo "  <style>"
    echo "    body { font-family: Georgia, serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 2rem; text-align: justify; }"
    echo "    .silk-manuscript { margin: 0; padding: 0; }"
    echo "    header { text-align: center; margin-bottom: 3rem; border-bottom: 1px solid #eee; padding-bottom: 2rem; }"
    echo "    .main-title { font-size: 2.5em; margin-bottom: 0.5rem; color: #333; }"
    echo "    .author { font-size: 1.2em; color: #666; font-style: italic; }"
    echo "    .chapter { margin-bottom: 3rem; border-bottom: 1px solid #f0f0f0; padding-bottom: 2rem; }"
    echo "    .chapter:last-child { border-bottom: none; }"
    echo "    .chapter h2 { text-align: center; margin-bottom: 2rem; font-size: 1.8em; color: #444; }"
    echo "    .narrative-section { margin-bottom: 2rem; }"
    echo "    /* Style livre : pas d'espacement entre paragraphes, indentation première ligne */"
    echo "    p { margin: 0; text-indent: 1.5em; text-align: justify; }"
    echo "    /* Premier paragraphe d'une section : pas d'indentation */"
    echo "    .narrative-section > p:first-of-type, h2 + .narrative-section p:first-child, h3 + p { text-indent: 0; }"
    echo "    /* Classes sémantiques pour narration et dialogues */"
    echo "    .narration { text-indent: 1.5em; }"
    echo "    .dialogue { text-indent: 0 !important; margin-left: 1em; font-style: italic; }"
    echo "    /* Indications temporelles/lieu - sans centrage */"
    echo "    .time-location { font-style: italic; color: #666; margin: 1rem 0; text-indent: 0; }"
    echo "    /* Blanc typographique */"
    echo "    .blank-space { height: 2rem; text-align: center; margin: 1.5rem 0; }"
    echo "    .blank-space::after { content: '⁂'; color: #666; font-size: 1.2em; }"
    echo "    /* Styles pour les éléments en italique (pensées, titres, lectures) */"
    echo "    em { font-style: italic; color: #555; }"
    echo "    /* Table des matières */"
    echo "    .table-of-contents { background: #f9f9f9; padding: 2rem; margin-bottom: 3rem; border-radius: 8px; }"
    echo "    .table-of-contents h2 { margin-top: 0; text-align: center; }"
    echo "    .table-of-contents ul { list-style: none; padding: 0; }"
    echo "    .table-of-contents li { margin: 0.5rem 0; }"
    echo "    .table-of-contents a { text-decoration: none; color: #333; }"
    echo "    .table-of-contents a:hover { color: #666; }"
    echo "    /* Responsive */"
    echo "    @media (max-width: 768px) {"
    echo "      body { padding: 1rem; font-size: 16px; }"
    echo "      .main-title { font-size: 2em; }"
    echo "      .chapter h2 { font-size: 1.5em; }"
    echo "      p { text-indent: 1em; }"
    echo "    }"
    echo "  </style>"
}

# === TABLE DES MATIÈRES ===
add_table_of_contents() {
    local output_file="$1"
    local -n chapters_ref="$2"

    {
        echo '<nav class="table-of-contents">'
        echo '  <h2>Table des matières</h2>'
        echo '  <ul>'
    } >> "$output_file"

    # Ajouter chaque chapitre dans l'ordre
    for chapter_num in $(printf '%s\n' "${!chapters_ref[@]}" | sort -n); do
        local full_data="${chapters_ref[$chapter_num]}"
        local chapter_title="${full_data%%|*}"

        echo "    <li><a href=\"#chapter-$chapter_num\">$chapter_title</a></li>" >> "$output_file"
    done

    {
        echo '  </ul>'
        echo '</nav>'
        echo
    } >> "$output_file"

    return 0
}

# === TRAITEMENT CHAPITRES VERS HTML ===
process_chapters_to_html() {
    local output_file="$1"
    local -n chapters_ref="$2"
    local french_quotes="$3"
    local auto_dashes="$4"

    local processed_count=0

    # Traiter chaque chapitre dans l'ordre numérique
    for chapter_num in $(printf '%s\n' "${!chapters_ref[@]}" | sort -n); do
        # Extraire titre et contenu
        local full_data="${chapters_ref[$chapter_num]}"
        local chapter_title="${full_data%%|*}"

        local temp_data="${full_data#*|}"
        local encoded_chapter_content="${temp_data%|*}"

        local chapter_content
        if chapter_content=$(echo "$encoded_chapter_content" | base64 -d 2>/dev/null); then
            log_debug "✅ Ch.$chapter_num: contenu décodé avec succès"
        else
            log_debug "⚠️ Ch.$chapter_num: contenu déjà en clair ou erreur décodage"
        fi

        log_debug "📖 Conversion Ch.$chapter_num: $chapter_title"

        # Transformer et ajouter au fichier HTML
        if ! transform_chapter_to_html "$output_file" "$chapter_content" "$chapter_num" "$chapter_title" "$french_quotes" "$auto_dashes"; then
            log_error "Échec conversion Ch.$chapter_num"
            return 1
        fi

        ((processed_count++))
    done

    log_debug "✅ $processed_count chapitres convertis"
    return 0
}

# === TRANSFORMATION CHAPITRE VERS HTML ===
transform_chapter_to_html() {
    local output_file="$1"
    local content="$2"
    local chapter_num="$3"
    local chapter_title="$4"
    local french_quotes="$5"
    local auto_dashes="$6"

    # Commencer l'article
    echo "<article class=\"chapter\" id=\"chapter-$chapter_num\">" >> "$output_file"

    # Titre du chapitre (seulement si ce n'est pas un "Bis")
    if [[ ! "$chapter_title" =~ [Bb]is ]]; then
        echo "  <h2>$chapter_title</h2>" >> "$output_file"
    fi

    local in_section=false
    local section_count=0
    local current_section_content=""

    # Traiter le contenu ligne par ligne
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Détecter début de section (---)
        if [[ "$line" == "---" ]]; then
            # Fermer la section précédente si elle existe
            if [[ "$in_section" == true ]]; then
                echo "$current_section_content" >> "$output_file"
                echo "  </section>" >> "$output_file"
                current_section_content=""
            fi

            # Commencer nouvelle section
            ((section_count++))
            echo "  <section class=\"narrative-section\" id=\"chapter-$chapter_num-section-$section_count\">" >> "$output_file"
            in_section=true
            continue
        fi

        # Si on n'est pas encore dans une section et qu'on a du contenu, en créer une
        if [[ "$in_section" == false && -n "$line" ]]; then
            ((section_count++))
            echo "  <section class=\"narrative-section\" id=\"chapter-$chapter_num-section-$section_count\">" >> "$output_file"
            in_section=true
        fi

        # Traiter les différents types de contenu
        if [[ -n "$line" ]]; then
            local html_line
            if html_line=$(process_content_line_to_html "$line" "$french_quotes" "$auto_dashes"); then
                current_section_content+="$html_line"
            fi
        else
            # Ligne vide - l'ajouter au contenu de section
            current_section_content+=$'\n'
        fi

    done <<< "$content"

    # Fermer la dernière section si elle était ouverte
    if [[ "$in_section" == true ]]; then
        echo "$current_section_content" >> "$output_file"
        echo "  </section>" >> "$output_file"
    fi

    # Fermer l'article
    echo "</article>" >> "$output_file"
    echo >> "$output_file"

    return 0
}

# === TRAITEMENT LIGNE DE CONTENU VERS HTML ===
process_content_line_to_html() {
    local line="$1"
    local french_quotes="$2"
    local auto_dashes="$3"

    # Traiter les indications spatio-temporelles **texte**
    if [[ "$line" =~ ^\*\*.*\*\*$ ]]; then
        local indication="${line:2:-2}"  # Enlever les **
        echo "    <h3 class=\"time-location\">$indication</h3>"$'\n'
        return 0
    fi

    # Blanc typographique
    if [[ "$line" == "~" ]]; then
        echo "    <div class=\"blank-space\"></div>"$'\n'
        return 0
    fi

    # Ligne vide
    if [[ -z "$line" ]]; then
        echo $'\n'
        return 0
    fi

    # Appliquer transformations typographiques et Markdown
    local processed_line="$line"

    # 1. Traiter l'italique *texte* -> <em>texte</em>
    processed_line=$(echo "$processed_line" | sed 's/\*\([^*]*\)\*/<em>\1<\/em>/g')

    # 2. Guillemets français
    if [[ "$french_quotes" == "true" ]]; then
        # Remplacer guillemets droits par guillemets français
        processed_line="${processed_line//\"/« }"
        processed_line="${processed_line//\"/» }"
    fi

    # 3. Tirets cadratins
    if [[ "$auto_dashes" == "true" ]]; then
        # Remplacer -- par — (tiret cadratin)
        processed_line="${processed_line//--/—}"
    fi

    # Détecter type de contenu et wrapper approprié
    if [[ "$processed_line" =~ ^[\"«—] ]] || [[ "$processed_line" =~ ^[[:space:]]*— ]]; then
        # Dialogue
        echo "    <p class=\"dialogue\">$processed_line</p>"$'\n'
    else
        # Paragraphe narratif normal
        echo "    <p class=\"narration\">$processed_line</p>"$'\n'
    fi

    return 0
}

# === EXTRACTION CSS DEPUIS YAML ===
extract_yaml_css() {
    local yaml_file="$1"

    if [[ ! -f "$yaml_file" ]]; then
        return 1
    fi

    # Extraire le bloc CSS multiline du YAML
    local in_css_block=false
    local css_content=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^css:[[:space:]]*\| ]]; then
            # Début du bloc CSS avec |
            in_css_block=true
            continue
        elif [[ "$in_css_block" == true ]]; then
            if [[ "$line" =~ ^[[:space:]]{2,} ]] || [[ -z "$line" ]]; then
                # Ligne indentée ou vide = contenu CSS
                local clean_line="${line#  }"  # Supprimer 2 espaces d'indentation
                css_content+="$clean_line"$'\n'
            else
                # Ligne non indentée = fin du bloc CSS
                break
            fi
        fi
    done < "$yaml_file"

    echo "$css_content"
    return 0
}

# === FERMETURE DOCUMENT HTML ===
close_html_document() {
    local output_file="$1"
    local embeddable="$2"

    # Fermer le conteneur principal
    echo '</div>' >> "$output_file"

    if [[ "$embeddable" != "true" ]]; then
        # Fermer document complet
        {
            echo '</body>'
            echo '</html>'
        } >> "$output_file"
    fi

    return 0
}

# === RAPPORT FINAL ===
generate_html_success_report() {
    local output_file="$1"
    local start_time="$2"
    local max_chapters="$3"

    local duration=$(end_timer "$start_time")

    log_success "✅ HTML sémantique généré: $output_file"
    log_info "📊 Résumé:"
    log_info "   📚 Chapitres: $max_chapters"
    log_info "   ⏱️  Durée: ${duration}s"

    if [[ -f "$output_file" ]]; then
        local file_size=$(du -h "$output_file" | cut -f1)
        log_info "   📄 Taille: $file_size"
    fi

    return 0
}

# === EXPORTS ===
export -f generate_custom_html
export -f setup_html_generation_environment
export -f generate_html_output_filename
export -f generate_direct_html_output
export -f start_html_document
export -f add_embedded_css
export -f add_table_of_contents
export -f process_chapters_to_html
export -f transform_chapter_to_html
export -f process_content_line_to_html
export -f extract_yaml_css
export -f close_html_document
export -f generate_html_success_report

# === MODULE CHARGÉ ===
readonly SILK_CORE_CUSTOM_HTML_LOADED=true
