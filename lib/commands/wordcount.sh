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

# === FONCTION PRINCIPALE ===
cmd_wordcount() {
    ensure_silk_context
    
    local target_words="${SILK_DEFAULT_TARGET_WORDS:-80000}"
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
  
SILK analyse intelligemment votre progression.
HELP
}

# === ANALYSE PRINCIPALE ===
analyze_silk_wordcount() {
    local target_words="$1"
    local show_details="$2"
    local show_projections="$3"
    local output_format="$4"
    
    local total_words=0
    local chapter_count=0
    local min_words=999999
    local max_words=0
    local min_chapter=""
    local max_chapter=""
    local chapter_data=()
    
    # Collecte des données
    for file in 01-Manuscrit/Ch*.md; do
        if [[ -f "$file" ]]; then
            local chapter_name=$(basename "$file" .md)
            local chapter_title=$(head -n1 "$file" | sed 's/^#*\s*//')
            
            # Extraire contenu après "## manuscrit"
            local words=0
            if grep -q "$VAULT_MARKER" "$file"; then
                words=$(extract_manuscript_content "$file" | wc -w)
            fi
            
            if [[ $words -gt 0 ]]; then
                ((chapter_count++))
                total_words=$((total_words + words))
                
                chapter_data+=("$chapter_name:$words:$chapter_title")
                
                if [[ $words -lt $min_words ]]; then
                    min_words=$words
                    min_chapter="$chapter_name"
                fi
                
                if [[ $words -gt $max_words ]]; then
                    max_words=$words
                    max_chapter="$chapter_name"
                fi
            fi
        fi
    done
    
    if [[ $chapter_count -eq 0 ]]; then
        log_warning "Aucun chapitre avec contenu trouvé"
        echo "💡 Ajoutez du contenu après '$VAULT_MARKER' dans vos chapitres"
        return
    fi
    
    # Sortie selon le format
    case "$output_format" in
        "json")
            output_json "$total_words" "$chapter_count" "$target_words" "${chapter_data[@]}"
            ;;
        "csv")
            output_csv "${chapter_data[@]}"
            ;;
        "summary")
            output_summary "$total_words" "$chapter_count" "$target_words" "$min_words" "$max_words" "$min_chapter" "$max_chapter"
            ;;
        *)
            output_detailed "$total_words" "$chapter_count" "$target_words" "$show_details" "$show_projections" "$min_words" "$max_words" "$min_chapter" "$max_chapter" "${chapter_data[@]}"
            ;;
    esac
}

