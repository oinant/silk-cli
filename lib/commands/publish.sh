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

# === CONSTANTES MODULE ===
readonly PUBLISH_OUTPUT_DIR="outputs/publish"
readonly PUBLISH_TEMP_DIR="outputs/temp"

# === FONCTION PRINCIPALE ===
cmd_publish() {
    ensure_silk_context

    local format="${SILK_DEFAULT_FORMAT:-digital}"
    local max_chapters=99
    local output_name=""
    local french_quotes=false
    local auto_dashes=false
    local include_toc=true
    local include_stats=false
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_publish_help
                return 0
                ;;
            -f|--format)
                if [[ $# -lt 2 ]]; then
                    log_error "Option -f/--format nécessite un argument"
                    return 1
                fi
                format="$2"
                shift 2
                ;;
            -ch|--chapters)
                if [[ $# -lt 2 ]]; then
                    log_error "Option -ch/--chapters nécessite un argument"
                    return 1
                fi
                max_chapters="$2"
                shift 2
                ;;
            -o|--output)
                if [[ $# -lt 2 ]]; then
                    log_error "Option -o/--output nécessite un argument"
                    return 1
                fi
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
            --no-toc)
                include_toc=false
                shift
                ;;
            --with-stats)
                include_stats=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            -*)
                log_error "Option inconnue: $1"
                show_publish_help
                return 1
                ;;
            *)
                # Si c'est un nombre, traiter comme max_chapters
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    max_chapters="$1"
                fi
                shift
                ;;
        esac
    done

    # Vérifier que le format existe
    if ! validate_format "$format"; then
        return 1
    fi

    # Vérifier dépendances sauf en dry-run
    if [[ "$dry_run" == "false" ]] && ! check_publish_dependencies "$format"; then
        show_dependency_help
        return 1
    fi

    log_info "🕸️ SILK tisse votre PDF (format: $format, chapitres: $max_chapters)"

    if [[ "$dry_run" == "true" ]]; then
        dry_run_publish "$format" "$max_chapters" "$output_name"
    else
        generate_silk_output "$format" "$max_chapters" "$french_quotes" "$auto_dashes" "$output_name" "$include_toc" "$include_stats"
    fi
}

