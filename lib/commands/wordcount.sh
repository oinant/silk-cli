#!/bin/bash
# lib/commands/wordcount.sh - Commande SILK wordcount

# Vérification chargement des dépendances
if [[ "${SILK_CORE_UTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/utils requis" >&2
    exit 1
fi

if [[ "${SILK_CORE_VAULT_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/vault requis" >&2
    exit 1
fi

# === CONSTANTES ===
readonly DEFAULT_TARGET=80000
readonly THRESHOLDS=(40000 60000 80000 100000 120000)
readonly THRESHOLD_LABELS=("40k" "60k" "80k" "100k" "120k")

# === FONCTION PRINCIPALE ===
cmd_wordcount() {
    ensure_silk_context

    local target_words="$DEFAULT_TARGET"
    if [[ -f ".silk/config" ]]; then
        source ".silk/config"
        target_words="${TARGET_WORDS:-$DEFAULT_TARGET}"
    fi


    local show_details=true
    local show_projections=true
    local output_format="table"

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_wordcount_help
                return 0
                ;;
            -t|--target)
                target_words="$2"
                shift 2
                ;;
            --summary)
                show_details=false
                output_format="summary"
                shift
                ;;
            --no-projections)
                show_projections=false
                shift
                ;;
            --json)
                output_format="json"
                show_details=false
                show_projections=false
                shift
                ;;
            --csv)
                output_format="csv"
                shift
                ;;
            -*)
                log_error "Option inconnue: $1"
                return 1
                ;;
            *)
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    target_words="$1"
                fi
                shift
                ;;
        esac
    done

    if ! is_valid_word_count "$target_words"; then
        log_error "Objectif mots invalide: $target_words"
        return 1
    fi

    log_info "🕸️ SILK analyse votre progression (objectif: $target_words mots)"

    analyze_silk_wordcount "$target_words" "$show_details" "$show_projections" "$output_format"
}

# === AIDE WORDCOUNT ===
show_wordcount_help() {
    cat << 'HELP'
📊 SILK WORDCOUNT - Statistiques progression manuscrit

USAGE:
  silk wordcount [TARGET_WORDS] [OPTIONS]

OPTIONS:
  -t, --target NUMBER       Objectif en mots (défaut config)
  --summary                 Résumé uniquement (pas de détails)
  --no-projections         Pas de calculs objectif
  --json                   Sortie format JSON
  --csv                    Sortie format CSV
  -h, --help               Afficher cette aide

EXEMPLES:
  silk wordcount             # Objectif depuis config
  silk wordcount 100000      # Objectif 100k mots
  silk wordcount -t 60000    # Objectif 60k (novella)
  silk wordcount --summary   # Résumé rapide
  silk wordcount --json     # Export JSON

SEUILS DE RÉFÉRENCE SILK:
  40k mots   = ~160 pages   (novella courte)
  60k mots   = ~240 pages   (roman court)
  80k mots   = ~320 pages   (standard)
  100k mots  = ~400 pages   (gros roman)
  120k mots  = ~480 pages   (très gros roman)

FONCTIONNALITÉS AVANCÉES:
  - Regroupement automatique chapitres bis (Ch23 + Ch23-1 = Ch23)
  - Détection séparateur MANUSCRIPT_SEPARATOR obligatoire
  - Analyse régularité et recommandations personnalisées
  - Identification chapitres à développer en priorité
  - Positionnement dans seuils éditoriaux

SILK analyse intelligemment votre progression littéraire.
HELP
}

