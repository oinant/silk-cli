#!/bin/bash
# lib/commands/publish/reporting.sh - Rapports et statistiques

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

# === STATISTIQUES PROJET ===
generate_project_stats() {
    local output_format="${1:-console}"
    
    local total_chapters=0
    local total_words=0
    local total_files=0
    
    # Analyser tous les fichiers chapitres
    for file in 01-Manuscrit/Ch*.md; do
        if [[ -f "$file" ]] && grep -q "## manuscrit" "$file"; then
            ((total_files++))
            
            # Extraire numéro de chapitre
            local chapter_num=$(extract_chapter_number "$file")
            if [[ -n "$chapter_num" ]] && [[ "$chapter_num" -gt "$total_chapters" ]]; then
                total_chapters="$chapter_num"
            fi
            
            # Compter mots
            local words=$(sed -n '/## manuscrit/,$p' "$file" | tail -n +2 | wc -w)
            total_words=$((total_words + words))
        fi
    done
    
    case "$output_format" in
        "json")
            cat << EOF
{
    "project": "$(basename "$PWD")",
    "chapters": $total_chapters,
    "files": $total_files,
    "words": $total_words,
    "pages_estimated": $((total_words / 250)),
    "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
            ;;
        "markdown")
            cat << EOF
# Statistiques Projet SILK

**Projet:** $(basename "$PWD")  
**Chapitres:** $total_chapters  
**Fichiers:** $total_files  
**Mots:** $total_words  
**Pages estimées:** $((total_words / 250))  

*Généré le $(date '+%d/%m/%Y à %H:%M:%S')*
EOF
            ;;
        *)
            echo "📊 STATISTIQUES PROJET:"
            echo "   Nom: $(basename "$PWD")"
            echo "   Chapitres: $total_chapters"
            echo "   Fichiers: $total_files"
            echo "   Mots: $total_words"
            echo "   Pages estimées: $((total_words / 250))"
            ;;
    esac
}