# === SORTIE DÉTAILLÉE ===
output_detailed() {
    local total_words="$1"
    local chapter_count="$2"
    local target_words="$3"
    local show_details="$4"
    local show_projections="$5"
    local min_words="$6"
    local max_words="$7"
    local min_chapter="$8"
    local max_chapter="$9"
    shift 9
    local chapter_data=("$@")
    
    # Affichage détaillé
    if [[ "$show_details" == "true" ]]; then
        echo
        echo "┌─────────┬─────────┬───────────────────────────────────────────────────────┐"
        echo "│ CHAPITRE│  MOTS   │ TITRE                                                 │"
        echo "├─────────┼─────────┼───────────────────────────────────────────────────────┤"
        
        for data in "${chapter_data[@]}"; do
            IFS=':' read -r chapter_name words chapter_title <<< "$data"
            
            # Tronquer titre si trop long
            local display_title="${chapter_title:0:53}"
            if [[ ${#chapter_title} -gt 53 ]]; then
                display_title="${display_title}..."
            fi
            
            printf "│  %-6s │ %6s  │ %-53s │\n" "$chapter_name" "$words" "$display_title"
        done
        
        echo "└─────────┴─────────┴───────────────────────────────────────────────────────┘"
        echo
    fi
    
    # Statistiques globales
    local avg_words=$((total_words / chapter_count))
    local words_needed=$((target_words - total_words))
    
    echo "🕷️ SILK ANALYTICS - STATISTIQUES GLOBALES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total chapitres écrits    : $chapter_count"
    echo "Total mots manuscrit      : $total_words"
    echo "Moyenne actuelle/chapitre : $avg_words mots"
    if [[ "$show_details" == "true" ]]; then
        echo "Chapitre le plus court    : $min_chapter ($min_words mots)"
        echo "Chapitre le plus long     : $max_chapter ($max_words mots)"
    fi
    echo
    
    # Projections vers objectif
    if [[ "$show_projections" == "true" ]]; then
        show_projections_analysis "$total_words" "$chapter_count" "$target_words" "$words_needed"
    fi
    
    # Position dans les seuils
    show_editorial_positioning "$total_words"
}

# === ANALYSE PROJECTIONS ===
show_projections_analysis() {
    local total_words="$1"
    local chapter_count="$2"
    local target_words="$3"
    local words_needed="$4"
    
    if [[ $words_needed -gt 0 ]]; then
        local words_per_chapter=$((words_needed / chapter_count))
        local target_avg=$((target_words / chapter_count))
        local current_pages=$((total_words / 250))
        local target_pages=$((target_words / 250))
        
        echo "🎯 SILK PROJECTIONS - OBJECTIF $target_words MOTS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Objectif configuré        : $target_words mots (~$target_pages pages)"
        echo "Mots à ajouter            : $words_needed mots"
        echo "Mots à ajouter/chapitre   : +$words_per_chapter mots"
        echo "Moyenne cible/chapitre    : $target_avg mots"
        echo
        
        # Recommandations SILK
        if [[ $words_per_chapter -lt 300 ]]; then
            echo "✅ SILK Évaluation: Objectif très réalisable (+$words_per_chapter mots/chapitre)"
            echo "   💡 Suggestion: Développez les scènes existantes"
        elif [[ $words_per_chapter -lt 600 ]]; then
            echo "🟡 SILK Évaluation: Effort modéré (+$words_per_chapter mots/chapitre)"
            echo "   💡 Suggestion: Ajoutez sous-trames et développement personnages"
        elif [[ $words_per_chapter -lt 1000 ]]; then
            echo "🟠 SILK Évaluation: Effort important (+$words_per_chapter mots/chapitre)"
            echo "   💡 Suggestion: Enrichissez descriptions et dialogues"
        else
            echo "🔥 SILK Évaluation: Effort très important (+$words_per_chapter mots/chapitre)"
            echo "   💡 Suggestion: Considérez ajouter de nouveaux chapitres"
            echo "   🎯 Alternative: Révisez l'objectif à $((total_words + chapter_count * 800)) mots"
        fi
    else
        echo "🎉 SILK SUCCESS - OBJECTIF ATTEINT !"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Objectif configuré        : $target_words mots"
        echo "Dépassement               : $((-words_needed)) mots"
        echo "🏆 Félicitations ! Temps de peaufiner et publier."
    fi
}

# === POSITIONNEMENT ÉDITORIAL ===
show_editorial_positioning() {
    local total_words="$1"
    
    echo
    echo "📖 SILK POSITIONNEMENT - STANDARDS ÉDITORIAUX"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local current_pages=$((total_words / 250))
    echo "Pages actuelles (~250 mots/page) : $current_pages pages"
    echo
    
    # Seuils de référence avec positionnement
    local thresholds=(40000 60000 80000 100000 120000)
    local labels=("40k" "60k" "80k" "100k" "120k")
    local descriptions=("Novella courte" "Roman court" "Standard" "Gros roman" "Très gros roman")
    
    for i in "${!thresholds[@]}"; do
        local threshold=${thresholds[$i]}
        local label=${labels[$i]}
        local desc=${descriptions[$i]}
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
    
    echo
    echo "🕸️ SILK weaves your progress into literary success."
}

# === SORTIE JSON ===
output_json() {
    local total_words="$1"
    local chapter_count="$2"
    local target_words="$3"
    shift 3
    local chapter_data=("$@")
    
    echo "{"
    echo "  \"silk_wordcount\": {"
    echo "    \"version\": \"$SILK_VERSION\","
    echo "    \"timestamp\": \"$(date -Iseconds)\","
    echo "    \"project\": \"$(basename "$PWD")\","
    echo "    \"summary\": {"
    echo "      \"total_words\": $total_words,"
    echo "      \"chapter_count\": $chapter_count,"
    echo "      \"target_words\": $target_words,"
    echo "      \"completion_percentage\": $(( (total_words * 100) / target_words )),"
    echo "      \"average_words_per_chapter\": $((total_words / chapter_count)),"
    echo "      \"estimated_pages\": $((total_words / 250))"
    echo "    },"
    echo "    \"chapters\": ["
    
    local first=true
    for data in "${chapter_data[@]}"; do
        IFS=':' read -r chapter_name words chapter_title <<< "$data"
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        echo -n "      {\"name\": \"$chapter_name\", \"words\": $words, \"title\": \"$chapter_title\"}"
    done
    echo
    echo "    ]"
    echo "  }"
    echo "}"
}

# === SORTIE CSV ===
output_csv() {
    local chapter_data=("$@")
    
    echo "chapter,words,title"
    for data in "${chapter_data[@]}"; do
        IFS=':' read -r chapter_name words chapter_title <<< "$data"
        echo "$chapter_name,$words,\"$chapter_title\""
    done
}

# === SORTIE RÉSUMÉ ===
output_summary() {
    local total_words="$1"
    local chapter_count="$2"
    local target_words="$3"
    local min_words="$4"
    local max_words="$5"
    local min_chapter="$6"
    local max_chapter="$7"
    
    local completion=$((total_words * 100 / target_words))
    local avg_words=$((total_words / chapter_count))
    
    echo "🕷️ SILK Résumé Progression"
    echo "=========================="
    echo "Total: $total_words/$target_words mots ($completion%)"
    echo "Chapitres: $chapter_count (moyenne: $avg_words mots)"
    echo "Plus court: $min_chapter ($min_words mots)"
    echo "Plus long: $max_chapter ($max_words mots)"
    echo "Pages: ~$((total_words / 250))"
    echo "🕸️ SILK tracks your literary journey."
}

# === EXPORT FONCTIONS ===
export -f cmd_wordcount
export -f show_wordcount_help
export -f analyze_silk_wordcount

# Marquer module comme chargé
readonly SILK_COMMAND_WORDCOUNT_LOADED=true