# === ANALYSE PRINCIPALE ===
analyze_silk_wordcount() {
    local target_words="$1"
    local show_details="$2"
    local show_projections="$3"
    local output_format="$4"

    # CORRECTION: Variables globales pour statistiques - déclaration dans function scope
    local -A chapter_words
    local -A chapter_titles
    local -A chapter_files
    local total_words=0
    local min_words=999999
    local max_words=0
    local min_chapter=""
    local max_chapter=""
    local files_without_separator=0

    log_debug "Analyse wordcount: objectif=$target_words, format=$output_format"

    # === PHASE 1: REGROUPER LES CHAPITRES BIS ===
    log_debug "🔍 Détection et regroupement des chapitres..."

    for file in 01-Manuscrit/Ch[0-9]*.md; do
        if [[ -f "$file" ]]; then
            local base_num=$(get_base_chapter_number "$file")
            local word_count=$(extract_silk_manuscrit_content "$file")
            local title=$(get_chapter_title "$file")

            log_debug "Fichier: $(basename "$file"), base_num: $base_num, words: $word_count"

            # Vérifier séparateur
            if ! grep -q "$MANUSCRIPT_SEPARATOR" "$file"; then
                ((files_without_separator++))
                log_debug "⚠️  FICHIER SANS SÉPARATEUR: $(basename "$file")"
                continue
            fi

            # Initialiser si première occurrence du chapitre
            if [[ -z "${chapter_words[$base_num]:-}" ]]; then
                chapter_words[$base_num]=0
                chapter_titles[$base_num]="$title"
                chapter_files[$base_num]=""
            fi

            # Cumuler les mots
            chapter_words[$base_num]=$((${chapter_words[$base_num]} + word_count))

            # Ajouter le fichier à la liste
            if [[ -n "${chapter_files[$base_num]}" ]]; then
                chapter_files[$base_num]="${chapter_files[$base_num]}, $(basename "$file")"
            else
                chapter_files[$base_num]="$(basename "$file")"
            fi

            # Mettre à jour le titre si c'est un chapitre principal
            if ! is_bis_chapter "$(basename "$file")"; then
                chapter_titles[$base_num]="$title"
            fi
        fi
    done

    # === PHASE 2: CALCULS STATISTIQUES ===
    for chapter_num in "${!chapter_words[@]}"; do
        local word_count=${chapter_words[$chapter_num]}

        if [[ "$word_count" -gt 0 ]]; then
            total_words=$((total_words + word_count))

            if [[ "$word_count" -lt "$min_words" ]]; then
                min_words=$word_count
                min_chapter="Ch$chapter_num"
            fi

            if [[ "$word_count" -gt "$max_words" ]]; then
                max_words=$word_count
                max_chapter="Ch$chapter_num"
            fi
        fi
    done

    local total_chapters=${#chapter_words[@]}

    if [[ $total_chapters -eq 0 ]]; then
        log_warning "Aucun chapitre avec contenu trouvé"
        echo "💡 Ajoutez du contenu après '$MANUSCRIPT_SEPARATOR' dans vos chapitres"
        return
    fi

    log_debug "Statistiques: $total_chapters chapitres, $total_words mots total"

    # === SORTIE SELON FORMAT ===
    case "$output_format" in
        "json")
            output_json_wordcount "$total_words" "$total_chapters" "$target_words" chapter_words chapter_titles chapter_files
            ;;
        "csv")
            output_csv_wordcount chapter_words chapter_titles chapter_files
            ;;
        "summary")
            output_summary_wordcount "$total_words" "$total_chapters" "$target_words" "$min_words" "$max_words" "$min_chapter" "$max_chapter"
            ;;
        *)
            output_detailed_wordcount "$total_words" "$total_chapters" "$target_words" "$show_details" "$show_projections" "$min_words" "$max_words" "$min_chapter" "$max_chapter" "$files_without_separator" chapter_words chapter_titles chapter_files
            ;;
    esac
}

