#!/bin/bash
# lib/commands/publish.sh - Commande SILK publish

# Vérification chargement des dépendances
if [[ "${SILK_CORE_UTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/utils requis" >&2
    exit 1
fi

if [[ "${SILK_CORE_VAULT_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/vault requis" >&2
    exit 1
fi

# === FONCTION PRINCIPALE ===
cmd_publish() {
    ensure_silk_context
    
    local format="${SILK_DEFAULT_FORMAT:-digital}"
    local max_chapters=99
    local french_quotes=false
    local auto_dashes=false
    local output_name=""
    local formats_dir="formats"
    
    # Si formats/ existe à la racine, l'utiliser
    if [[ -d "../formats" ]]; then
        formats_dir="../formats"
    elif [[ -d "../../formats" ]]; then
        formats_dir="../../formats"
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_publish_help
                return 0
                ;;
            -f|--format)
                format="$2"
                shift 2
                ;;
            -ch|--chapters)
                max_chapters="$2"
                shift 2
                ;;
            -o|--output)
                output_name="$2"
                shift 2
                ;;
            --french-quotes)
                french_quotes=true
                shift
                ;;
            --auto-dashes)
                auto_dashes=true
                shift
                ;;
            --formats-dir)
                formats_dir="$2"
                shift 2
                ;;
            -*)
                log_error "Option inconnue: $1"
                return 1
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Vérifier dépendances
    if ! check_publish_dependencies; then
        return 1
    fi
    
    log_info "🕸️ SILK tisse votre PDF (format: $format, chapitres: $max_chapters)"
    
    generate_silk_pdf "$format" "$max_chapters" "$french_quotes" "$auto_dashes" "$output_name" "$formats_dir"
}

