#!/bin/bash
# lib/commands/publish/output.sh - Génération des sorties

# === GÉNÉRATION OUTPUT UNIVERSEL (PDF/EPUB/HTML) ===
generate_silk_output() {
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

    # Détecter le type de sortie depuis le YAML
    local output_type=$(detect_output_format "$format")

    log_info "Collecte et analyse des chapitres..."

    # === TRAITEMENT HTML CUSTOM ===
    if [[ "$output_type" == "html" ]] && [[ "$(detect_custom_structure "$format")" == "true" ]]; then
        log_debug "🕸️ Génération HTML avec structure sémantique"
        
        # Vérifier que la fonction est disponible
        if ! declare -f generate_custom_html > /dev/null; then
            log_error "Fonction generate_custom_html non disponible"
            log_error "Le module core/custom_html.sh n'est pas chargé correctement"
            return 1
        fi

        generate_custom_html "$format" "$max_chapters" "$french_quotes" "$auto_dashes" "$output_name" "$include_toc" "$include_stats" "$embeddable"
        return $?
    fi

    # === TRAITEMENT PDF/EPUB (PANDOC) ===
    local extension=$(get_output_extension "$output_type")
    local filename=$(generate_output_filename "$format" "$max_chapters" "$output_name" "$extension" "$project_name" "$timestamp")

    log_debug "Nom fichier généré: $filename (type: $output_type)"

    # Créer les répertoires nécessaires
    mkdir -p "$PUBLISH_OUTPUT_DIR" "$PUBLISH_TEMP_DIR"

    log_info "Préparation métadonnées de publication..."

    # Créer métadonnées fusionnées
    local merged_metadata="$PUBLISH_TEMP_DIR/silk_merged_${format}_${timestamp}.yaml"
    create_merged_metadata "$format" "$merged_metadata" "$project_name" "$include_toc" "$embeddable"
    log_debug "Métadonnées créées: $merged_metadata"

    log_info "Préparation fichiers pour Pandoc..."

    # Préparer contenu des chapitres
    local clean_files_output
    clean_files_output=$(prepare_chapter_content "$max_chapters" "$french_quotes" "$auto_dashes" "$output_type" "$timestamp")
    
    if [[ $? -ne 0 ]] || [[ -z "$clean_files_output" ]]; then
        log_error "Échec préparation contenu chapitres"
        return 1
    fi

    # Convertir la sortie en array
    local clean_files=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && clean_files+=("$file")
    done <<< "$clean_files_output"

    local chapters_count=${#clean_files[@]}
    
    # Ajouter page statistiques si demandée
    if [[ "$include_stats" == "true" ]]; then
        local stats_file="$PUBLISH_TEMP_DIR/silk_stats_${timestamp}.md"
        create_stats_page "$stats_file" "$chapters_count" "$output_type"
        clean_files=("$stats_file" "${clean_files[@]}")
        log_debug "Page stats ajoutée: $stats_file"
    fi

    # Chemin de sortie final
    local output_file="$PUBLISH_OUTPUT_DIR/$filename"

    # Exécuter la génération Pandoc
    execute_pandoc_generation "$output_file" "$merged_metadata" "${clean_files[@]}" "$output_type" "$include_toc"
    local pandoc_result=$?

    if [[ $pandoc_result -eq 0 ]]; then
        local duration=$(end_timer "$start_time")
        show_publish_success "$output_file" "$filename" "$format" "$chapters_count" "$duration" "$french_quotes" "$auto_dashes" "$output_type"

        # Nettoyage fichiers temporaires (sauf en debug)
        if [[ "${SILK_DEBUG:-false}" != "true" ]]; then
            log_debug "Nettoyage fichiers temporaires de cette session"
            rm -f "$merged_metadata" "${clean_files[@]}" 2>/dev/null || true
        else
            log_debug "Fichiers temporaires conservés pour debug dans: $PUBLISH_TEMP_DIR"
        fi
        return 0
    else
        return $pandoc_result
    fi
}

# === EXÉCUTION PANDOC ===
execute_pandoc_generation() {
    local output_file="$1"
    local merged_metadata="$2"
    shift 2
    local clean_files=("$@")
    
    # Récupérer les derniers arguments (passés dans l'ordre inverse)
    local include_toc="${clean_files[-1]}"
    local output_type="${clean_files[-2]}"
    
    # Retirer les 2 derniers éléments de l'array
    unset 'clean_files[-1]'
    unset 'clean_files[-1]'

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
            echo "      pandoc $merged_metadata ${clean_files[0]} -o test.${output_file##*.}"
        fi
        echo
        return $pandoc_exit_code
    fi
}

# === EXPORTS ===
export -f generate_silk_output
export -f execute_pandoc_generation

# Marquer module comme chargé
readonly SILK_PUBLISH_OUTPUT_LOADED=true