# === SORTIE DÉTAILLÉE ===
output_detailed_wordcount() {
    local total_words="$1"
    local total_chapters="$2"
    local target_words="$3"
    local show_details="$4"
    local show_projections="$5"
    local min_words="$6"
    local max_words="$7"
    local min_chapter="$8"
    local max_chapter="$9"
    local files_without_separator="${10}"
    shift 10
    local -n chap_words=$1
    local -n chap_titles=$2
    local -n chap_files=$3

    # Affichage tableau détaillé
    if [[ "$show_details" == "true" ]]; then
        echo
        echo "┌─────────┬─────────┬───────────────────────────────────────────────────────┐"
        echo "│ CHAPITRE│  MOTS   │ TITRE                                                 │"
        echo "├─────────┼─────────┼───────────────────────────────────────────────────────┤"

        # Tri des chapitres par numéro
        for chapter_num in $(printf '%s\n' "${!chap_words[@]}" | sort -n); do
            local word_count=${chap_words[$chapter_num]}
            local chapter_title=${chap_titles[$chapter_num]}
            local files_list=${chap_files[$chapter_num]}

            # Limiter le titre à 53 caractères
            local title_short=$(echo "$chapter_title" | cut -c1-53)
            if [[ ${#chapter_title} -gt 53 ]]; then
                title_short="${title_short}..."
            fi

            # Indicateur si fichiers multiples
            local chapter_display="Ch$chapter_num"
            if [[ "$files_list" == *","* ]]; then
                chapter_display="Ch$chapter_num+"
            fi

            printf "│  %-6s │ %6s  │ %-53s │\n" "$chapter_display" "$word_count" "$title_short"
        done

        echo "└─────────┴─────────┴───────────────────────────────────────────────────────┘"
        echo "Note: + = chapitre avec fichiers multiples regroupés"
        echo
    fi

    # Statistiques globales
    local avg_words=$((total_words / total_chapters))
    local words_needed=$((target_words - total_words))

    echo "🕷️ SILK ANALYTICS - STATISTIQUES GLOBALES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total chapitres (regroupés)  : $total_chapters"
    echo "Total mots manuscrit          : $total_words"
    echo "Moyenne actuelle/chapitre     : $avg_words mots"
    if [[ "$show_details" == "true" ]]; then
        echo "Chapitre le plus court        : $min_chapter ($min_words mots)"
        echo "Chapitre le plus long         : $max_chapter ($max_words mots)"
    fi
    echo

    # Projections vers objectif
    if [[ "$show_projections" == "true" ]]; then
        show_projections_analysis_silk "$total_words" "$total_chapters" "$target_words" "$words_needed" "$avg_words" chap_words
    fi

    # Position dans les seuils
    show_editorial_positioning_silk "$total_words"

    # Vérification séparateurs
    show_separator_validation "$files_without_separator"

    echo
    echo "🕸️ SILK has analyzed your literary structure comprehensively."
}

# === ANALYSE PROJECTIONS ===
show_projections_analysis_silk() {
    local total_words="$1"
    local total_chapters="$2"
    local target_words="$3"
    local words_needed="$4"
    local avg_words="$5"
    local -n chapters_ref=$6

    if [[ $words_needed -gt 0 ]]; then
        local words_per_chapter=$((words_needed / total_chapters))
        local target_avg=$((target_words / total_chapters))

        echo "🎯 SILK PROJECTIONS - OBJECTIF $target_words MOTS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Objectif configuré            : $target_words mots (~$((target_words / 250)) pages)"
        echo "Mots à ajouter                : $words_needed mots"
        echo "Mots à ajouter/chapitre       : +$words_per_chapter mots"
        echo "Moyenne cible/chapitre        : $target_avg mots"
        echo "Progression nécessaire        : $(( (target_avg * 100) / avg_words ))% de l'actuelle"
        echo

        # Recommandations SILK
        if [[ $words_per_chapter -lt 300 ]]; then
            echo "✅ SILK Évaluation: Objectif très réalisable (+$words_per_chapter mots/chapitre)"
            echo "   💡 Développez les scènes existantes et enrichissez les descriptions"
        elif [[ $words_per_chapter -lt 600 ]]; then
            echo "🟡 SILK Évaluation: Effort modéré (+$words_per_chapter mots/chapitre)"
            echo "   💡 Ajoutez sous-trames et approfondissez le développement personnages"
        elif [[ $words_per_chapter -lt 1000 ]]; then
            echo "🟠 SILK Évaluation: Effort important (+$words_per_chapter mots/chapitre)"
            echo "   💡 Enrichissez dialogues, tensions et développement psychologique"
        else
            echo "🔥 SILK Évaluation: Effort très important (+$words_per_chapter mots/chapitre)"
            echo "   💡 Considérez ajouter de nouveaux chapitres ou réviser l'objectif"
            echo "   🎯 Objectif alternatif: $((total_words + total_chapters * 800)) mots"
        fi

        # Chapitres à développer en priorité
        echo
        echo "🎯 CHAPITRES À DÉVELOPPER EN PRIORITÉ (< moyenne actuelle)"
        for chapter_num in $(printf '%s\n' "${!chapters_ref[@]}" | sort -n); do
            local word_count=${chapters_ref[$chapter_num]}
            if [[ "$word_count" -lt "$avg_words" ]] && [[ "$word_count" -gt 0 ]]; then
                local gap=$((avg_words - word_count))
                local target_gap=$((target_avg - word_count))
                echo "   Ch$chapter_num : $word_count mots (-$gap de la moyenne, -$target_gap de la cible)"
            fi
        done
    else
        echo "🎉 SILK SUCCESS - OBJECTIF ATTEINT !"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Objectif configuré            : $target_words mots"
        echo "Dépassement                   : $((-words_needed)) mots"
        echo "🏆 Félicitations ! Temps de peaufiner et publier avec silk publish"
    fi
}

# === POSITIONNEMENT ÉDITORIAL ===
show_editorial_positioning_silk() {
    local total_words="$1"

    echo
    echo "📖 SILK POSITIONNEMENT - STANDARDS ÉDITORIAUX"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Position actuelle dans les seuils
    local position_info=$(format_position_in_thresholds "$total_words")
    echo "$position_info"

    local current_pages=$((total_words / 250))
    echo "Pages actuelles (~250 mots/page) : $current_pages pages"
    echo

    # Affichage de tous les seuils
    echo "📏 Seuils de référence :"
    for i in "${!THRESHOLDS[@]}"; do
        local threshold=${THRESHOLDS[$i]}
        local label=${THRESHOLD_LABELS[$i]}
        local desc=""
        case "$label" in
            "40k") desc="novella courte" ;;
            "60k") desc="roman court" ;;
            "80k") desc="standard" ;;
            "100k") desc="gros roman" ;;
            "120k") desc="très gros roman" ;;
        esac
        local pages=$((threshold / 250))

        if [[ $total_words -eq $threshold ]]; then
            echo "   🎯 $label mots : $pages pages ($desc) ← VOUS ÊTES ICI"
        elif [[ $total_words -lt $threshold ]]; then
            local gap=$((threshold - total_words))
            echo "   📍 $label mots : $pages pages ($desc) [+$gap mots à écrire]"
        else
            echo "   ✅ $label mots : $pages pages ($desc) [dépassé]"
        fi
    done
}

