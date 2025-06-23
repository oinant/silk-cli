#!/bin/bash
# install-html-custom.sh - Installation génération HTML custom pour SILK

set -e

echo "🕸️ Installation HTML Custom SILK"
echo "================================="

# === VÉRIFICATIONS PRÉALABLES ===
echo
echo "📋 Vérifications préalables..."

# Vérifier qu'on est dans un projet SILK
if [[ ! -f "silk" ]] && [[ ! -f "../silk" ]]; then
    echo "❌ Ce script doit être exécuté dans le répertoire SILK"
    echo "   Assurez-vous d'être dans le dossier contenant le script 'silk'"
    exit 1
fi

# Ajuster le chemin si nécessaire
if [[ -f "../silk" ]]; then
    cd ..
fi

# Vérifier structure SILK
required_dirs=("lib" "lib/commands" "lib/templates" "lib/templates/formats")
for dir in "${required_dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
        echo "❌ Répertoire manquant: $dir"
        echo "   Structure SILK incomplète"
        exit 1
    fi
done

echo "✅ Structure SILK validée"

# === SAUVEGARDE ===
echo
echo "💾 Sauvegarde des fichiers existants..."

backup_dir="backup-html-custom-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"

# Sauvegarder si existe déjà
if [[ -f "lib/commands/custom_html.sh" ]]; then
    cp "lib/commands/custom_html.sh" "$backup_dir/"
    echo "   📄 custom_html.sh → $backup_dir/"
fi

if [[ -f "lib/templates/formats/html-custom.yaml" ]]; then
    cp "lib/templates/formats/html-custom.yaml" "$backup_dir/"
    echo "   📄 html-custom.yaml → $backup_dir/"
fi

if [[ -f "lib/commands/publish.sh" ]]; then
    cp "lib/commands/publish.sh" "$backup_dir/"
    echo "   📄 publish.sh → $backup_dir/"
fi

echo "✅ Sauvegarde créée: $backup_dir/"

# === INSTALLATION MODULE PRINCIPAL ===
echo
echo "📦 Installation module custom_html.sh..."

cat > "lib/commands/custom_html.sh" << 'CUSTOM_HTML_EOF'
#!/bin/bash
# lib/commands/custom_html.sh - Générateur HTML custom pour SILK
# Installation automatique - Version complète intégrée