# === RAPPORT FORMATS DISPONIBLES ===
show_available_formats() {
    echo "📋 FORMATS SILK DISPONIBLES:"
    echo
    
    if [[ ! -d "formats" ]]; then
        echo "   ❌ Répertoire formats/ manquant"
        return 1
    fi
    
    local format_count=0
    
    for format_file in formats/*.yaml; do
        if [[ -f "$format_file" ]] && [[ "$(basename "$format_file")" != "base.yaml" ]]; then
            local format_name=$(basename "$format_file" .yaml)
            local output_type=$(detect_output_format "$format_name")
            
            # Extraire description si disponible
            local description=""
            if grep -q "^description:" "$format_file"; then
                description=$(grep "^description:" "$format_file" | cut -d: -f2- | xargs)
            fi
            
            printf "   %-12s [%s] %s\n" "$format_name" "$output_type" "$description"
            ((format_count++))
        fi
    done
    
    echo
    echo "   Total: $format_count formats disponibles"
    
    if [[ -f "formats/base.yaml" ]]; then
        echo "   ✅ Template de base configuré"
    else
        echo "   ⚠️  Template de base manquant"
    fi
}

# === RAPPORT ERREURS PUBLICATION ===
show_publish_error_report() {
    local error_code="$1"
    local error_context="${2:-}"
    
    echo
    log_error "Échec de la publication (code: $error_code)"
    echo
    
    case "$error_code" in
        1)
            echo "🔧 DIAGNOSTIC:"
            echo "   • Vérifiez la syntaxe des fichiers chapitres"
            echo "   • Assurez-vous que les séparateurs '## manuscrit' sont présents"
            echo "   • Vérifiez les permissions des répertoires"
            ;;
        2)
            echo "🔧 DIAGNOSTIC:"
            echo "   • Format non trouvé dans le répertoire formats/"
            echo "   • Créez le fichier formats/VOTRE_FORMAT.yaml"
            echo "   • Ou utilisez un format existant"
            ;;
        126|127)
            echo "🔧 DIAGNOSTIC:"
            echo "   • Dépendances manquantes (Pandoc ou XeLaTeX)"
            echo "   • Exécutez: silk publish --dry-run"
            echo "   • Installez les dépendances requises"
            ;;
        *)
            echo "🔧 DIAGNOSTIC:"
            echo "   • Erreur inconnue durant la publication"
            echo "   • Vérifiez les logs avec: silk publish --debug"
            echo "   • Consultez la documentation SILK"
            ;;
    esac
    
    if [[ -n "$error_context" ]]; then
        echo
        echo "💬 CONTEXTE:"
        echo "   $error_context"
    fi
    
    echo
    echo "💡 AIDE:"
    echo "   • silk publish --help"
    echo "   • silk publish --dry-run"
    echo "   • Documentation: https://silk-cli.dev/docs"
}

# === VALIDATION PUBLICATION ===
validate_publication_output() {
    local output_file="$1"
    local expected_type="${2:-pdf}"
    
    if [[ ! -f "$output_file" ]]; then
        log_error "Fichier de sortie non créé: $output_file"
        return 1
    fi
    
    # Vérifier taille minimale
    local file_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo "0")
    if [[ "$file_size" -lt 1024 ]]; then
        log_warning "Fichier de sortie très petit (${file_size} bytes)"
        return 2
    fi
    
    # Vérification basique du type de fichier
    if command -v file &> /dev/null; then
        local file_type=$(file -b "$output_file" 2>/dev/null)
        case "$expected_type" in
            "pdf")
                if [[ ! "$file_type" =~ PDF ]]; then
                    log_warning "Le fichier ne semble pas être un PDF valide"
                    return 3
                fi
                ;;
            "html")
                if [[ ! "$file_type" =~ HTML ]] && [[ ! "$file_type" =~ ASCII ]]; then
                    log_warning "Le fichier ne semble pas être un HTML valide"
                    return 3
                fi
                ;;
            "epub")
                if [[ ! "$file_type" =~ ZIP ]] && [[ ! "$file_type" =~ EPUB ]]; then
                    log_warning "Le fichier ne semble pas être un EPUB valide"
                    return 3
                fi
                ;;
        esac
    fi
    
    log_debug "Validation fichier de sortie: OK"
    return 0
}

# === MÉTRIQUES PERFORMANCE ===
show_performance_metrics() {
    local start_time="$1"
    local chapters_processed="$2"
    local words_processed="$3"
    local output_file="$4"
    
    local duration=$(end_timer "$start_time")
    local file_size_mb=0
    
    if [[ -f "$output_file" ]]; then
        local file_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo "0")
        file_size_mb=$((file_size / 1024 / 1024))
    fi
    
    echo
    echo "⚡ MÉTRIQUES PERFORMANCE:"
    echo "   ⏱️  Durée totale: ${duration}s"
    echo "   📚 Chapitres traités: $chapters_processed"
    echo "   📝 Mots traités: $words_processed"
    echo "   💾 Taille finale: ${file_size_mb}MB"
    
    if [[ "$duration" -gt 0 ]]; then
        local words_per_second=$((words_processed / duration))
        echo "   🚀 Vitesse: $words_per_second mots/seconde"
    fi
}

# === RAPPORT DIAGNOSTIC SYSTÈME ===
show_system_diagnostic() {
    echo "🔧 DIAGNOSTIC SYSTÈME SILK PUBLISH:"
    echo
    
    # Vérifier dépendances
    echo "📦 DÉPENDANCES:"
    if command -v pandoc &> /dev/null; then
        echo "   ✅ Pandoc: $(pandoc --version | head -1)"
    else
        echo "   ❌ Pandoc: non installé"
    fi
    
    if command -v xelatex &> /dev/null; then
        echo "   ✅ XeLaTeX: $(xelatex --version | head -1)"
    else
        echo "   ❌ XeLaTeX: non installé"
    fi
    
    # Vérifier structure projet
    echo
    echo "📁 STRUCTURE PROJET:"
    if [[ -d "01-Manuscrit" ]]; then
        local chapter_files=$(find 01-Manuscrit -name "Ch*.md" | wc -l)
        echo "   ✅ Répertoire manuscrit: $chapter_files fichiers"
    else
        echo "   ❌ Répertoire manuscrit: manquant"
    fi
    
    if [[ -d "formats" ]]; then
        local format_files=$(find formats -name "*.yaml" | wc -l)
        echo "   ✅ Répertoire formats: $format_files templates"
    else
        echo "   ❌ Répertoire formats: manquant"
    fi
    
    # Vérifier répertoires de sortie
    echo
    echo "📤 RÉPERTOIRES SORTIE:"
    for dir in "$PUBLISH_OUTPUT_DIR" "$PUBLISH_TEMP_DIR"; do
        if [[ -d "$dir" ]]; then
            local files_count=$(find "$dir" -type f | wc -l)
            echo "   ✅ $dir: $files_count fichiers"
        else
            echo "   ⚠️  $dir: n'existe pas (sera créé)"
        fi
    done
    
    # Vérifier espace disque
    echo
    echo "💾 ESPACE DISQUE:"
    if command -v df &> /dev/null; then
        local disk_usage=$(df -h . | tail -1 | awk '{print $4}')
        echo "   📊 Espace disponible: $disk_usage"
    fi
}

# === EXPORTS ===
export -f show_publish_success
export -f generate_project_stats
export -f show_available_formats
export -f show_publish_error_report
export -f validate_publication_output
export -f show_performance_metrics
export -f show_system_diagnostic

# Marquer module comme chargé
readonly SILK_PUBLISH_REPORTING_LOADED=true