# === VALIDATION SÉPARATEURS ===
show_separator_validation() {
    local files_without_separator="$1"

    echo
    echo "📋 SILK VÉRIFICATION - SÉPARATEURS ${MANUSCRIPT_SEPARATOR}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ $files_without_separator -eq 0 ]]; then
        echo "✅ Tous les chapitres utilisent le séparateur '$MANUSCRIPT_SEPARATOR'"
        echo "🕸️ Structure SILK conforme pour génération contexte LLM"
    else
        echo "⚠️  $files_without_separator fichier(s) sans séparateur détecté(s)"
        echo "   💡 Ajoutez '$MANUSCRIPT_SEPARATOR' avant le contenu de chaque chapitre"
        echo "   💡 Cela permet d'exclure les métadonnées du comptage et contexte"
        echo "   🔧 Utilisez: silk context pour vérifier la structure"
    fi
}


# === FONCTIONS UTILITAIRES ===
get_base_chapter_number() {
    local filename="$1"
    echo "$filename" | sed 's/.*Ch\([0-9][0-9]*\).*/\1/' | sed 's/^0*//'
}

get_chapter_title() {
    local file="$1"
    head -n1 "$file" | sed 's/^#*\s*//'
}

is_bis_chapter() {
    local filename="$1"
    [[ "$filename" =~ (bis|-[0-9]) ]]
}

extract_silk_manuscrit_content() {
    local file="$1"

    if grep -q "$MANUSCRIPT_SEPARATOR" "$file"; then
        # Extraire contenu après séparateur, en gérant les erreurs
        local content=""
        local found_marker=false

        while IFS= read -r line; do
            if [[ "$line" == *"$MANUSCRIPT_SEPARATOR"* ]]; then
                found_marker=true
                continue
            fi
            if [[ "$found_marker" == true ]] && [[ "$line" != "---" ]]; then
                content+="$line "
            fi
        done < "$file"

        echo "$content" | wc -w
    else
        echo "0"
    fi
}

