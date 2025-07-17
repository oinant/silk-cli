#!/bin/bash
# lib/commands/publish/validation.sh - Validation formats et dépendances

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

# === DÉTECTION TYPE SORTIE ===
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

# === DÉTECTION STRUCTURE CUSTOM HTML ===
detect_custom_structure() {
    local format="$1"
    local format_config="formats/$format.yaml"

    if [[ -f "$format_config" ]]; then
        if grep -q "^custom_structure:[[:space:]]*true" "$format_config"; then
            echo "true"
            return 0
        fi
    fi
    echo "false"
}

# === VÉRIFICATION DÉPENDANCES ===
check_publish_dependencies() {
    local format="$1"
    local output_type=$(detect_output_format "$format")
    local missing=0

    # Pandoc requis pour tous les formats
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

# === AIDE DÉPENDANCES ===
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
        if [[ -f "$file" ]] && grep -q "$MANUSCRIPT_SEPARATOR" "$file"; then
            local chapter_num=$(extract_chapter_number "$file")
            if [[ -n "$chapter_num" && "$chapter_num" -le "$max_chapters" ]]; then
                ((available_chapters++))
                local words=$(sed -n "/${MANUSCRIPT_SEPARATOR}/,\$p" "$file" | tail -n +2 | wc -w)
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

# === EXPORTS ===
export -f validate_format
export -f detect_output_format
export -f detect_custom_structure
export -f check_publish_dependencies
export -f show_dependency_help
export -f dry_run_publish

# Marquer module comme chargé
readonly SILK_PUBLISH_VALIDATION_LOADED=true
