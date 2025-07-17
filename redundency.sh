#!/bin/bash

# =============================================================================
# ANALYSE FRÉQUENCE MOTS ET GROUPES NOMINAUX
# Compatible avec ton système SILK
# =============================================================================

# --- CONFIGURATION ---
MIN_WORD_LENGTH=3
MIN_FREQUENCY=2
EXCLUDE_COMMON_WORDS=true

# Mots courants à exclure (français)
COMMON_WORDS="le la les de du des et à un une ce cette ces que qui quoi avec sans pour par sur sous dans vers chez contre entre parmi selon pendant durant avant après depuis jusqu'à car donc mais où comme quand comment pourquoi alors ainsi encore toujours déjà jamais plus moins très assez trop peu beaucoup bien mal aussi même autre tout tous toute toutes quelque quelques chaque chacun chacune aucun aucune certain certaine certains certaines plusieurs tel telle tels telles tout tous toute toutes"

# =============================================================================
# ANALYSE FRÉQUENCE DES MOTS
# =============================================================================

analyze_word_frequency() {
    local input_file="$1"
    local top_n="${2:-20}"

    if [[ ! -f "$input_file" ]]; then
        echo "❌ Fichier non trouvé: $input_file" >&2
        return 1
    fi

    echo "📊 ANALYSE FRÉQUENCE DES MOTS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Traitement du texte
    local temp_file=$(mktemp)

    # Extraction et nettoyage
    if command -v gsed >/dev/null 2>&1; then
        SED_CMD="gsed"
    else
        SED_CMD="sed"
    fi

    cat "$input_file" | \
        # Supprimer markdown et balises
        $SED_CMD 's/[#*_`\[\](){}]//g' | \
        # Convertir en minuscules
        tr '[:upper:]' '[:lower:]' | \
        # Supprimer ponctuation sauf apostrophes
        $SED_CMD "s/[^a-zàâäéèêëïîôöùûüÿç']/ /g" | \
        # Remplacer multiples espaces par un seul
        tr -s ' ' | \
        # Un mot par ligne
        tr ' ' '\n' | \
        # Filtrer mots trop courts
        awk "length(\$0) >= $MIN_WORD_LENGTH" | \
        # Supprimer lignes vides
        grep -v '^$' > "$temp_file"

    # Filtrage mots courants si activé
    if [[ "$EXCLUDE_COMMON_WORDS" == "true" ]]; then
        local filtered_file=$(mktemp)
        grep -vwF -f <(echo "$COMMON_WORDS" | tr ' ' '\n') "$temp_file" > "$filtered_file"
        mv "$filtered_file" "$temp_file"
    fi

    # Comptage et tri
    echo "🔍 Top $top_n mots les plus fréquents:"
    echo
    printf "%-4s %-20s %s\n" "Rang" "Mot" "Occurrences"
    echo "────────────────────────────────────────"

    sort "$temp_file" | uniq -c | sort -nr | head -n "$top_n" | \
    awk -v min_freq="$MIN_FREQUENCY" '$1 >= min_freq { printf "%-4d %-20s %d\n", NR, $2, $1 }'

    # Statistiques globales
    local total_words=$(wc -l < "$temp_file")
    local unique_words=$(sort "$temp_file" | uniq | wc -l)
    local richness=$((unique_words * 100 / total_words))

    echo
    echo "📈 Statistiques:"
    echo "   • Mots total: $total_words"
    echo "   • Mots uniques: $unique_words"
    echo "   • Richesse lexicale: ${richness}%"

    rm -f "$temp_file"
}

# =============================================================================
# ANALYSE GROUPES NOMINAUX (N-GRAMMES)
# =============================================================================

