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
    if [[ "$dry_run" == "false" ]] && ! check_publish_dependencies; then
        show_dependency_help
        return 1
    fi

    log_info "🕸️ SILK tisse votre PDF (format: $format, chapitres: $max_chapters)"

    if [[ "$dry_run" == "true" ]]; then
        dry_run_publish "$format" "$max_chapters" "$output_name"
    else
        generate_silk_pdf "$format" "$max_chapters" "$french_quotes" "$auto_dashes" "$output_name" "$include_toc" "$include_stats"
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

CONVENTIONS MANUSCRIT SILK:
  ~          → Blanc typographique (pause narrative)
  ---        → Transition de scène (*** centrés)
  *texte*    → Indications temporelles/lieu (italique centré)
  [[liens]]  → Liens Obsidian (convertis automatiquement)

DÉPENDANCES REQUISES:
  - Pandoc (https://pandoc.org/installing.html)
  - XeLaTeX (https://www.latex-project.org/get/)

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

# === VÉRIFICATION DÉPENDANCES ===
check_publish_dependencies() {
    local missing=0

    if ! command -v pandoc &> /dev/null; then
        log_error "Pandoc requis mais non trouvé"
        ((missing++))
    else
        log_debug "Pandoc trouvé: $(pandoc --version | head -1)"
    fi

    if ! command -v xelatex &> /dev/null; then
        log_error "XeLaTeX requis mais non trouvé"
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

# === GÉNÉRATION PDF AVEC NETTOYAGE ===
generate_silk_pdf() {
    local format="$1"
    local max_chapters="$2"
    local french_quotes="$3"
    local auto_dashes="$4"
    local output_name="$5"
    local include_toc="$6"
    local include_stats="$7"

    local start_time=$(start_timer)
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local project_name=$(basename "$PWD")

    log_debug "Début génération PDF: format=$format, max_chapters=$max_chapters"

    ensure_directory "$PUBLISH_OUTPUT_DIR"
    ensure_directory "$PUBLISH_TEMP_DIR"

    # 🧹 NETTOYAGE AUTOMATIQUE DU DOSSIER TEMP
    cleanup_temp_directory "$PUBLISH_TEMP_DIR"

    # Générer nom de fichier CORRECTEMENT
    local filename
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

    log_debug "Nom fichier généré: $filename"

    log_info "Préparation métadonnées de publication..."

    # Créer métadonnées fusionnées
    local merged_metadata="$PUBLISH_TEMP_DIR/silk_merged_${format}_${timestamp}.yaml"
    create_merged_metadata "$format" "$merged_metadata" "$project_name"
    log_debug "Métadonnées créées: $merged_metadata"

    log_info "Collecte et nettoyage des chapitres..."

    # CORRECTION CRITIQUE: Initialisation correcte du tableau associatif
    declare -A chapter_parts_map
    local clean_files=()
    local chapters_included=0

    # Phase 1: Identifier et regrouper tous les fichiers par chapitre de base
    log_debug "🔍 Phase 1: Identification chapitres..."

    # DEBUG: Lister tous les fichiers d'abord
    log_debug "📂 Fichiers trouvés dans 01-Manuscrit/:"
    for file in 01-Manuscrit/Ch*.md; do
        if [[ -f "$file" ]]; then
            log_debug "   📄 $(basename "$file")"
        fi
    done

    for file in 01-Manuscrit/Ch*.md; do
        log_debug "🔍 DEBUT traitement fichier: $file"

        if [[ -f "$file" ]]; then
            log_debug "   ✅ Fichier existe: $file"

            if grep -q "## manuscrit" "$file"; then
                log_debug "   ✅ Marqueur manuscrit trouvé dans: $file"

                # DEBUG: Test extract_chapter_number avec gestion d'erreur
                local chapter_num=""
                log_debug "   🔍 Extraction numéro chapitre..."

                # Méthode robuste sans fonction externe
                local file_basename=$(basename "$file")
                if [[ "$file_basename" =~ ^[Cc]h([0-9]+) ]]; then
                    chapter_num="${BASH_REMATCH[1]}"
                    chapter_num=$(echo "$chapter_num" | sed 's/^0*//')  # Supprimer zéros
                    log_debug "   ✅ Numéro extrait: '$chapter_num' pour $file_basename"
                else
                    log_debug "   ❌ Impossible d'extraire numéro de: $file_basename"
                    chapter_num="0"
                fi

                log_debug "   🎯 Chapter_num='$chapter_num', max_chapters='$max_chapters'"

                if [[ -n "$chapter_num" && "$chapter_num" != "0" ]]; then
                    if [[ $chapter_num -le $max_chapters ]]; then
                        log_debug "   ✅ Chapitre $chapter_num inclus (≤ $max_chapters)"

                        # CORRECTION: Utilisation correcte du tableau associatif
                        if [[ -z "${chapter_parts_map[$chapter_num]:-}" ]]; then
                            chapter_parts_map[$chapter_num]="$file"
                            log_debug "   📝 Nouveau chapitre: chapter_parts_map[$chapter_num]='$file'"
                        else
                            chapter_parts_map[$chapter_num]="${chapter_parts_map[$chapter_num]}|$file"
                            log_debug "   📝 Ajout partie: chapter_parts_map[$chapter_num]='${chapter_parts_map[$chapter_num]}'"
                        fi
                    else
                        log_debug "   ❌ Chapitre $chapter_num exclu (> $max_chapters)"
                    fi
                else
                    log_debug "   ❌ Chapter_num invalide: '$chapter_num'"
                fi
            else
                log_debug "   ❌ Pas de marqueur manuscrit dans: $file"
            fi
        else
            log_debug "   ❌ Fichier n'existe pas: $file"
        fi

        log_debug "🔍 FIN traitement fichier: $file"
        log_debug "   📊 Chapter_parts_map actuellement: ${!chapter_parts_map[*]}"
    done

    log_debug "📊 RÉSUMÉ Phase 1:"
    log_debug "   Chapitres détectés: ${#chapter_parts_map[@]}"
    for num in "${!chapter_parts_map[@]}"; do
        local count=$(echo "${chapter_parts_map[$num]}" | tr '|' '\n' | wc -l)
        log_debug "   Ch$num: $count partie(s)"
    done

    # Phase 2: Traiter chaque chapitre avec toutes ses parties
    log_debug "🔍 Phase 2: Traitement et combinaison..."
    log_debug "📊 Chapitres à traiter: ${!chapter_parts_map[*]}"

    # Compter combien de chapitres on a vraiment
    local total_chapters=${#chapter_parts_map[@]}
    log_debug "📊 Total chapitres détectés: $total_chapters"

    if [[ $total_chapters -eq 0 ]]; then
        log_error "❌ Aucun chapitre détecté en Phase 1 !"
        log_error "   Vérifiez les noms de fichiers et marqueurs"
        return 1
    fi

    # Temporairement désactiver errexit pour la boucle de traitement
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
            log_debug "   📖 Ajout partie: $(basename "$file")"

            # Extraire titre (prendre le premier trouvé ou le principal)
            if [[ -z "$chapter_title" ]] || [[ "$(basename "$file")" != *"-1-"* && "$(basename "$file")" != *"-2-"* ]]; then
                chapter_title=$(head -n1 "$file" | sed 's/^#*\s*//')
            fi

            # Extraire contenu après "## manuscrit"
            local part_content
            if part_content=$(extract_manuscript_content "$file"); then
                if [[ -n "$part_content" ]]; then
                    combined_content+="$part_content"
                    combined_content+=$'\n\n'  # Séparateur entre parties
                fi
            else
                log_warning "   ⚠️  Pas de contenu dans: $(basename "$file")"
            fi
        done

        # Créer fichier combiné unique
        if [[ -n "$combined_content" ]]; then
            local clean_file="$PUBLISH_TEMP_DIR/silk_clean_ch${chapter_num}_${timestamp}.md"

            # Titre avec indication multi-parties si nécessaire
            local display_title="$chapter_title"
            if [[ $files_count -gt 1 ]]; then
                display_title="$chapter_title (${files_count} parties)"
            fi

            # Créer le fichier nettoyé
            if create_clean_chapter_file "$clean_file" "$chapter_num" "$display_title" "$combined_content" "$french_quotes" "$auto_dashes"; then
                clean_files+=("$clean_file")
                ((chapters_included++))

                if [[ $files_count -gt 1 ]]; then
                    echo "   ✅ Ch$chapter_num combiné ($files_count parties)"
                else
                    echo "   ✅ Ch$chapter_num préparé"
                fi
                log_debug "Chapitre ajouté: $clean_file"
            else
                log_warning "   ❌ Ch$chapter_num échec création fichier"
            fi
        else
            log_warning "   ❌ Ch$chapter_num sans contenu valide"
        fi
    done

    # Réactiver errexit
    set -e

    log_debug "Chapitres collectés: $chapters_included"
    log_debug "Fichiers clean: ${clean_files[*]}"

    if [[ $chapters_included -eq 0 ]]; then
        log_error "Aucun chapitre trouvé à publier"
        log_error "Vérifiez que vos chapitres ont le marqueur '## manuscrit'"
        return 1
    fi

    # Ajouter page statistiques si demandée
    if [[ "$include_stats" == "true" ]]; then
        local stats_file="$PUBLISH_TEMP_DIR/silk_stats_${timestamp}.md"
        create_stats_page "$stats_file" "$chapters_included"
        clean_files=("$stats_file" "${clean_files[@]}")
        log_debug "Page stats ajoutée: $stats_file"
    fi

    # Le chemin de sortie doit pointer vers le PDF !
    local output_pdf="$PUBLISH_OUTPUT_DIR/$filename"

    log_info "🎯 Génération PDF avec Pandoc..."
    log_debug "Fichiers d'entrée: ${clean_files[*]}"
    log_debug "Métadonnées: $merged_metadata"
    log_debug "Sortie PDF: $output_pdf"

    local pandoc_args=(
        "$merged_metadata"
        "${clean_files[@]}"
        "-o" "$output_pdf"
        "--pdf-engine=xelatex"
        "-f" "markdown+smart"
        "--highlight-style=tango"
    )

    # Ajouter TOC si demandé
    if [[ "$include_toc" == "true" ]]; then
        pandoc_args+=("--toc" "--toc-depth=1")
    fi

    log_debug "Commande Pandoc: pandoc ${pandoc_args[*]}"

    # Capturer sortie d'erreur Pandoc
    local pandoc_output
    local pandoc_exit_code=0

    echo "🔄 Exécution Pandoc..."
    if pandoc_output=$(pandoc "${pandoc_args[@]}" 2>&1); then
        log_debug "Pandoc terminé avec succès"
        log_debug "Sortie Pandoc: $pandoc_output"

        if [[ -f "$output_pdf" ]]; then
            local duration=$(end_timer "$start_time")
            show_publish_success "$output_pdf" "$filename" "$format" "$chapters_included" "$duration" "$french_quotes" "$auto_dashes"

            # Nettoyage fichiers temporaires ACTUELS sauf en debug
            if [[ "${SILK_DEBUG:-false}" != "true" ]]; then
                log_debug "Nettoyage fichiers temporaires de cette session"
                rm -f "$merged_metadata" "${clean_files[@]}" 2>/dev/null || true
            else
                log_debug "Fichiers temporaires conservés pour debug dans: $PUBLISH_TEMP_DIR"
            fi
            return 0
        else
            log_error "Pandoc s'est terminé sans erreur mais le PDF n'a pas été créé"
            log_error "Fichier attendu: $output_pdf"
            log_error "Sortie Pandoc: $pandoc_output"
            return 1
        fi
    else
        pandoc_exit_code=$?
        log_error "Erreur Pandoc (code: $pandoc_exit_code)"
        echo
        echo "📋 SORTIE PANDOC:"
        echo "$pandoc_output"
        echo
        echo "🔧 DEBUGGING:"
        echo "   1. Vérifiez les métadonnées: cat $merged_metadata"
        echo "   2. Vérifiez un chapitre: head -20 ${clean_files[0]:-aucun}"
        echo "   3. Test Pandoc manuel:"
        if [[ ${#clean_files[@]} -gt 0 ]]; then
            echo "      pandoc $merged_metadata ${clean_files[0]} -o test.pdf --pdf-engine=xelatex"
        else
            echo "      Aucun fichier chapitre généré à tester"
        fi
        echo "   4. Vérifiez XeLaTeX: xelatex --version"
        echo
        echo "💡 Fichiers temporaires conservés dans: $PUBLISH_TEMP_DIR"
        return 1
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
create_merged_metadata() {
    local format="$1"
    local output_file="$2"
    local project_name="$3"

    {
        echo "---"

        # Base metadata ou fallback
        if [[ -f "formats/base.yaml" ]]; then
            # Exclure header-includes de base.yaml pour éviter conflit
            grep -v "^header-includes:" "formats/base.yaml" | grep -v "^  " || {
                echo "title: \"$project_name\""
                echo "author: \"${SILK_AUTHOR_NAME:-Auteur}\""
                echo "date: \"$(date '+%Y-%m-%d')\""
                echo "lang: fr-FR"
                echo "documentclass: book"
            }
        else
            echo "title: \"$project_name\""
            echo "author: \"${SILK_AUTHOR_NAME:-Auteur}\""
            echo "date: \"$(date '+%Y-%m-%d')\""
            echo "lang: fr-FR"
            echo "documentclass: book"
        fi

        echo ""

        # Format specific (avec header-includes fusionné)
        if [[ -f "formats/$format.yaml" ]]; then
            cat "formats/$format.yaml"
        fi

        echo "---"
    } > "$output_file"
}


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
    local output_pdf="$1"
    local filename="$2"
    local format="$3"
    local chapters_included="$4"
    local duration="$5"
    local french_quotes="$6"
    local auto_dashes="$7"

    echo
    log_success "🕸️ PDF généré en $duration"

    echo
    echo "📊 RÉSUMÉ PUBLICATION:"
    echo "   📖 Fichier: $filename"
    echo "   🎯 Format: $format"
    echo "   📚 Chapitres: $chapters_included"
    echo "   🇫🇷 Guillemets français: $(if [[ "$french_quotes" == "true" ]]; then echo "OUI"; else echo "NON"; fi)"
    echo "   💬 Tirets automatiques: $(if [[ "$auto_dashes" == "true" ]]; then echo "OUI"; else echo "NON"; fi)"

    if [[ -f "$output_pdf" ]]; then
        # Calculer taille fichier
        if command -v stat &> /dev/null; then
            local file_size
            case "$(detect_os)" in
                "macos")
                    file_size=$(stat -f%z "$output_pdf" 2>/dev/null || echo "0")
                    ;;
                *)
                    file_size=$(stat -c%s "$output_pdf" 2>/dev/null || echo "0")
                    ;;
            esac
            local size_mb=$((file_size / 1024 / 1024))
            echo "   📁 Taille: ${size_mb}MB"
        fi
    fi

    echo
    echo "📁 FICHIER GÉNÉRÉ:"
    echo "   🕸️ $output_pdf"
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