format_position_in_thresholds() {
    local current_words="$1"
    local result=""

    for i in "${!THRESHOLDS[@]}"; do
        local threshold=${THRESHOLDS[$i]}
        local label=${THRESHOLD_LABELS[$i]}
        local pages=$((threshold / 250))

        if [[ $current_words -le $threshold ]]; then
            if [[ $i -eq 0 ]]; then
                result="📍 Position actuelle : < $label ($pages pages)"
            else
                local prev_threshold=${THRESHOLDS[$((i-1))]}
                local prev_label=${THRESHOLD_LABELS[$((i-1))]}
                local prev_pages=$((prev_threshold / 250))
                result="📍 Position actuelle : entre $prev_label ($prev_pages pages) et $label ($pages pages)"
            fi
            break
        fi
    done

    # Si on dépasse tous les seuils
    if [[ -z "$result" ]]; then
        local max_threshold=${THRESHOLDS[-1]}
        local max_label=${THRESHOLD_LABELS[-1]}
        local max_pages=$((max_threshold / 250))
        result="📍 Position actuelle : > $max_label ($max_pages pages)"
    fi

    echo "$result"
}

# === SORTIE JSON ===
output_json_wordcount() {
    local total_words="$1"
    local total_chapters="$2"
    local target_words="$3"
    local -n chap_words=$4
    local -n chap_titles=$5
    local -n chap_files=$6

    echo "{"
    echo "  \"silk_wordcount\": {"
    echo "    \"version\": \"$SILK_VERSION\","
    echo "    \"timestamp\": \"$(date -Iseconds)\","
    echo "    \"project\": \"$(basename "$PWD")\","
    echo "    \"summary\": {"
    echo "      \"total_words\": $total_words,"
    echo "      \"chapter_count\": $total_chapters,"
    echo "      \"target_words\": $target_words,"
    echo "      \"completion_percentage\": $(( (total_words * 100) / target_words )),"
    echo "      \"average_words_per_chapter\": $((total_words / total_chapters)),"
    echo "      \"estimated_pages\": $((total_words / 250))"
    echo "    },"
    echo "    \"chapters\": ["

    local first=true
    for chapter_num in $(printf '%s\n' "${!chap_words[@]}" | sort -n); do
        local word_count=${chap_words[$chapter_num]}
        local chapter_title=${chap_titles[$chapter_num]}
        local files_list=${chap_files[$chapter_num]}

        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        echo -n "      {\"number\": $chapter_num, \"words\": $word_count, \"title\": \"$chapter_title\", \"files\": \"$files_list\"}"
    done
    echo
    echo "    ]"
    echo "  }"
    echo "}"
}

# === SORTIE CSV ===
output_csv_wordcount() {
    local -n chap_words=$1
    local -n chap_titles=$2
    local -n chap_files=$3

    echo "chapter,words,title,files"
    for chapter_num in $(printf '%s\n' "${!chap_words[@]}" | sort -n); do
        local word_count=${chap_words[$chapter_num]}
        local chapter_title=${chap_titles[$chapter_num]}
        local files_list=${chap_files[$chapter_num]}
        echo "$chapter_num,$word_count,\"$chapter_title\",\"$files_list\""
    done
}

# === SORTIE RÉSUMÉ ===
output_summary_wordcount() {
    local total_words="$1"
    local total_chapters="$2"
    local target_words="$3"
    local min_words="$4"
    local max_words="$5"
    local min_chapter="$6"
    local max_chapter="$7"

    local completion=$((total_words * 100 / target_words))
    local avg_words=$((total_words / total_chapters))

    echo "🕷️ SILK Résumé Progression"
    echo "=========================="
    echo "Total: $total_words/$target_words mots ($completion%)"
    echo "Chapitres: $total_chapters (moyenne: $avg_words mots)"
    echo "Plus court: $min_chapter ($min_words mots)"
    echo "Plus long: $max_chapter ($max_words mots)"
    echo "Pages: ~$((total_words / 250))"
    echo "🕸️ SILK tracks your literary journey."
}

# === EXPORT FONCTIONS ===
export -f cmd_wordcount
export -f show_wordcount_help

# Marquer module comme chargé
readonly SILK_COMMAND_WORDCOUNT_LOADED=true