# === AIDE PUBLISH ===
show_publish_help() {
    cat << 'HELP'
📖 SILK PUBLISH - Génération PDF manuscrit professionnel

USAGE:
  silk publish [OPTIONS]

OPTIONS:
  -f, --format FORMAT       Format de sortie
  -ch, --chapters NUMBER    Limiter aux N premiers chapitres
  -o, --output NAME         Nom fichier de sortie personnalisé
  --french-quotes           Utiliser guillemets français « »
  --auto-dashes             Ajouter tirets cadratins aux dialogues
  --formats-dir DIR         Répertoire des formats (défaut: formats)
  -h, --help                Afficher cette aide

EXEMPLES:
  silk publish                           # Format par défaut
  silk publish -f iphone -ch 10          # Format iPhone, 10 chapitres
  silk publish --french-quotes           # Guillemets français
  silk publish -f book --auto-dashes     # Format livre avec tirets

FORMATS SILK DISPONIBLES:
  digital    Format écran (6"×9", marges 0.5") - lecture confortable
  iphone     Format mobile (4.7"×8.3", marges 0.3") - smartphone
  kindle     Format liseuse (5"×7.5", optimisé e-ink) - Kindle/Kobo
  book       Format livre papier (A5, marges optimisées) - impression

CONVENTIONS MANUSCRIT SILK:
  ~          → Blanc typographique (pause narrative)
  ---        → Transition de scène (*** centrés)
  *texte*    → Indications temporelles/lieu (italique centré)
  [[liens]]  → Liens Obsidian (convertis automatiquement)

DÉPENDANCES:
  - Pandoc (https://pandoc.org/installing.html)
  - XeLaTeX (https://www.latex-project.org/get/)

SILK weaves your manuscript into beautiful PDF.
HELP
}

# === GÉNÉRATION PDF ===
generate_silk_pdf() {
    local format="$1"
    local max_chapters="$2"
    local french_quotes="$3"
    local auto_dashes="$4"
    local output_name="$5"
    local formats_dir="$6"
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local project_name=$(basename "$PWD")
    local filename=""
    
    if [[ -n "$output_name" ]]; then
        filename="$output_name"
        # Ajouter .pdf si pas déjà présent
        if [[ "$filename" != *.pdf ]]; then
            filename="$filename.pdf"
        fi
    else
        filename="${project_name}-SILK-${format}-${timestamp}.pdf"
        if [[ $max_chapters -ne 99 ]]; then
            filename="${project_name}-SILK-${format}-Ch${max_chapters}-${timestamp}.pdf"
        fi
    fi
    
    # Vérifier template de format
    if [[ ! -f "$formats_dir/$format.yaml" ]]; then
        log_error "Format '$format' non trouvé dans $formats_dir/"
        echo "💡 Formats SILK disponibles:"
        if [[ -d "$formats_dir" ]]; then
            ls "$formats_dir"/*.yaml 2>/dev/null | sed 's/.*\///;s/\.yaml$//' | grep -v base | sed 's/^/   /' || echo "   Aucun format configuré"
        else
            echo "   Répertoire formats non trouvé: $formats_dir"
        fi
        return 1
    fi
    
    ensure_directory "outputs/publish"
    ensure_directory "outputs/temp"
    
    # Fusionner métadonnées base + format
    local merged_metadata="outputs/temp/silk_merged_${format}.yaml"
    {
        echo "---"
        if [[ -f "$formats_dir/base.yaml" ]]; then
            cat "$formats_dir/base.yaml"
        else
            log_warning "base.yaml non trouvé, utilisation métadonnées minimales"
            echo "title: \"$project_name\""
            echo "author: \"${SILK_AUTHOR_NAME:-Auteur}\""
            echo "date: \"$(date '+%Y-%m-%d')\""
        fi
        echo ""
        cat "$formats_dir/$format.yaml"
        echo "---"
    } > "$merged_metadata"
    
    # Collecter et nettoyer chapitres
    collect_and_clean_chapters "$max_chapters" "$french_quotes" "$auto_dashes"
    local chapters_included=$?
    
    if [[ $chapters_included -eq 0 ]]; then
        log_error "Aucun chapitre trouvé à publier"
        return 1
    fi
    
    # Générer PDF avec Pandoc
    local output_pdf="outputs/publish/$filename"
    
    log_info "🎯 Génération PDF avec Pandoc..."
    local clean_files=(outputs/temp/silk_clean_*.md)
    
    if pandoc "$merged_metadata" "${clean_files[@]}" \
        -o "$output_pdf" \
        --pdf-engine=xelatex \
        -f markdown+smart \
        --toc \
        --toc-depth=1 \
        -V geometry:margin=1in \
        --highlight-style=tango 2>/dev/null; then
        
        show_publish_success "$output_pdf" "$filename" "$format" "$chapters_included" "$french_quotes" "$auto_dashes"
        
    else
        log_error "Erreur lors de la génération PDF"
        echo "💡 Vérifiez que XeLaTeX et les polices sont correctement installées"
        return 1
    fi
}

# === COLLECTE ET NETTOYAGE CHAPITRES ===
collect_and_clean_chapters() {
    local max_chapters="$1"
    local french_quotes="$2"
    local auto_dashes="$3"
    
    local chapters_included=0
    
    echo "🕷️ Tissage des chapitres:"
    for file in 01-Manuscrit/Ch*.md; do
        if [[ -f "$file" ]]; then
            local chapter_num=$(extract_chapter_number "$file")
            
            if [[ -n "$chapter_num" && $chapter_num -le $max_chapters ]]; then
                local clean_file="outputs/temp/silk_clean_$(basename "$file")"
                clean_chapter_file "$file" "$clean_file" "$french_quotes" "$auto_dashes" "$chapter_num"
                ((chapters_included++))
                echo "   ✅ Ch$chapter_num tissé"
            fi
        fi
    done
    
    return $chapters_included
}

# === NETTOYAGE CHAPITRE ===
clean_chapter_file() {
    local input="$1"
    local output="$2"
    local french_quotes="$3"
    local auto_dashes="$4"
    local chapter_num="$5"
    
    # Titre de chapitre avec saut de page (sauf premier)
    if [[ $chapter_num -gt 1 ]]; then
        echo "\\newpage" > "$output"
        echo "" >> "$output"
    else
        echo "" > "$output"
    fi
    
    # Extraire titre et le formater
    local chapter_title=$(head -n1 "$input" | sed 's/^#*\s*//')
    echo "# $chapter_title" >> "$output"
    echo "" >> "$output"
    
    # Extraire et traiter contenu après "## manuscrit"
    local found_marker=false
    while IFS= read -r line; do
        if [[ "$line" == *"$VAULT_MARKER"* ]]; then
            found_marker=true
            continue
        fi
        
        if [[ "$found_marker" == true ]]; then
            process_manuscript_line "$line" "$output" "$french_quotes" "$auto_dashes"
        fi
    done < "$input"
}

# === TRAITEMENT LIGNE MANUSCRIT ===
process_manuscript_line() {
    local line="$1"
    local output="$2"
    local french_quotes="$3"
    local auto_dashes="$4"
    
    # Traitement des séparateurs spéciaux SILK
    if [[ "$line" == "---" ]]; then
        # Transition de scène
        echo "" >> "$output"
        echo "\\begin{center}" >> "$output"
        echo "\\vspace{1cm}" >> "$output"
        echo "***" >> "$output"
        echo "\\vspace{1cm}" >> "$output"
        echo "\\end{center}" >> "$output"
        echo "" >> "$output"
    elif [[ "$line" == "~" ]]; then
        # Blanc typographique
        echo "" >> "$output"
        echo "\\vspace{0.5cm}" >> "$output"
        echo "" >> "$output"
    elif [[ "$line" =~ ^\*.*\*$ ]] && [[ "$line" =~ \- ]]; then
        # Indications temporelles (*Lundi matin - Commissariat*)
        echo "" >> "$output"
        echo "\\begin{center}" >> "$output"
        echo "\\textit{${line:1:-1}}" >> "$output"
        echo "\\end{center}" >> "$output"
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
            # Remplacer — par vrai tiret cadratin LaTeX
            processed_line=$(echo "$processed_line" | sed 's/—/---/g')
            # Ajouter tirets aux dialogues qui commencent par -
            processed_line=$(echo "$processed_line" | sed 's/^- /--- /g')
        fi