# === AIDE PUBLISH ===
show_publish_help() {
    cat << 'HELP'
📖 SILK PUBLISH - Génération PDF manuscrit professionnel

USAGE:
  silk publish [OPTIONS]

OPTIONS:
  -f, --format FORMAT       Format de sortie (digital, iphone, kindle, book)
  -ch, --chapters NUMBER    Limiter aux N premiers chapitres
  -o, --output NAME         Nom fichier de sortie personnalisé
  --french-quotes           Utiliser guillemets français « »
  --auto-dashes             Ajouter tirets cadratins aux dialogues
  --no-toc                  Ne pas inclure table des matières
  --with-stats              Inclure page de statistiques
  --dry-run                 Simulation sans génération PDF
  -h, --help                Afficher cette aide

EXEMPLES:
  silk publish                           # Format par défaut
  silk publish -f iphone -ch 10          # Format iPhone, 10 chapitres
  silk publish --french-quotes           # Guillemets français
  silk publish -f book --auto-dashes     # Format livre avec tirets
  silk publish --dry-run                 # Test sans génération

FORMATS SILK DISPONIBLES:
  digital    Format écran (6"×9", marges 0.5") - lecture confortable
  iphone     Format mobile (4.7"×8.3", marges 0.3") - smartphone
  kindle     Format liseuse (5"×7.5", optimisé e-ink) - Kindle/Kobo
  book       Format livre papier (A5, marges optimisées) - impression
  epub       Format EPUB mobile (reflowable, sans LaTeX requis)

CONVENTIONS MANUSCRIT SILK:
  ~          → Blanc typographique (pause narrative)
  ---        → Transition de scène (*** centrés)
  *texte*    → Indications temporelles/lieu (italique centré)
  [[liens]]  → Liens Obsidian (convertis automatiquement)

DÉPENDANCES REQUISES:
  - Pandoc (https://pandoc.org/installing.html)
  - XeLaTeX (https://www.latex-project.org/get/)

EPUB AVANTAGES:
  ✅ Pas de LaTeX nécessaire
  ✅ Texte adaptable à l'écran
  ✅ Support natif mode sombre
  ✅ Recherche et marque-pages intégrés

SILK weaves your manuscript into beautiful PDF.
HELP
}

# === VALIDATION FORMAT ===
validate_format() {
    local format="$1"

    # Vérifier que le template existe
    if [[ ! -f "formats/$format.yaml" ]]; then
        log_error "Format '$format' non trouvé"
        echo
        echo "💡 Formats SILK disponibles:"
        if [[ -d "formats" ]]; then
            find formats -name "*.yaml" -not -name "base.yaml" -exec basename {} .yaml \; 2>/dev/null | sort | sed 's/^/   /' || echo "   Aucun format configuré"
        else
            echo "   Répertoire formats/ manquant - projet SILK incomplet"
            return 1
        fi
        return 1
    fi

    return 0
}

detect_output_format() {
    local format="$1"
    local format_config="formats/$format.yaml"

    # Lire le type de sortie depuis le YAML
    if [[ -f "$format_config" ]]; then
        local output_type=$(grep "^output_type:" "$format_config" | cut -d: -f2 | xargs)
        echo "${output_type:-pdf}"  # PDF par défaut
    else
        echo "pdf"
    fi
}

# 2. FONCTION check_dependencies() - MODIFIÉE
check_publish_dependencies() {
    local format="$1"
    local output_type=$(detect_output_format "$format")
    local missing=0

    if ! command -v pandoc &> /dev/null; then
        log_error "Pandoc requis mais non trouvé"
        ((missing++))
    else
        log_debug "Pandoc trouvé: $(pandoc --version | head -1)"
    fi

    # XeLaTeX seulement pour PDF
    if [[ "$output_type" == "pdf" ]] && ! command -v xelatex &> /dev/null; then
        log_error "XeLaTeX requis pour génération PDF"
        ((missing++))
    else
        log_debug "XeLaTeX trouvé: $(xelatex --version | head -1)"
    fi

    return $missing
}

show_dependency_help() {
    echo
    echo "🔧 INSTALLATION DÉPENDANCES:"
    echo
    case "$(detect_os)" in
        "linux")
            echo "Ubuntu/Debian:"
            echo "  sudo apt update"
            echo "  sudo apt install pandoc texlive-xelatex texlive-fonts-recommended"
            echo
            echo "Arch Linux:"
            echo "  sudo pacman -S pandoc texlive-core texlive-bin"
            ;;
        "macos")
            echo "macOS (avec Homebrew):"
            echo "  brew install pandoc"
            echo "  brew install --cask mactex"
            echo
            echo "Ou télécharger MacTeX: https://www.tug.org/mactex/"
            ;;
        "windows")
            echo "Windows:"
            echo "  1. Installer Pandoc: https://pandoc.org/installing.html"
            echo "  2. Installer MiKTeX: https://miktex.org/download"
            echo "  3. Redémarrer Git Bash après installation"
            ;;
    esac
    echo
    echo "💡 Test installation: silk publish --dry-run"
}

# === DRY RUN ===
dry_run_publish() {
    local format="$1"
    local max_chapters="$2"
    local output_name="$3"

    echo
    echo "🔍 SIMULATION PUBLICATION:"
    echo "========================="
    echo
    echo "📖 Format: $format"
    echo "📊 Chapitres: $max_chapters (max)"
    echo "📁 Output: ${output_name:-auto-généré}"
    echo

    # Analyser contenu disponible
    local available_chapters=0
    local total_words=0

    for file in 01-Manuscrit/Ch*.md; do
        if [[ -f "$file" ]] && grep -q "## manuscrit" "$file"; then
            local chapter_num=$(extract_chapter_number "$file")
            if [[ -n "$chapter_num" && "$chapter_num" -le "$max_chapters" ]]; then
                ((available_chapters++))
                local words=$(sed -n '/## manuscrit/,$p' "$file" | tail -n +2 | wc -w)
                total_words=$((total_words + words))
                echo "   ✅ Ch$chapter_num: $words mots - $(head -1 "$file" | sed 's/^#*\s*//')"
            fi
        fi
    done

    echo
    echo "📊 RÉSUMÉ:"
    echo "   Chapitres inclus: $available_chapters"
    echo "   Total mots: $total_words"
    echo "   Pages estimées: $((total_words / 250))"
    echo
    echo "📄 Template format: formats/$format.yaml"
    if [[ -f "formats/base.yaml" ]]; then
        echo "   ✅ Base template trouvé"
    else
        echo "   ⚠️  Base template manquant"
    fi
    echo
    echo "🎯 Commande réelle: silk publish -f $format -ch $max_chapters"
    echo "🕸️ SILK simulation terminée - prêt pour génération PDF"
}


# === NETTOYAGE INTELLIGENT TEMP ===
# === NETTOYAGE INTELLIGENT TEMP AVEC FIX ROBUSTE ===
cleanup_temp_directory() {
    local temp_dir="$1"
    local keep_recent_hours="${2:-24}"

    log_debug "🧹 Nettoyage dossier temporaire: $temp_dir"

    if [[ ! -d "$temp_dir" ]]; then
        return 0
    fi

    # CRITIQUE: Désactiver errexit temporairement pour éviter crash
    set +e

    # Compter fichiers avant
    local files_before=$(find "$temp_dir" -type f 2>/dev/null | wc -l)

    if [[ $files_before -eq 0 ]]; then
        log_debug "   📁 Dossier temp déjà vide"
        set -e  # Réactiver errexit
        return 0
    fi

    log_debug "   📊 $files_before fichiers détectés"

    # Nettoyage par âge (fichiers > 24h)
    local deleted_old=0
    if command -v find &> /dev/null; then
        local old_files
        old_files=$(find "$temp_dir" -type f -name "silk_*" -mtime +0 2>/dev/null)
        if [[ -n "$old_files" ]]; then
            while IFS= read -r old_file; do
                if [[ -f "$old_file" ]]; then
                    rm -f "$old_file" 2>/dev/null && ((deleted_old++))
                fi
            done <<< "$old_files"
        fi
    fi

    # Nettoyage par pattern (méthode simple et robuste)
    local deleted_pattern=0
    for pattern in "clean_Ch*.md" "merged_metadata_*.yaml" "temp_*.yaml"; do
        for file in "$temp_dir"/$pattern; do
            if [[ -f "$file" ]]; then
                rm -f "$file" 2>/dev/null && ((deleted_pattern++))
            fi
        done
    done

    # Nettoyage par limite (garder 10 plus récents par type)
    local deleted_excess=0

    # Méthode SIMPLE et ROBUSTE pour silk_clean_*
    local clean_files=("$temp_dir"/silk_clean_*)
    if [[ ${#clean_files[@]} -gt 10 ]]; then
        # Trier par date de modification (plus ancien en premier)
        local sorted_clean_files
        sorted_clean_files=$(ls -t "$temp_dir"/silk_clean_* 2>/dev/null | tail -n +11)
        if [[ -n "$sorted_clean_files" ]]; then
            while IFS= read -r excess_file; do
                if [[ -f "$excess_file" ]]; then
                    rm -f "$excess_file" 2>/dev/null && ((deleted_excess++))
                fi
            done <<< "$sorted_clean_files"
        fi
    fi

    # Même chose pour silk_merged_*
    local merged_files=("$temp_dir"/silk_merged_*)
    if [[ ${#merged_files[@]} -gt 10 ]]; then
        local sorted_merged_files
        sorted_merged_files=$(ls -t "$temp_dir"/silk_merged_* 2>/dev/null | tail -n +11)
        if [[ -n "$sorted_merged_files" ]]; then
            while IFS= read -r excess_file; do
                if [[ -f "$excess_file" ]]; then
                    rm -f "$excess_file" 2>/dev/null && ((deleted_excess++))
                fi
            done <<< "$sorted_merged_files"
        fi
    fi

    # Recompter fichiers après
    local files_after=$(find "$temp_dir" -type f 2>/dev/null | wc -l)
    local total_deleted=$((deleted_old + deleted_pattern + deleted_excess))

    if [[ $total_deleted -gt 0 ]]; then
        log_debug "   🗑️  Supprimés: $total_deleted fichiers ($files_before → $files_after)"
        log_debug "      📅 Anciens: $deleted_old, 🏷️  Pattern: $deleted_pattern, 📊 Excès: $deleted_excess"
    else
        log_debug "   ✨ Aucun nettoyage nécessaire ($files_before fichiers)"
    fi

    # CRITIQUE: Réactiver errexit
    set -e
}

# === GÉNÉRATION OUTPUT UNIVERSEL (PDF/EPUB/HTML) ===
generate_silk_output() {
    local format="$1"
    local max_chapters="$2"
    local french_quotes="$3"
    local auto_dashes="$4"
    local output_name="$5"
    local include_toc="$6"
    local include_stats="$7"

    # Détecter le type de sortie depuis le YAML
    local output_type=$(detect_output_format "$format")
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local project_name=$(basename "$PWD")

    # Extension basée sur le type de sortie
    local extension
    case "$output_type" in
        "epub") extension="epub" ;;
        "html") extension="html" ;;
        *) extension="pdf" ;;
    esac

    # Nom de fichier
    local filename
    if [[ -n "$output_name" ]]; then
        filename="${output_name}.${extension}"
    else
        filename="${project_name}-${format}-${timestamp}.${extension}"
        if [[ $max_chapters -ne 99 ]]; then
            filename="${project_name}-${format}-Ch${max_chapters}-${timestamp}.${extension}"
        fi
    fi

    log_debug "Nom fichier généré: $filename (type: $output_type)"

    # Créer les répertoires nécessaires
    mkdir -p "$PUBLISH_OUTPUT_DIR" "$PUBLISH_TEMP_DIR"

    log_info "Préparation métadonnées de publication..."

    # Créer métadonnées fusionnées
    local merged_metadata="$PUBLISH_TEMP_DIR/silk_merged_${format}_${timestamp}.yaml"
    create_merged_metadata "$format" "$merged_metadata" "$project_name"
    log_debug "Métadonnées créées: $merged_metadata"

    log_info "Collecte et nettoyage des chapitres..."

    # Collecte des chapitres (même logique que votre version actuelle)
    declare -A chapter_parts_map
    local clean_files=()
    local chapters_included=0

    # Phase 1: Identifier et regrouper tous les fichiers par chapitre de base
    log_debug "🔍 Phase 1: Identification chapitres..."

    for file in 01-Manuscrit/Ch*.md; do
        if [[ -f "$file" ]] && grep -q "## manuscrit" "$file"; then
            # Extraction robuste du numéro de chapitre
            local file_basename=$(basename "$file")
            local chapter_num=""

            if [[ "$file_basename" =~ ^[Cc]h([0-9]+) ]]; then
                chapter_num="${BASH_REMATCH[1]}"
                chapter_num=$(echo "$chapter_num" | sed 's/^0*//')  # Supprimer zéros
            else
                chapter_num="0"
            fi

            if [[ -n "$chapter_num" && "$chapter_num" != "0" && $chapter_num -le $max_chapters ]]; then
                if [[ -z "${chapter_parts_map[$chapter_num]:-}" ]]; then
                    chapter_parts_map[$chapter_num]="$file"
                else
                    chapter_parts_map[$chapter_num]="${chapter_parts_map[$chapter_num]}|$file"
                fi
                log_debug "   ✅ Ch$chapter_num ajouté: $(basename "$file")"
            fi
        fi
    done

    # Phase 2: Traiter chaque chapitre avec toutes ses parties
    log_debug "🔍 Phase 2: Traitement et combinaison..."

    # Temporairement désactiver errexit
    set +e

    for chapter_num in $(printf '%s\n' "${!chapter_parts_map[@]}" | sort -n); do
        local parts_list="${chapter_parts_map[$chapter_num]}"
        IFS='|' read -ra files_array <<< "$parts_list"

        local chapter_title=""
        local combined_content=""
        local files_count=${#files_array[@]}

        log_debug "📚 Traitement Ch$chapter_num ($files_count partie(s))"

        # Combiner toutes les parties du chapitre
        for file in "${files_array[@]}"; do
            # Extraire titre
            if [[ -z "$chapter_title" ]] || [[ "$(basename "$file")" != *"-1-"* && "$(basename "$file")" != *"-2-"* ]]; then
                chapter_title=$(head -n1 "$file" | sed 's/^#*\s*//')
            fi

            # Extraire contenu après "## manuscrit"
            local part_content
            if part_content=$(extract_manuscript_content "$file"); then
                if [[ -n "$part_content" ]]; then
                    combined_content+="$part_content"
                    combined_content+=$'\n\n'
                fi
            fi
        done

        # Créer fichier combiné unique
        if [[ -n "$combined_content" ]]; then
            local clean_file="$PUBLISH_TEMP_DIR/silk_clean_ch${chapter_num}_${timestamp}.md"

            local display_title="$chapter_title"
            if [[ $files_count -gt 1 ]]; then
                display_title="$chapter_title (${files_count} parties)"
            fi

            # Créer le fichier nettoyé selon le type de sortie
            if create_clean_chapter_file "$clean_file" "$chapter_num" "$display_title" "$combined_content" "$french_quotes" "$auto_dashes" "$output_type"; then
                clean_files+=("$clean_file")
                ((chapters_included++))
                echo "   ✅ Ch$chapter_num préparé"
            fi
        fi
    done

    # Réactiver errexit
    set -e

    if [[ $chapters_included -eq 0 ]]; then
        log_error "Aucun chapitre trouvé à publier"
        return 1
    fi

    # Ajouter page statistiques si demandée
    if [[ "$include_stats" == "true" ]]; then
        local stats_file="$PUBLISH_TEMP_DIR/silk_stats_${timestamp}.md"
        create_stats_page "$stats_file" "$chapters_included" "$output_type"
        clean_files=("$stats_file" "${clean_files[@]}")
        log_debug "Page stats ajoutée: $stats_file"
    fi

    # Chemin de sortie final
    local output_file="$PUBLISH_OUTPUT_DIR/$filename"

    log_info "🎯 Génération $output_type avec Pandoc..."
    log_debug "Fichiers d'entrée: ${clean_files[*]}"
    log_debug "Métadonnées: $merged_metadata"
    log_debug "Sortie: $output_file"

    # Arguments Pandoc de base
    local pandoc_args=(
        "$merged_metadata"
        "${clean_files[@]}"
        "-o" "$output_file"
        "-f" "markdown+smart"
    )

    # Arguments spécifiques au type de sortie
    case "$output_type" in
        "pdf")
            pandoc_args+=(
                "--pdf-engine=xelatex"
                "--highlight-style=tango"
            )
            ;;
        "epub")
            pandoc_args+=(
                "--epub-chapter-level=2"
            )
            ;;
        "html")
            pandoc_args+=(
                "--standalone"
                "--self-contained"
            )
            ;;
    esac

    # Table des matières si demandée
    if [[ "$include_toc" == "true" ]]; then
        pandoc_args+=("--toc" "--toc-depth=1")
    fi

    log_debug "Commande Pandoc: pandoc ${pandoc_args[*]}"

    # Exécution Pandoc avec gestion d'erreur
    local pandoc_output
    echo "🔄 Exécution Pandoc..."

    if pandoc_output=$(pandoc "${pandoc_args[@]}" 2>&1); then
        log_debug "Pandoc terminé avec succès"

        if [[ -f "$output_file" ]]; then
            local duration=$(end_timer "$start_time")
            show_publish_success "$output_file" "$filename" "$format" "$chapters_included" "$duration" "$french_quotes" "$auto_dashes" "$output_type"

            # Nettoyage fichiers temporaires (sauf en debug)
            if [[ "${SILK_DEBUG:-false}" != "true" ]]; then
                log_debug "Nettoyage fichiers temporaires de cette session"
                rm -f "$merged_metadata" "${clean_files[@]}" 2>/dev/null || true
            else
                log_debug "Fichiers temporaires conservés pour debug dans: $PUBLISH_TEMP_DIR"
            fi
            return 0
        else
            log_error "Pandoc terminé mais le fichier n'a pas été créé"
            log_error "Fichier attendu: $output_file"
            return 1
        fi
    else
        local pandoc_exit_code=$?
        log_error "Erreur Pandoc (code: $pandoc_exit_code)"
        echo
        echo "📋 SORTIE PANDOC:"
        echo "$pandoc_output"
        echo
        echo "🔧 DEBUGGING:"
        echo "   1. Vérifiez les métadonnées: cat $merged_metadata"
        echo "   2. Test manuel:"
        if [[ ${#clean_files[@]} -gt 0 ]]; then
            echo "      pandoc $merged_metadata ${clean_files[0]} -o test.$extension"
        fi
        echo
        return 1
    fi
}

# === FONCTION UTILITAIRE POUR EXTRACTION CONTENU ===
extract_manuscript_content() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    # Extraire tout après "## manuscrit"
    sed -n '/## manuscrit/,$p' "$file" | tail -n +2
}

# === FONCTION CRÉATION FICHIER NETTOYÉ ADAPTÉE ===
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
        process_silk_line "$line" "$output_file" "$french_quotes" "$auto_dashes" "$output_type"
    done <<< "$content"

    log_debug "✅ Fichier nettoyé créé: $output_file"
    return 0
}

# === FONCTION TRAITEMENT LIGNE ADAPTÉE ===
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


# === COMMANDE DE NETTOYAGE MANUEL ===
cmd_cleanup_temp() {
    ensure_silk_context

    local temp_dir="${PUBLISH_TEMP_DIR:-outputs/temp}"
    local force=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                force=true
                shift
                ;;
            --help|-h)
                cat << 'HELP'
🧹 SILK CLEANUP - Nettoyage dossier temporaire

USAGE:
  silk cleanup [OPTIONS]

OPTIONS:
  --force, -f    Supprimer TOUS les fichiers temp (attention !)
  --help, -h     Afficher cette aide

EXEMPLES:
  silk cleanup         # Nettoyage intelligent (garde fichiers récents)
  silk cleanup --force # Suppression complète (⚠️  attention)

Le nettoyage intelligent garde les fichiers des dernières 24h
et limite à 10 fichiers par type pour éviter l'accumulation.
HELP
                return 0
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ "$force" == "true" ]]; then
        log_warning "🚨 Nettoyage COMPLET du dossier temporaire..."
        read -p "Êtes-vous sûr ? (oui/NON): " confirm
        case "$confirm" in
            "oui"|"OUI"|"yes"|"YES")
                if [[ -d "$temp_dir" ]]; then
                    rm -rf "$temp_dir"/*
                    log_success "Dossier temporaire vidé complètement"
                else
                    log_info "Dossier temporaire n'existe pas"
                fi
                ;;
            *)
                log_info "Nettoyage annulé"
                ;;
        esac
    else
        log_info "🧹 Nettoyage intelligent du dossier temporaire..."
        cleanup_temp_directory "$temp_dir"
        log_success "Nettoyage intelligent terminé"
    fi
}

# === MÉTADONNÉES ===
# === MODIFICATION DE create_merged_metadata() ===
create_merged_metadata() {
    local format="$1"
    local output_file="$2"
    local project_name="$3"

    # Détecter l'image de couverture
    local cover_image=""
    local cover_candidates=(
        "cover.jpg" "cover.png" "cover.jpeg"
        "couverture.jpg" "couverture.png"
        "Cover.jpg" "Cover.png"
        "assets/cover.jpg" "assets/cover.png"
        "images/cover.jpg" "images/cover.png"
    )

    for candidate in "${cover_candidates[@]}"; do
        if [[ -f "$candidate" ]]; then
            cover_image="$candidate"
            log_debug "🎨 Couverture trouvée: $cover_image"
            break
        fi
    done

    if [[ -z "$cover_image" ]]; then
        log_debug "📷 Aucune couverture trouvée (cherché: ${cover_candidates[*]})"
    fi

    {
        echo "---"

        # Base metadata avec substitutions
        if [[ -f "formats/base.yaml" ]]; then
            while IFS= read -r line; do
                # Substitutions des variables
                line=$(echo "$line" | sed "s/{{TITLE}}/$project_name/g")
                line=$(echo "$line" | sed "s/{{AUTHOR}}/${SILK_AUTHOR_NAME:-Auteur}/g")
                line=$(echo "$line" | sed "s/{{DATE}}/$(date '+%Y-%m-%d')/g")
                line=$(echo "$line" | sed "s|{{COVER_IMAGE}}|$cover_image|g")

                # Exclure header-includes pour éviter conflit
                if [[ ! "$line" =~ ^header-includes: ]] && [[ ! "$line" =~ ^[[:space:]]*- ]]; then
                    echo "$line"
                fi
            done < "formats/base.yaml"
        else
            # Fallback sans base.yaml
            echo "title: \"$project_name\""
            echo "author: \"${SILK_AUTHOR_NAME:-Auteur}\""
            echo "date: \"$(date '+%Y-%m-%d')\""
            echo "lang: fr-FR"
            if [[ -n "$cover_image" ]]; then
                echo "epub-cover-image: \"$cover_image\""
            fi
        fi

        echo ""

        # Format specific avec substitutions
        if [[ -f "formats/$format.yaml" ]]; then
            while IFS= read -r line; do
                line=$(echo "$line" | sed "s/{{TITLE}}/$project_name/g")
                line=$(echo "$line" | sed "s/{{AUTHOR}}/${SILK_AUTHOR_NAME:-Auteur}/g")
                line=$(echo "$line" | sed "s/{{DATE}}/$(date '+%Y-%m-%d')/g")
                line=$(echo "$line" | sed "s|{{COVER_IMAGE}}|$cover_image|g")

                # Omettre epub-cover-image si pas d'image trouvée
                if [[ "$line" =~ ^epub-cover-image: ]] && [[ -z "$cover_image" ]]; then
                    continue
                fi

                echo "$line"
            done < "formats/$format.yaml"
        fi

        echo "---"
    } > "$output_file"
}

# === OPTION : PARAMÈTRE COVER EXPLICITE ===
# Vous pouvez aussi ajouter une option à cmd_publish() :

# Dans cmd_publish(), ajouter :
# --cover)
#     if [[ $# -lt 2 ]]; then
#         log_error "Option --cover nécessite un chemin vers l'image"
#         return 1
#     fi
#     export SILK_COVER_IMAGE="$2"
#     shift 2
#     ;;

# Et dans create_merged_metadata() :
# cover_image="${SILK_COVER_IMAGE:-$cover_image}"

# === STRUCTURE RECOMMANDÉE PROJET SILK ===
# Mon-Projet/
# ├── cover.jpg                 # ← Couverture auto-détectée
# ├── formats/
# │   ├── base.yaml
# │   └── epub.yaml
# ├── 01-Manuscrit/
# │   ├── Ch01.md
# │   └── Ch02.md
# └── outputs/

# === TRAITEMENT LIGNE SILK ===
process_silk_line() {
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
        # Indications temporelles (*Lundi matin - Bureau*)
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

        # Conversion liens Obsidian [[liens]]
        processed_line=$(echo "$processed_line" | sed -e 's/\[\[\([^|]*\)|\([^]]*\)\]\]/\2/g' -e 's/\[\[\([^]]*\)\]\]/\1/g')

        # Gestion indentation dialogues
        if [[ "$processed_line" =~ ^[\"«—] ]]; then
            echo "\\noindent $processed_line  " >> "$output"
        else
            echo "$processed_line  " >> "$output"
        fi
    fi
}

# === NOUVELLE FONCTION POUR CRÉATION FICHIER NETTOYÉ ===
create_clean_chapter_file() {
    local output_file="$1"
    local chapter_num="$2"
    local chapter_title="$3"
    local content="$4"
    local french_quotes="$5"
    local auto_dashes="$6"

    log_debug "📝 Création fichier nettoyé: $output_file"

    # Saut de page pour chapitres > 1
    if [[ $chapter_num -gt 1 ]]; then
        echo "\\newpage" > "$output_file"
        echo "" >> "$output_file"
    else
        echo "" > "$output_file"
    fi

    # Titre du chapitre
    echo "# $chapter_title" >> "$output_file"
    echo "" >> "$output_file"

    # Traitement du contenu ligne par ligne
    while IFS= read -r line; do
        process_silk_line "$line" "$output_file" "$french_quotes" "$auto_dashes"
    done <<< "$content"

    log_debug "✅ Fichier nettoyé créé: $output_file"
    return 0
}

# === PAGE STATISTIQUES ===
create_stats_page() {
    local output_file="$1"
    local chapters_included="$2"

    {
        echo "\\newpage"
        echo ""
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

# === RAPPORT SUCCESS ===
show_publish_success() {
    local output_file="$1"
    local filename="$2"
    local format="$3"
    local chapters_included="$4"
    local duration="$5"
    local french_quotes="$6"
    local auto_dashes="$7"
    local output_type="${8:-pdf}"

    echo
    log_success "📚 ${output_type^^} généré: $output_file"

    echo
    echo "📊 RÉSUMÉ PUBLICATION:"
    echo "   📖 Fichier: $filename"
    echo "   🎯 Format: $format ($output_type)"
    echo "   📚 Chapitres: $chapters_included"
    echo "   🇫🇷 Guillemets français: $(if [[ "$french_quotes" == "true" ]]; then echo "OUI"; else echo "NON"; fi)"
    echo "   💬 Tirets automatiques: $(if [[ "$auto_dashes" == "true" ]]; then echo "OUI"; else echo "NON"; fi)"

    if [[ -f "$output_file" ]]; then
        # Calculer taille fichier
        if command -v stat &> /dev/null; then
            local file_size
            case "$(detect_os)" in
                "macos")
                    file_size=$(stat -f%z "$output_file" 2>/dev/null || echo "0")
                    ;;
                *)
                    file_size=$(stat -c%s "$output_file" 2>/dev/null || echo "0")
                    ;;
            esac
            local size_mb=$((file_size / 1024 / 1024))
            echo "   📁 Taille: ${size_mb}MB"
        fi
    fi

    echo
    echo "📁 FICHIER GÉNÉRÉ:"
    echo "   🕸️ $output_file"
    echo
    echo "💡 PROCHAINES ÉTAPES:"
    echo "   📱 Test sur appareil cible"
    echo "   🖨️  Impression test si format book"
    echo "   📧 Partage avec bêta-lecteurs"
    echo
    echo "🕸️ SILK has woven your manuscript into beautiful PDF!"
}

# === EXPORT FONCTIONS ===
export -f cmd_publish
export -f show_publish_help

# Marquer module comme chargé
readonly SILK_COMMAND_PUBLISH_LOADED=true