analyze_ngrams() {
    local input_file="$1"
    local n="${2:-2}"  # Bigrammes par défaut
    local top_n="${3:-15}"

    if [[ ! -f "$input_file" ]]; then
        echo "❌ Fichier non trouvé: $input_file" >&2
        return 1
    fi

    echo
    echo "🔗 ANALYSE ${n}-GRAMMES (GROUPES DE $n MOTS)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local temp_file=$(mktemp)
    local ngrams_file=$(mktemp)

    # Préparation du texte
    cat "$input_file" | \
        # Supprimer markdown
        $SED_CMD 's/[#*_`\[\](){}]//g' | \
        # Convertir en minuscules
        tr '[:upper:]' '[:lower:]' | \
        # Garder lettres, espaces et apostrophes
        $SED_CMD "s/[^a-zàâäéèêëïîôöùûüÿç' ]/ /g" | \
        # Normaliser espaces
        tr -s ' ' | \
        # Supprimer espaces début/fin
        $SED_CMD 's/^ *//; s/ *$//' > "$temp_file"

    # Génération des n-grammes - Version simplifiée
    cat "$temp_file" | while read -r line; do
        words=($line)
        for ((i=0; i<=((${#words[@]}-n)); i++)); do
            ngram=""
            for ((j=0; j<n; j++)); do
                word="${words[$((i+j))]}"
                if [[ ${#word} -ge 2 ]]; then
                    if [[ -z "$ngram" ]]; then
                        ngram="$word"
                    else
                        ngram="$ngram $word"
                    fi
                fi
            done
            # Vérifier qu'on a exactement n mots
            if [[ $(echo "$ngram" | wc -w) -eq $n ]]; then
                echo "$ngram"
            fi
        done
    done > "$ngrams_file"

    # Filtrage des n-grammes avec mots courants
    if [[ "$EXCLUDE_COMMON_WORDS" == "true" ]]; then
        local filtered_ngrams=$(mktemp)
        while read -r ngram; do
            local has_common=false
            for word in $ngram; do
                if echo "$COMMON_WORDS" | grep -wq "$word"; then
                    has_common=true
                    break
                fi
            done
            if [[ "$has_common" == "false" ]]; then
                echo "$ngram"
            fi
        done < "$ngrams_file" > "$filtered_ngrams"
        mv "$filtered_ngrams" "$ngrams_file"
    fi

    # Comptage et affichage
    echo "🔍 Top $top_n ${n}-grammes les plus fréquents:"
    echo
    printf "%-4s %-40s %s\n" "Rang" "${n}-gramme" "Occurrences"
    echo "──────────────────────────────────────────────────────"

    sort "$ngrams_file" | uniq -c | sort -nr | head -n "$top_n" | \
    awk -v min_freq="$MIN_FREQUENCY" '$1 >= min_freq { printf "%-4d %-40s %d\n", NR, substr($0, index($0, $2)), $1 }'

    # Statistiques
    local total_ngrams=$(wc -l < "$ngrams_file")
    local unique_ngrams=$(sort "$ngrams_file" | uniq | wc -l)

    echo
    echo "📈 Statistiques ${n}-grammes:"
    echo "   • Total: $total_ngrams"
    echo "   • Uniques: $unique_ngrams"

    rm -f "$temp_file" "$ngrams_file"
}

# =============================================================================
# ANALYSE COMPLÈTE
# =============================================================================

analyze_text_complete() {
    local input_file="$1"
    local top_words="${2:-20}"
    local top_ngrams="${3:-15}"

    if [[ ! -f "$input_file" ]]; then
        echo "❌ Usage: analyze_text_complete <fichier> [top_mots] [top_ngrams]" >&2
        return 1
    fi

    echo "🕷️ SILK - ANALYSE TEXTUELLE COMPLÈTE"
    echo "Fichier: $(basename "$input_file")"
    echo "$(date '+%d/%m/%Y %H:%M:%S')"
    echo

    # Analyse des mots
    analyze_word_frequency "$input_file" "$top_words"

    # Analyse bigrammes
    analyze_ngrams "$input_file" 2 "$top_ngrams"

    # Analyse trigrammes
    analyze_ngrams "$input_file" 3 10

    echo
    echo "✅ Analyse terminée"
}

# =============================================================================
# FONCTION POUR SILK INTEGRATION
# =============================================================================

silk_analyze_manuscript() {
    local chapter_range="${1:-all}"

    if [[ ! -d "01-Manuscrit" ]]; then
        echo "❌ Répertoire 01-Manuscrit non trouvé" >&2
        return 1
    fi

    local temp_content=$(mktemp)

    # Extraction du contenu manuscrit
    for file in 01-Manuscrit/*.md; do
        if [[ -f "$file" ]] && grep -q "$" "$file"; then
            echo "📄 Extraction: $(basename "$file")"

            # Extraire contenu après le marqueur
            awk -v marker="$MANUSCRIPT_SEPARATOR" '
            found && !/^---$/ { print }
            $0 ~ marker { found = 1; next }
            ' "$file" >> "$temp_content"
        fi
    done

    if [[ ! -s "$temp_content" ]]; then
        echo "❌ Aucun contenu manuscrit trouvé avec le marqueur '$MANUSCRIPT_SEPARATOR'" >&2
        rm -f "$temp_content"
        return 1
    fi

    # Analyse complète
    analyze_text_complete "$temp_content" 25 20

    rm -f "$temp_content"
}

# =============================================================================
# EXEMPLES D'UTILISATION
# =============================================================================

show_examples() {
    echo "📚 EXEMPLES D'UTILISATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "# Analyser un fichier texte"
    echo "analyze_word_frequency mon_texte.txt 30"
    echo
    echo "# Analyser les bigrammes"
    echo "analyze_ngrams mon_texte.txt 2 20"
    echo
    echo "# Analyse complète"
    echo "analyze_text_complete mon_texte.txt"
    echo
    echo "# Pour projet SILK"
    echo "silk_analyze_manuscript"
    echo
    echo "# Configuration:"
    echo "MIN_WORD_LENGTH=$MIN_WORD_LENGTH"
    echo "MIN_FREQUENCY=$MIN_FREQUENCY"
    echo "EXCLUDE_COMMON_WORDS=$EXCLUDE_COMMON_WORDS"
}

# =============================================================================
# MAIN
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        "words")
            analyze_word_frequency "$2" "$3"
            ;;
        "ngrams")
            analyze_ngrams "$2" "$3" "$4"
            ;;
        "complete")
            analyze_text_complete "$2" "$3" "$4"
            ;;
        "silk")
            silk_analyze_manuscript "$2"
            ;;
        "examples"|"help")
            show_examples
            ;;
        *)
            echo "Usage: $0 {words|ngrams|complete|silk|help} [options...]"
            echo "Tapez '$0 help' pour voir les exemples"
            ;;
    esac
fi