# Marquer module comme chargé
readonly SILK_CUSTOM_HTML_LOADED=true

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

    # Nom de fichier de sortie
    local filename
    if [[ -n "$output_name" ]]; then
        filename="${output_name}.html"
    else
        if [[ "$max_chapters" != "99" ]]; then
            local chapter_suffix=""
            if [[ "$max_chapters" == *","* ]]; then
                chapter_suffix="Ch$(echo "$max_chapters" | tr ',' '-')"
            elif [[ "$max_chapters" == *"-"* ]]; then
                chapter_suffix="Ch$(echo "$max_chapters" | tr '-' 'à')"
            else
                chapter_suffix="Ch${max_chapters}"
            fi
            filename="${project_name}-${format}-${chapter_suffix}-${timestamp}.html"
        else
            filename="${project_name}-${format}-${timestamp}.html"
        fi
    fi

    local output_file="$PUBLISH_OUTPUT_DIR/$filename"

    # Créer répertoires nécessaires
    mkdir -p "$PUBLISH_OUTPUT_DIR"

    log_info "🕸️ Génération HTML custom: $filename"

    # Collecter les fichiers chapitres
    local chapter_files=()
    collect_chapter_files chapter_files "$max_chapters"

    if [[ ${#chapter_files[@]} -eq 0 ]]; then
        log_error "Aucun chapitre trouvé dans 01-Manuscrit/"
        return 1
    fi

    log_debug "Fichiers collectés: ${#chapter_files[@]} chapitres"

    # Générer HTML
    if create_html_structure "$output_file" "$project_name" "$embeddable" "$include_toc" "$format"; then
        # Traiter chaque chapitre
        local chapter_count=0
        for chapter_file in "${chapter_files[@]}"; do
            ((chapter_count++))
            local chapter_num=$(extract_chapter_number "$chapter_file")
            local chapter_title=$(extract_chapter_title "$chapter_file")
            local content=$(extract_manuscript_content "$chapter_file")

            if [[ -n "$content" ]]; then
                log_debug "   📖 Ch.$chapter_num: $chapter_title"
                process_chapter_to_html "$output_file" "$chapter_num" "$chapter_title" "$content" "$french_quotes" "$auto_dashes"
            fi
        done

        # Fermer la structure HTML si pas embeddable
        if [[ "$embeddable" != "true" ]]; then
            echo "</body>" >> "$output_file"
            echo "</html>" >> "$output_file"
        else
            echo "</div>" >> "$output_file"
        fi

        local duration=$(end_timer "$start_time")
        log_success "✅ HTML généré: $output_file ($chapter_count chapitres, ${duration}s)"

        # Afficher infos fichier
        if [[ -f "$output_file" ]]; then
            local file_size=$(du -h "$output_file" | cut -f1)
            log_info "📄 Taille: $file_size"
        fi

        return 0
    else
        log_error "❌ Échec génération HTML"
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
    local format_config="lib/templates/formats/$format.yaml"
    local author_name="${SILK_AUTHOR_NAME:-Auteur}"
    local css_content=""

    # Extraire CSS du YAML
    if [[ -f "$format_config" ]]; then
        css_content=$(extract_yaml_css "$format_config")
    fi

    # Début du document si pas embeddable
    if [[ "$embeddable" != "true" ]]; then
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
EOF

        # Intégrer CSS
        if [[ -n "$css_content" ]]; then
            echo "    <style>" >> "$output_file"
            echo "$css_content" >> "$output_file"
            echo "    </style>" >> "$output_file"
        fi

        echo "</head>" >> "$output_file"
        echo "<body>" >> "$output_file"

        # Titre principal
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
        # Mode embeddable - juste une div conteneur
        echo "<!-- Fragment HTML SILK - Mode embeddable -->" > "$output_file"
        echo "<div class=\"silk-manuscript\">" >> "$output_file"
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
                # Ligne du CSS (indentée) ou ligne vide
                if [[ "$line" =~ ^[[:space:]]{2}(.*)$ ]]; then
                    css_content="${css_content}${BASH_REMATCH[1]}"$'\n'
                else
                    css_content="${css_content}"$'\n'
                fi
            else
                # Fin du bloc CSS
                break
            fi
        fi
    done < "$yaml_file"

    echo "$css_content"
}

# === GÉNÉRATION PLACEHOLDER TOC ===
generate_toc_placeholder() {
    local output_file="$1"

    cat >> "$output_file" << 'EOF'
    <nav id="TOC" class="table-of-contents">
        <h2>Table des matières</h2>
        <ul>
            <!-- TOC sera générée dynamiquement -->
        </ul>
    </nav>

EOF
}

# === TRAITEMENT CHAPITRE VERS HTML ===
process_chapter_to_html() {
    local output_file="$1"
    local chapter_num="$2"
    local chapter_title="$3"
    local content="$4"
    local french_quotes="$5"
    local auto_dashes="$6"

    # ID unique pour le chapitre
    local chapter_id="ch-$chapter_num"

    # Début section chapitre
    echo "    <section class=\"chapter\" id=\"$chapter_id\">" >> "$output_file"
    echo "        <h2>$chapter_title</h2>" >> "$output_file"
    echo "" >> "$output_file"

    # Parser le contenu en blocs narratifs
    parse_narrative_blocks "$output_file" "$content" "$french_quotes" "$auto_dashes"

    # Fin section chapitre
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

    # Traiter ligne par ligne
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

    log_debug "      🎯 $block_count blocs narratifs"
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

    # Ignorer lignes vides en début/fin
    if [[ -z "$line" ]]; then
        return
    fi

    # Traitement des conventions SILK
    if [[ "$line" == "~" ]]; then
        # Blanc typographique
        echo "            <div class=\"blank-space\"></div>" >> "$output_file"

    elif [[ "$line" =~ ^\*.*\*$ ]]; then
        # Indications temporelles/lieu *texte*
        local indication="${line:1:-1}"
        echo "            <p class=\"time-location\"><em>$indication</em></p>" >> "$output_file"

    else
        # Ligne de texte normale
        local processed_line="$line"

        # Traitement guillemets français
        if [[ "$french_quotes" == "true" ]]; then
            processed_line=$(echo "$processed_line" | sed 's/"([^"]*)"/« \1 »/g')
        fi

        # Traitement tirets cadratins
        if [[ "$auto_dashes" == "true" ]]; then
            processed_line=$(echo "$processed_line" | sed 's/—/—/g')
            processed_line=$(echo "$processed_line" | sed 's/^- /— /g')
        fi

        # Conversion Markdown basique vers HTML
        processed_line=$(process_markdown_to_html "$processed_line")

        # Détecter dialogue et appliquer classe appropriée
        if [[ "$processed_line" =~ ^[\"«—] ]] || [[ "$processed_line" =~ ^[[:space:]]*— ]]; then
            echo "            <p class=\"dialogue\">$processed_line</p>" >> "$output_file"
        else
            echo "            <p>$processed_line</p>" >> "$output_file"
        fi
    fi
}

# === CONVERSION MARKDOWN BASIQUE ===
process_markdown_to_html() {
    local text="$1"

    # Italique *texte* -> <em>texte</em>
    text=$(echo "$text" | sed 's/\*\([^*]*\)\*/<em>\1<\/em>/g')

    # Gras **texte** -> <strong>texte</strong>
    text=$(echo "$text" | sed 's/\*\*\([^*]*\)\*\*/<strong>\1<\/strong>/g')

    # Liens Obsidian [[liens]]
    text=$(echo "$text" | sed -e 's/\[\[\([^|]*\)|\([^]]*\)\]\]/\2/g' -e 's/\[\[\([^]]*\)\]\]/\1/g')

    echo "$text"
}

# === COLLECTE FICHIERS CHAPITRES ===
collect_chapter_files() {
    local -n chapter_files_ref="$1"
    local max_chapters="$2"

    chapter_files_ref=()

    if [[ ! -d "01-Manuscrit" ]]; then
        log_error "Répertoire 01-Manuscrit/ introuvable"
        return 1
    fi

    # Logique de sélection identique à publish.sh
    if [[ "$max_chapters" == "99" ]]; then
        # Tous les chapitres
        while IFS= read -r -d '' file; do
            chapter_files_ref+=("$file")
        done < <(find "01-Manuscrit" -name "Ch*.md" -print0 | sort -z)

    elif [[ "$max_chapters" == *","* ]]; then
        # Liste spécifique: 1,5,10
        IFS=',' read -ra chapter_list <<< "$max_chapters"
        for chapter in "${chapter_list[@]}"; do
            chapter=$(echo "$chapter" | xargs) # trim whitespace
            local chapter_file=$(find "01-Manuscrit" -name "Ch$(printf "%02d" "$chapter")*.md" -o -name "Ch$chapter-*.md" | head -1)
            if [[ -f "$chapter_file" ]]; then
                chapter_files_ref+=("$chapter_file")
            fi
        done

    elif [[ "$max_chapters" == *"-"* ]]; then
        # Range: 5-10
        local start_ch=$(echo "$max_chapters" | cut -d'-' -f1)
        local end_ch=$(echo "$max_chapters" | cut -d'-' -f2)

        for ((i=start_ch; i<=end_ch; i++)); do
            local chapter_file=$(find "01-Manuscrit" -name "Ch$(printf "%02d" "$i")*.md" -o -name "Ch$i-*.md" | head -1)
            if [[ -f "$chapter_file" ]]; then
                chapter_files_ref+=("$chapter_file")
            fi
        done

    else
        # Nombre simple: premiers N chapitres
        local count=0
        while IFS= read -r -d '' file && [[ $count -lt $max_chapters ]]; do
            chapter_files_ref+=("$file")
            ((count++))
        done < <(find "01-Manuscrit" -name "Ch*.md" -print0 | sort -z)
    fi
}

# === EXTRACTION NUMÉRO CHAPITRE ===
extract_chapter_number() {
    local filename="$1"
    local basename=$(basename "$filename" .md)

    if [[ "$basename" =~ Ch([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "1"
    fi
}

# === EXTRACTION TITRE CHAPITRE ===
extract_chapter_title() {
    local file="$1"

    # Chercher première ligne commençant par #
    local title=$(grep "^# " "$file" | head -1 | sed 's/^# //')

    if [[ -n "$title" ]]; then
        echo "$title"
    else
        local basename=$(basename "$file" .md)
        echo "$basename"
    fi
}

# === FONCTION DÉTECTION CUSTOM STRUCTURE ===
detect_custom_structure() {
    local format="$1"
    local format_config="lib/templates/formats/$format.yaml"

    if [[ -f "$format_config" ]]; then
        if grep -q "^custom_structure:[[:space:]]*true" "$format_config"; then
            echo "true"
            return 0
        fi
    fi
    echo "false"
}
CUSTOM_HTML_EOF

chmod +x "lib/commands/custom_html.sh"
echo "✅ Module custom_html.sh installé"

# === INSTALLATION FORMAT YAML ===
echo
echo "📦 Installation format html-custom.yaml..."

cat > "lib/templates/formats/html-custom.yaml" << 'YAML_EOF'
# Format HTML Custom pour SILK - Structure sémantique complète
output_type: html
custom_structure: true

# Désactiver Pandoc pour ce format
standalone: false
self-contained: false

# Métadonnées HTML
lang: fr-FR
title-prefix: "SILK"

# CSS pour structure sémantique optimisée
css: |
  /* === RESET ET BASE === */
  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }

  html {
    font-size: 18px;
    scroll-behavior: smooth;
  }

  body {
    font-family: Georgia, "Minion Pro", "Times New Roman", serif;
    line-height: 1.6;
    color: #2c2c2c;
    background: #fefefe;
    text-align: justify;
    hyphens: auto;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }

  /* === CONTENEUR PRINCIPAL === */
  .silk-manuscript {
    max-width: 800px;
    margin: 0 auto;
    padding: 2rem;
  }

  /* === HEADER === */
  header {
    text-align: center;
    margin-bottom: 4rem;
    padding-bottom: 2rem;
    border-bottom: 2px solid #e0e0e0;
  }

  .main-title {
    font-size: 2.5em;
    font-weight: 300;
    color: #1a1a1a;
    margin-bottom: 0.5rem;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  }

  .author {
    font-size: 1.2em;
    color: #666;
    font-style: italic;
    font-weight: normal;
  }

  /* === CHAPITRES === */
  .chapter {
    margin-bottom: 4rem;
    position: relative;
  }

  .chapter:not(:last-child) {
    border-bottom: 1px solid #e0e0e0;
    padding-bottom: 3rem;
  }

  .chapter h2 {
    font-size: 1.8em;
    color: #1a1a1a;
    text-align: center;
    margin-bottom: 2.5rem;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    font-weight: 600;
    position: relative;
    padding-bottom: 1rem;
  }

  .chapter h2::after {
    content: '';
    position: absolute;
    bottom: 0;
    left: 50%;
    transform: translateX(-50%);
    width: 60px;
    height: 3px;
    background: linear-gradient(90deg, transparent 0%, #ccc 50%, transparent 100%);
    border-radius: 2px;
  }

  /* === BLOCS NARRATIFS === */
  .narrative-block {
    margin-bottom: 2.5rem;
    position: relative;
  }

  .narrative-block:not(:last-child) {
    padding-bottom: 1.5rem;
  }

  .narrative-block:not(:last-child)::after {
    content: '';
    position: absolute;
    bottom: 0;
    left: 50%;
    transform: translateX(-50%);
    width: 30%;
    height: 1px;
    background: linear-gradient(90deg, transparent 0%, #ddd 50%, transparent 100%);
  }

  /* === PARAGRAPHES === */
  .narrative-block p {
    margin-bottom: 1rem;
    text-indent: 1.5em;
    orphans: 3;
    widows: 3;
    text-align: justify;
  }

  .narrative-block p:first-child {
    text-indent: 0;
    margin-top: 0;
  }

  .narrative-block p:last-child {
    margin-bottom: 0;
  }

  /* === DIALOGUES === */
  .dialogue {
    text-indent: 0 !important;
    margin-left: 1rem;
    font-style: italic;
    position: relative;
    padding-left: 1rem;
  }

  .dialogue::before {
    content: '—';
    position: absolute;
    left: -0.5rem;
    color: #666;
    font-weight: bold;
  }

  /* === INDICATIONS TEMPORELLES === */
  .time-location {
    text-align: center;
    font-style: italic;
    color: #666;
    margin: 2rem 0;
    font-size: 0.95em;
    text-indent: 0;
    position: relative;
    padding: 1rem 0;
  }

  .time-location::before,
  .time-location::after {
    content: '※';
    position: absolute;
    top: 50%;
    transform: translateY(-50%);
    color: #ccc;
    font-size: 0.8em;
  }

  .time-location::before {
    left: 20%;
  }

  .time-location::after {
    right: 20%;
  }

  /* === BLANCS TYPOGRAPHIQUES === */
  .blank-space {
    height: 3rem;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 2rem 0;
    position: relative;
  }

  .blank-space::after {
    content: '⁂';
    color: #999;
    font-size: 1.5em;
    text-shadow: 0 1px 2px rgba(0,0,0,0.1);
  }

  /* === RESPONSIVE === */
  @media (max-width: 768px) {
    html {
      font-size: 16px;
    }

    .silk-manuscript {
      padding: 1rem;
    }

    .main-title {
      font-size: 2em;
    }

    .chapter h2 {
      font-size: 1.5em;
      margin-bottom: 2rem;
    }

    .narrative-block {
      margin-bottom: 2rem;
    }

    .narrative-block p {
      text-indent: 1em;
    }

    .dialogue {
      margin-left: 0.5rem;
      padding-left: 0.5rem;
    }
  }

  /* === MODE SOMBRE === */
  @media (prefers-color-scheme: dark) {
    body {
      background: #1a1a1a;
      color: #e0e0e0;
    }

    header {
      border-bottom-color: #444;
    }

    .main-title {
      color: #f0f0f0;
    }

    .author {
      color: #ccc;
    }

    .chapter {
      border-bottom-color: #444;
    }

    .chapter h2 {
      color: #f0f0f0;
    }

    .chapter h2::after {
      background: linear-gradient(90deg, transparent 0%, #666 50%, transparent 100%);
    }

    .narrative-block:not(:last-child)::after {
      background: linear-gradient(90deg, transparent 0%, #555 50%, transparent 100%);
    }

    .time-location {
      color: #aaa;
    }

    .time-location::before,
    .time-location::after {
      color: #666;
    }

    .blank-space::after {
      color: #666;
      text-shadow: 0 1px 2px rgba(255,255,255,0.1);
    }

    .dialogue::before {
      color: #999;
    }
  }

# Variables de template
variables:
  documentclass: article
  geometry: margin=1in
  fontsize: 18pt
  mainfont: Georgia

# Options de génération
table-of-contents: true
toc-depth: 2
number-sections: false

# Métadonnées personnalisables
title: "{{TITLE}}"
author: "{{AUTHOR}}"
date: "{{DATE}}"
subject: "Manuscrit SILK - Structure Sémantique"
keywords: ["fiction", "roman", "SILK", "HTML", "sémantique"]
description: "Manuscrit avec structure HTML sémantique généré par SILK"
YAML_EOF

echo "✅ Format html-custom.yaml installé"

# === PATCH PUBLISH.SH ===
echo
echo "🔧 Application du patch dans publish.sh..."

# Vérifier si patch déjà appliqué
if grep -q "detect_custom_structure" "lib/commands/publish.sh"; then
    echo "⚠️  Patch déjà appliqué dans publish.sh"
else
    # Créer fichier temporaire avec le patch
    cp "lib/commands/publish.sh" "lib/commands/publish.sh.tmp"

    # Injecter la fonction detect_custom_structure avant la dernière ligne
    sed -i '$i\
# === FONCTION DÉTECTION CUSTOM STRUCTURE ===\
detect_custom_structure() {\
    local format="$1"\
    local format_config="lib/templates/formats/$format.yaml"\
    \
    if [[ -f "$format_config" ]]; then\
        if grep -q "^custom_structure:[[:space:]]*true" "$format_config"; then\
            echo "true"\
            return 0\
        fi\
    fi\
    echo "false"\
}\
' "lib/commands/publish.sh.tmp"

    # Injecter l'appel dans generate_silk_output après detect_output_format
    sed -i '/local output_type=$(detect_output_format "$format")/a\
\
    # Détecter si génération HTML custom demandée\
    if [[ "$output_type" == "html" ]] && [[ "$(detect_custom_structure "$format")" == "true" ]]; then\
        log_debug "🕸️ Structure HTML custom détectée pour format: $format"\
        \
        # Sourcer les fonctions custom HTML si pas déjà fait\
        if ! declare -f generate_custom_html > /dev/null; then\
            if [[ -f "lib/commands/custom_html.sh" ]]; then\
                source "lib/commands/custom_html.sh"\
            else\
                log_error "Fichier lib/commands/custom_html.sh introuvable"\
                return 1\
            fi\
        fi\
        \
        # Appeler générateur custom\
        generate_custom_html "$format" "$max_chapters" "$french_quotes" "$auto_dashes" "$output_name" "$include_toc" "$include_stats" "$embeddable"\
        return $?\
    fi' "lib/commands/publish.sh.tmp"

    # Remplacer le fichier original
    mv "lib/commands/publish.sh.tmp" "lib/commands/publish.sh"

    echo "✅ Patch appliqué dans publish.sh"
fi

# === MISE À JOUR HELP ===
echo
echo "📝 Mise à jour de l'aide..."

# Ajouter html-custom dans l'aide si pas déjà fait
if ! grep -q "html-custom" "lib/commands/publish.sh"; then
    sed -i '/html       Format HTML brut/a\
  html-custom  Format HTML avec structure sémantique (sections/articles)' "lib/commands/publish.sh"

    sed -i '/silk publish -f html --embeddable      # Fragment HTML pour intégration/a\
  silk publish -f html-custom --embeddable  # HTML sémantique embeddable' "lib/commands/publish.sh"

    echo "✅ Aide mise à jour"
else
    echo "⚠️  Aide déjà mise à jour"
fi

# === INSTALLATION SCRIPT DE TEST ===
echo
echo "🧪 Installation script de test..."

mkdir -p tests

cat > "tests/test-custom-html.sh" << 'TEST_EOF'
#!/bin/bash
# tests/test-custom-html.sh - Tests pour génération HTML custom

source "lib/core/utils.sh" 2>/dev/null || {
    echo "❌ Framework SILK requis"
    exit 1
}

echo "🕸️ Tests génération HTML custom SILK"
echo "===================================="

# Test basique
echo
echo "📋 Test 1: Détection custom_structure"

if [[ "$(detect_custom_structure "html-custom")" == "true" ]]; then
    echo "✅ Détection format html-custom"
else
    echo "❌ Détection échoue"
fi

echo
echo "🎯 Pour test complet:"
echo "  1. Créer projet SILK: silk init \"Test HTML\""
echo "  2. Ajouter du contenu dans 01-Manuscrit/"
echo "  3. Tester: silk publish -f html-custom"
echo "  4. Vérifier: ls outputs/publish/*.html"
TEST_EOF

chmod +x "tests/test-custom-html.sh"
echo "✅ Script de test installé"

# === VALIDATION INSTALLATION ===
echo
echo "🔍 Validation de l'installation..."

errors=0

# Vérifier fichiers installés
required_files=(
    "lib/commands/custom_html.sh"
    "lib/templates/formats/html-custom.yaml"
    "tests/test-custom-html.sh"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ $file"
    else
        echo "❌ $file manquant"
        ((errors++))
    fi
done

# Vérifier patch appliqué
if grep -q "detect_custom_structure" "lib/commands/publish.sh"; then
    echo "✅ Patch publish.sh appliqué"
else
    echo "❌ Patch publish.sh manquant"
    ((errors++))
fi

# Vérifier chargement module
if source "lib/commands/custom_html.sh" 2>/dev/null; then
    if declare -f generate_custom_html > /dev/null; then
        echo "✅ Module custom_html.sh fonctionnel"
    else
        echo "❌ Fonction generate_custom_html manquante"
        ((errors++))
    fi
else
    echo "❌ Module custom_html.sh non chargeable"
    ((errors++))
fi

# === RÉSULTAT FINAL ===
echo
echo "🏁 RÉSULTAT INSTALLATION"
echo "========================"

if [[ $errors -eq 0 ]]; then
    echo "✅ Installation réussie !"
    echo
    echo "🎯 PROCHAINES ÉTAPES:"
    echo "1. Tester la fonctionnalité:"
    echo "   ./tests/test-custom-html.sh"
    echo
    echo "2. Dans un projet SILK existant:"
    echo "   silk publish -f html-custom"
    echo "   silk publish -f html-custom --embeddable"
    echo "   silk publish -f html-custom -ch 1-5"
    echo
    echo "3. Vérifier le résultat:"
    echo "   open outputs/publish/*.html"
    echo
    echo "📚 Documentation complète disponible dans les artefacts"
    echo "🕸️ SILK HTML custom opérationnel !"

else
    echo "❌ $errors erreur(s) détectée(s)"
    echo
    echo "🔧 DÉPANNAGE:"
    echo "1. Vérifier permissions: chmod +x lib/commands/custom_html.sh"
    echo "2. Vérifier structure SILK complète"
    echo "3. Relancer l'installation si nécessaire"
    echo
    echo "📧 Sauvegarde disponible: $backup_dir/"
fi

echo
echo "🕸️ Installation HTML Custom SILK terminée"

exit $errors
