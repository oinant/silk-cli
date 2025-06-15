#!/bin/bash
# debug-chapters.sh - Debug détection chapitres SILK

set -euo pipefail

echo "🕷️ SILK CLI - Debug Détection Chapitres"
echo "======================================="

# Couleurs pour le debug
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[DEBUG] $1${NC}"; }
log_success() { echo -e "${GREEN}[OK] $1${NC}"; }
log_warning() { echo -e "${YELLOW}[WARN] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }

# Fonction actuelle (probablement bugée)
extract_chapter_number_current() {
    local filename="$(basename "$1")"
    echo "$filename" | sed -n 's/^[Cc]h\([0-9]\+\).*/\1/p' | sed 's/^0*//'
}

# Fonction améliorée pour plus de formats
extract_chapter_number_improved() {
    local filename="$(basename "$1")"
    local chapter_num=""

    # Pattern 1: Ch23-1 -> 23, Ch05 -> 5
    chapter_num=$(echo "$filename" | sed -n 's/^[Cc]h\([0-9]\+\).*/\1/p' | sed 's/^0*//')

    # Pattern 2: Chapitre23 -> 23
    if [[ -z "$chapter_num" ]]; then
        chapter_num=$(echo "$filename" | sed -n 's/^[Cc]hapitre\([0-9]\+\).*/\1/p' | sed 's/^0*//')
    fi

    # Pattern 3: 23-titre -> 23
    if [[ -z "$chapter_num" ]]; then
        chapter_num=$(echo "$filename" | sed -n 's/^\([0-9]\+\).*/\1/p' | sed 's/^0*//')
    fi

    # Pattern 4: Chapitre 23 -> 23 (avec espace)
    if [[ -z "$chapter_num" ]]; then
        chapter_num=$(echo "$filename" | sed -n 's/^[Cc]hapitre[[:space:]]\+\([0-9]\+\).*/\1/p' | sed 's/^0*//')
    fi

    # Pattern 5: Ch 23 -> 23 (avec espace)
    if [[ -z "$chapter_num" ]]; then
        chapter_num=$(echo "$filename" | sed -n 's/^[Cc]h[[:space:]]\+\([0-9]\+\).*/\1/p' | sed 's/^0*//')
    fi

    echo "${chapter_num:-0}"
}

# Test sur le répertoire actuel
test_chapter_detection() {
    log_info "Test détection chapitres dans: $PWD"
    echo

    if [[ ! -d "01-Manuscrit" ]]; then
        log_error "Pas dans un projet SILK (01-Manuscrit/ manquant)"
        return 1
    fi

    echo "📁 Fichiers dans 01-Manuscrit/:"
    ls -la 01-Manuscrit/*.md 2>/dev/null || {
        log_warning "Aucun fichier .md trouvé dans 01-Manuscrit/"
        return 1
    }

    echo
    echo "🔍 ANALYSE DÉTECTION:"
    echo "┌────────────────────────────────────────────┬─────────┬─────────┐"
    echo "│ FICHIER                                    │ ACTUEL  │ AMÉLIORÉ│"
    echo "├────────────────────────────────────────────┼─────────┼─────────┤"

    local total_files=0
    local detected_current=0
    local detected_improved=0

    for file in 01-Manuscrit/*.md; do
        if [[ -f "$file" ]]; then
            ((total_files++))
            local filename=$(basename "$file")

            # Test fonction actuelle
            local num_current=$(extract_chapter_number_current "$file")
            local num_improved=$(extract_chapter_number_improved "$file")

            if [[ "$num_current" != "0" && -n "$num_current" ]]; then
                ((detected_current++))
            fi

            if [[ "$num_improved" != "0" && -n "$num_improved" ]]; then
                ((detected_improved++))
            fi

            # Formater l'affichage
            local display_filename="${filename:0:42}"
            if [[ ${#filename} -gt 42 ]]; then
                display_filename="${display_filename}..."
            fi

            local status_current="${num_current:-❌}"
            local status_improved="${num_improved:-❌}"

            printf "│ %-42s │ %-7s │ %-7s │\n" "$display_filename" "$status_current" "$status_improved"
        fi
    done

    echo "└────────────────────────────────────────────┴─────────┴─────────┘"
    echo
    echo "📊 RÉSUMÉ:"
    echo "   Total fichiers      : $total_files"
    echo "   Détectés (actuel)   : $detected_current"
    echo "   Détectés (amélioré) : $detected_improved"

    if [[ $detected_improved -gt $detected_current ]]; then
        log_success "Fonction améliorée détecte plus de chapitres !"
        echo
        log_info "💡 Remplacez la fonction dans lib/core/utils.sh"
    elif [[ $detected_current -eq 0 ]]; then
        log_error "Aucune fonction ne détecte les chapitres !"
        echo
        echo "🔍 FORMATS DÉTECTÉS:"
        for file in 01-Manuscrit/*.md; do
            if [[ -f "$file" ]]; then
                echo "   $(basename "$file")"
            fi
        done | head -5
        echo
        log_warning "Formats non reconnus - regex à adapter manuellement"
    else
        log_success "Fonction actuelle fonctionne correctement"
    fi
}

# Test de is_chapter_in_range
test_range_function() {
    echo
    log_info "Test fonction is_chapter_in_range"
    echo

    # Simuler la fonction is_chapter_in_range (version simplifiée)
    is_chapter_in_range_test() {
        local chapter_num="$1"
        local range="$2"

        if [[ "$range" == "all" ]]; then
            return 0
        fi

        if [[ -z "$chapter_num" ]] || ! [[ "$chapter_num" =~ ^[0-9]+$ ]]; then
            return 1
        fi

        if [[ "$range" == *","* ]]; then
            IFS=',' read -ra chapter_list <<< "$range"
            for ch in "${chapter_list[@]}"; do
                ch=$(echo "$ch" | tr -d ' ')
                if [[ "$chapter_num" -eq "$ch" ]]; then
                    return 0
                fi
            done
            return 1
        fi

        if [[ "$range" == *"-"* ]]; then
            local start_ch=$(echo "$range" | cut -d'-' -f1)
            local end_ch=$(echo "$range" | cut -d'-' -f2)

            if [[ "$chapter_num" -ge "$start_ch" ]] && [[ "$chapter_num" -le "$end_ch" ]]; then
                return 0
            else
                return 1
            fi
        else
            if [[ "$chapter_num" -eq "$range" ]]; then
                return 0
            else
                return 1
            fi
        fi
    }

    # Tests
    local test_ranges=("1-5" "all" "1,3,5" "28")

    echo "Tests is_chapter_in_range:"
    for range in "${test_ranges[@]}"; do
        echo "  Range: $range"
        local included=0
        local excluded=0

        for file in 01-Manuscrit/*.md; do
            if [[ -f "$file" ]]; then
                local num=$(extract_chapter_number_improved "$file")
                if [[ "$num" != "0" && -n "$num" ]]; then
                    if is_chapter_in_range_test "$num" "$range"; then
                        ((included++))
                    else
                        ((excluded++))
                    fi
                fi
            fi
        done

        echo "    ✅ Inclus: $included, ❌ Exclus: $excluded"
    done
}

# Test avec vraie commande silk context si disponible
test_silk_context() {
    echo
    log_info "Test avec vraie commande silk context"
    echo

    if [[ ! -x "silk" ]] && [[ ! -x "../silk" ]] && [[ ! -x "/mnt/c/dev/silk-cli/silk" ]]; then
        log_warning "Script silk non trouvé, sautant test"
        return
    fi

    # Essayer de trouver silk
    local silk_cmd=""
    if [[ -x "./silk" ]]; then
        silk_cmd="./silk"
    elif [[ -x "../silk" ]]; then
        silk_cmd="../silk"
    elif [[ -x "/mnt/c/dev/silk-cli/silk" ]]; then
        silk_cmd="/mnt/c/dev/silk-cli/silk"
    fi

    if [[ -n "$silk_cmd" ]]; then
        log_info "Test avec: $silk_cmd"

        # Test debug
        echo "📋 Test silk context avec debug:"
        SILK_DEBUG=true "$silk_cmd" context "Test debug" --chapters 1-3 2>&1 | head -20

        echo
        echo "📄 Vérification fichier généré:"
        if [[ -f "outputs/context/silk-context.md" ]]; then
            local chapters_in_file=$(grep -c "^### Ch" "outputs/context/silk-context.md" || echo "0")
            echo "   Chapitres dans fichier: $chapters_in_file"

            echo "   Chapitres détectés:"
            grep "^### Ch" "outputs/context/silk-context.md" | head -5
        else
            log_warning "Fichier contexte non généré"
        fi
    fi
}

# Fonction principale
main() {
    echo "🕷️ Démarrage debug détection chapitres SILK"
    echo "PWD: $PWD"
    echo "Date: $(date)"
    echo

    test_chapter_detection
    test_range_function
    test_silk_context

    echo
    log_info "🔧 ACTIONS RECOMMANDÉES:"
    echo
    echo "1. Si fonction améliorée détecte plus de chapitres:"
    echo "   → Remplacer extract_chapter_number() dans lib/core/utils.sh"
    echo
    echo "2. Si aucune fonction ne marche:"
    echo "   → Examiner formats de noms de fichiers et adapter regex"
    echo
    echo "3. Si problème dans is_chapter_in_range:"
    echo "   → Vérifier logique de ranges dans lib/core/utils.sh"
    echo
    echo "4. Test final:"
    echo "   → silk context 'Test' --chapters 1-5"
    echo "   → Compter chapitres dans outputs/context/silk-context.md"
}

# Exécution
main "$@"
