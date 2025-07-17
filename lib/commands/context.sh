#!/bin/bash
# lib/commands/context.sh - Commande SILK context (FIXED)

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
readonly CONTEXT_OUTPUT_DIR="outputs/context"
readonly CONTEXT_UNIFIED_FILE="silk-context.md"

# === PROMPTS PRÉDÉFINIS ===
declare -A PREDEFINED_PROMPTS=(
    ["coherence"]="Analyse la cohérence narrative, temporelle et psychologique de ces chapitres. Identifie les incohérences, contradictions ou éléments qui nécessitent une harmonisation."
    ["revision"]="Révise ces chapitres en te concentrant sur l'amélioration du style, du rythme narratif et de la fluidité. Propose des améliorations concrètes pour enrichir le texte."
    ["characters"]="Analyse le développement des personnages dans ces chapitres. Évalue la crédibilité psychologique, l'évolution des arcs narratifs et la cohérence des motivations."
    ["dialogue"]="Examine les dialogues dans ces chapitres. Améliore l'authenticité, la différenciation des voix et l'efficacité narrative des échanges."
    ["plot"]="Analyse la progression de l'intrigue dans ces chapitres. Évalue le rythme, les tensions, les révélations et l'engagement du lecteur."
    ["style"]="Analyse le style d'écriture de ces chapitres. Propose des améliorations pour la voix narrative, les descriptions et l'atmosphère générale."
    ["continuity"]="Vérifie la continuité narrative entre ces chapitres. Identifie les ruptures de rythme, les transitions abruptes ou les éléments manquants."
    ["editing"]="Effectue une révision éditoriale complète de ces chapitres : syntaxe, grammaire, répétitions, clarté et impact."
)

# === FONCTION PRINCIPALE ===
cmd_context() {
    local prompt_text=""
    local prompt_source=""
    local chapter_range="1-30"
    local mode="normal"
    local include_timeline=false
    local include_wordcount=false
    local timeline_file=""
    local backstory_file=""
    local prompt_file="prompt.md"

    # Parser arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                log_info "debug activé ?"
                log_debug "debug activé"
                show_context_help
                return 0
                ;;
            -p|--prompt)
                if [[ $# -lt 2 ]]; then
                    log_error "Option -p/--prompt nécessite un argument"
                    return 1
                fi
                local predefined_key="$2"
                if [[ -n "${PREDEFINED_PROMPTS[$predefined_key]:-}" ]]; then
                    prompt_text="${PREDEFINED_PROMPTS[$predefined_key]}"
                    prompt_source="predefined:$predefined_key"
                    log_debug "Prompt prédéfini: $predefined_key"
                else
                    log_error "Prompt prédéfini inconnu: $predefined_key"
                    echo "💡 Prompts disponibles: ${!PREDEFINED_PROMPTS[*]}"
                    return 1
                fi
                shift 2
                ;;
            --withpromptfile)
                if [[ $# -ge 2 && "$2" != -* ]]; then
                    prompt_file="$2"
                    shift 2
                else
                    # Utiliser prompt.md par défaut
                    shift
                fi

                if [[ -f "$prompt_file" ]]; then
                    prompt_text=$(cat "$prompt_file")
                    prompt_source="file:$prompt_file"
                    log_debug "Prompt depuis fichier: $prompt_file"
                else
                    log_error "Fichier prompt non trouvé: $prompt_file"
                    return 1
                fi
                ;;
            -ch|--chapters)
                if [[ $# -lt 2 ]]; then
                    log_error "Option -ch/--chapters nécessite un argument"
                    return 1
                fi
                chapter_range="$2"
                log_debug "Range chapitres: $chapter_range"
                shift 2
                ;;
            --timeline|-tl)
                include_timeline=true
                if [[ $# -ge 2 && "$2" != -* ]]; then
                    timeline_file="$2"
                    shift 2
                else
                    shift
                fi
                log_debug "Timeline incluse: ${timeline_file:-auto}"
                ;;
            --wordcount|-wc)
                include_wordcount=true
                log_debug "Word count inclus"
                shift
                ;;
            --mode)
                if [[ $# -lt 2 ]]; then
                    log_error "Option --mode nécessite un argument"
                    return 1
                fi
                mode="$2"
                case "$mode" in
                    nocontext|normal|full) ;;
                    *)
                        log_error "Mode invalide: $mode (nocontext, normal, full)"
                        return 1
                        ;;
                esac
                log_debug "Mode contexte: $mode"
                shift 2
                ;;
            --backstory)
                if [[ $# -ge 2 && "$2" != -* ]]; then
                    backstory_file="$2"
                    shift 2
                else
                    # Chercher fichier backstory par défaut
                    shift
                fi
                log_debug "Backstory: ${backstory_file:-auto}"
                ;;
            -*)
                log_error "Option inconnue: $1"
                show_context_help
                return 1
                ;;
            *)
                # Traiter comme prompt direct si pas encore défini
                if [[ -z "$prompt_text" ]]; then
                    prompt_text="$1"
                    prompt_source="direct"
                    log_debug "Prompt direct: $1"
                fi
                shift
                ;;
        esac
    done

    # Valider qu'un prompt est défini
    if [[ -z "$prompt_text" ]]; then
        log_error "Aucun prompt fourni. Utilisez:"
        echo "  silk context \"votre question\""
        echo "  silk context -p coherence"
        echo "  silk context --withpromptfile prompt.md"
        return 1
    fi

    # Vérifier contexte vault
    ensure_silk_context

    # Normaliser le range
    local original_range="$chapter_range"
    chapter_range=$(normalize_chapter_range "$chapter_range")

    if [[ "$original_range" != "$chapter_range" ]]; then
        log_debug "Range normalisé: $original_range -> $chapter_range"
    fi

    # Auto-détection fichiers si non spécifiés
    auto_detect_context_files timeline_file backstory_file

    # Générer contexte unifié
    local start_time=$(start_timer)

    log_info "🕸️ SILK tisse votre contexte unifié..."

    # FIX: Utiliser des chaînes vides pour paramètres optionnels
    generate_unified_context "$prompt_text" "$prompt_source" "$chapter_range" "$mode" "$include_timeline" "$include_wordcount" "${timeline_file:-}" "${backstory_file:-}" "$original_range"

    local duration=$(end_timer "$start_time")

    # Rapport final
    show_unified_report "$mode" "$chapter_range" "$duration" "$prompt_source"

    return 0
}

# === AIDE CONTEXTE ===
show_context_help() {
    cat << 'HELP'
🕸️ SILK CONTEXT - Génération contexte unifié pour LLM

USAGE:
  silk context "votre question"                    # Prompt direct
  silk context -p NOM_PROMPT [OPTIONS]             # Prompt prédéfini
  silk context --withpromptfile [FICHIER] [OPTIONS] # Prompt depuis fichier

OPTIONS PROMPT:
  -p, --prompt NAME             Utiliser prompt prédéfini
  --withpromptfile [FILE]       Prompt depuis fichier (défaut: prompt.md)

OPTIONS CONTENU:
  -ch, --chapters RANGE         Chapitres (ex: 1-4, 20,28,30, all)
  --mode MODE                   Contexte: nocontext|normal|full
  --timeline, -tl [FILE]        Inclure timeline (auto-détection)
  --wordcount, -wc              Inclure statistiques mots
  --backstory [FILE]            Fichier backstory spécifique
  -h, --help                    Afficher cette aide

PROMPTS PRÉDÉFINIS:
  coherence     Analyse cohérence narrative et temporelle
  revision      Révision style et rythme narratif
  characters    Développement et psychologie personnages
  dialogue      Amélioration authenticité des dialogues
  plot          Progression intrigue et tensions
  style         Analyse et amélioration style d'écriture
  continuity    Vérification continuité entre chapitres
  editing       Révision éditoriale complète

MODES CONTEXTE:
  nocontext     Prompt + manuscrit seulement
  normal        + personnages principaux + concepts essentiels
  full          + tous personnages + lieux + worldbuilding + timeline

EXEMPLES:
  silk context "Révise le dialogue d'Emma au chapitre 15"
  silk context -p coherence --chapters 1-10
  silk context -p characters --mode full
  silk context --withpromptfile analyse-complete.md -ch 20,25,30
  silk context --withpromptfile --timeline --wc --mode full

FORMATS CHAPITRES:
  10-15         Range (10, 11, 12, 13, 14, 15)
  28            Chapitre unique
  20,28,30      Liste spécifique
  5,12,18-20    Mixte (5, 12, 18, 19, 20)
  all           Tous les chapitres

FICHIER GÉNÉRÉ:
  outputs/context/silk-context.md    Fichier unifié prêt pour LLM

🕸️ SILK weaves prompt + context + manuscript into one unified file.
HELP
}

# === AUTO-DÉTECTION FICHIERS ===
auto_detect_context_files() {
    local -n timeline_ref=$1
    local -n backstory_ref=$2

    # Auto-détection timeline si non spécifiée
    if [[ -z "$timeline_ref" ]]; then
        local timeline_candidates=(
            "07-timeline/timeline-rebuild-4.md"
            "07-timeline/timeline.md"
            "timeline.md"
            "Timeline.md"
        )

        for candidate in "${timeline_candidates[@]}"; do
            if [[ -f "$candidate" ]]; then
                timeline_ref="$candidate"
                log_debug "Timeline auto-détectée: $candidate"
                break
            fi
        done
    fi

    # Auto-détection backstory si non spécifiée
    if [[ -z "$backstory_ref" ]]; then
        local backstory_candidates=(
            "backstory.md"
            "Backstory.md"
            "04-Concepts/backstory.md"
            "10-Lore/backstory.md"
        )

        for candidate in "${backstory_candidates[@]}"; do
            if [[ -f "$candidate" ]]; then
                backstory_ref="$candidate"
                log_debug "Backstory auto-détectée: $candidate"
                break
            fi
        done
    fi
}

# === GÉNÉRATION CONTEXTE UNIFIÉ ===
generate_unified_context() {
    local prompt_text="$1"
    local prompt_source="$2"
    local chapter_range="$3"
    local mode="$4"
    local include_timeline="$5"
    local include_wordcount="$6"
    local timeline_file="$7"
    local backstory_file="$8"
    local original_range="$9"

    ensure_directory "$CONTEXT_OUTPUT_DIR"

    local output_file="${CONTEXT_OUTPUT_DIR}/${CONTEXT_UNIFIED_FILE}"

    log_info "Génération contexte unifié (mode: $mode, chapitres: $chapter_range)"

    # === 1. HEADER ET PROMPT ===
    {
        echo "# 🕸️ SILK CONTEXTE UNIFIÉ"
        echo
        echo "**Généré le:** $(date '+%d/%m/%Y à %H:%M:%S')"
        echo "**Mode:** $mode"
        echo "**Chapitres:** $chapter_range"
        echo "**Source prompt:** $prompt_source"
        echo
        echo "---"
        echo
        echo "# 📋 PROMPT"
        echo
        echo "$prompt_text"
        echo
        echo "---"
        echo
    } > "$output_file"

    # === 2. CONTEXTE MÉTADONNÉES ===
    if [[ "$mode" != "nocontext" ]]; then
        add_unified_context "$output_file" "$mode" "$chapter_range" "$timeline_file" "$backstory_file"
    fi

    # === 3. MANUSCRIT ===
    add_unified_manuscript "$output_file" "$chapter_range" "$include_timeline" "$include_wordcount" "$timeline_file"

    log_success "Contexte unifié généré: $output_file"
}

# === AJOUT CONTEXTE MÉTADONNÉES ===
add_unified_context() {
    local output_file="$1"
    local mode="$2"
    local chapter_range="$3"
    local timeline_file="$4"
    local backstory_file="$5"

    {
        echo "# 🧠 CONTEXTE PROJET"
        echo
        echo "## 📂 Structure SILK"
        echo "- **01-Manuscrit/**: $(ls 01-Manuscrit/*.md 2>/dev/null | wc -l) chapitres rédigés"
        echo "- **02-Personnages/**: $(find 02-Personnages -name "*.md" 2>/dev/null | wc -l) fiches personnages"
        echo "- **04-Concepts/**: $(ls 04-Concepts/*.md 2>/dev/null | wc -l) mécaniques narratives"
        echo "- **07-timeline/**: $(ls 07-timeline/*.md 2>/dev/null | wc -l) chronologies"
        echo
    } >> "$output_file"

    # Backstory (mode normal et full)
    if [[ "$mode" == "normal" || "$mode" == "full" ]] && [[ -n "$backstory_file" && -f "$backstory_file" ]]; then
        add_backstory_section "$output_file" "$backstory_file"
    fi

    # Concepts (mode normal et full)
    if [[ "$mode" == "normal" || "$mode" == "full" ]]; then
        add_concepts_section "$output_file"
    fi

    # Personnages selon mode
    add_characters_section "$output_file" "$mode"

    # Timeline (mode full seulement)
    if [[ "$mode" == "full" ]] && [[ -n "$timeline_file" && -f "$timeline_file" ]]; then
        add_timeline_section "$output_file" "$timeline_file"
    fi

    # Lieux (mode full seulement)
    if [[ "$mode" == "full" ]]; then
        add_locations_section "$output_file"
    fi

    # Worldbuilding (mode full seulement)
    if [[ "$mode" == "full" ]]; then
        add_worldbuilding_section "$output_file"
    fi

    # Métadonnées chapitres concernés (tous modes)
    add_chapter_metadata_section "$output_file" "$chapter_range"
}

# === AJOUT MANUSCRIT ===
add_unified_manuscript() {
    local output_file="$1"
    local chapter_range="$2"
    local include_timeline="$3"
    local include_wordcount="$4"
    local timeline_file="$5"

    {
        echo "---"
        echo
        echo "# 📖 MANUSCRIT"
        echo
    } >> "$output_file"

    # Timeline si demandée
    if [[ "$include_timeline" == "true" ]] && [[ -n "$timeline_file" && -f "$timeline_file" ]]; then
        add_timeline_to_manuscript "$output_file" "$timeline_file"
    fi

    # Word count si demandé
    if [[ "$include_wordcount" == "true" ]]; then
        add_wordcount_to_manuscript "$output_file"
    fi

    # Contenu chapitres
    {
        echo "## Chapitres sélectionnés"
        echo
    } >> "$output_file"

    extract_chapters_content "$chapter_range" >> "$output_file"
}

# === SECTIONS CONTEXTE ===
add_backstory_section() {
    local output_file="$1"
    local backstory_file="$2"

    {
        echo "## 📚 Backstory"
        echo
        cat "$backstory_file"
        echo
    } >> "$output_file"

    log_debug "Backstory ajoutée: $backstory_file"
}

add_concepts_section() {
    local output_file="$1"

    if [[ $(ls 04-Concepts/*.md 2>/dev/null | wc -l) -gt 0 ]]; then
        echo "## 🧠 Concepts narratifs" >> "$output_file"
        echo >> "$output_file"

        for file in 04-Concepts/*.md; do
            if [[ -f "$file" ]]; then
                {
                    echo "### $(basename "$file" .md)"
                    echo
                    cat "$file"
                    echo
                } >> "$output_file"
            fi
        done
    fi
}

add_characters_section() {
    local output_file="$1"
    local mode="$2"

    echo "## 👥 Personnages" >> "$output_file"
    echo >> "$output_file"

    # Trio principal (tous modes sauf nocontext)
    if [[ "$mode" != "nocontext" ]]; then
        echo "### 🌟 Trio principal" >> "$output_file"
        for file in 02-Personnages/{Emma,Max,Yasmine}.md; do
            if [[ -f "$file" ]]; then
                {
                    echo
                    echo "#### $(basename "$file" .md)"
                    cat "$file"
                    echo
                } >> "$output_file"
            fi
        done
    fi

    # Personnages principaux (mode normal et full)
    if [[ "$mode" == "normal" || "$mode" == "full" ]]; then
        if [[ -d "02-Personnages/Principaux" ]] && [[ $(ls 02-Personnages/Principaux/*.md 2>/dev/null | wc -l) -gt 0 ]]; then
            echo "### 🎯 Personnages principaux" >> "$output_file"
            for file in 02-Personnages/Principaux/*.md; do
                if [[ -f "$file" ]]; then
                    {
                        echo
                        echo "#### $(basename "$file" .md)"
                        cat "$file"
                        echo
                    } >> "$output_file"
                fi
            done
        fi
    fi

    # Personnages secondaires (mode full seulement)
    if [[ "$mode" == "full" ]]; then
        if [[ -d "02-Personnages/Secondaires" ]]; then
            echo "### 👥 Personnages secondaires" >> "$output_file"

            # Parcourir tous les fichiers dans Secondaires/ et ses sous-dossiers
            find 02-Personnages/Secondaires -name "*.md" 2>/dev/null | while read -r file; do
                if [[ -f "$file" ]]; then
                    local relative_path=$(echo "$file" | sed 's|02-Personnages/Secondaires/||')
                    {
                        echo
                        echo "#### $relative_path"
                        cat "$file"
                        echo
                    } >> "$output_file"
                fi
            done
        fi
    fi
}

add_timeline_section() {
    local output_file="$1"
    local timeline_file="$2"

    {
        echo "## 📅 Timeline complète"
        echo
        cat "$timeline_file"
        echo
    } >> "$output_file"

    log_debug "Timeline ajoutée: $timeline_file"
}

add_locations_section() {
    local output_file="$1"

    if [[ $(ls 03-Lieux/*.md 2>/dev/null | wc -l) -gt 0 ]]; then
        echo "## 🗺️ Lieux" >> "$output_file"
        echo >> "$output_file"

        for file in 03-Lieux/*.md; do
            if [[ -f "$file" ]]; then
                {
                    echo "### $(basename "$file" .md)"
                    echo
                    cat "$file"
                    echo
                } >> "$output_file"
            fi
        done
    fi
}

add_worldbuilding_section() {
    local output_file="$1"

    # Worldbuilding pour projets fantasy
    if [[ -d "05-Worldbuilding" ]] && [[ $(ls 05-Worldbuilding/*.md 2>/dev/null | wc -l) -gt 0 ]]; then
        echo "## 🌍 Worldbuilding" >> "$output_file"
        echo >> "$output_file"

        for file in 05-Worldbuilding/*.md; do
            if [[ -f "$file" ]]; then
                {
                    echo "### $(basename "$file" .md)"
                    echo
                    cat "$file"
                    echo
                } >> "$output_file"
            fi
        done
    fi

    # Lore général
    if [[ -d "10-Lore" ]] && [[ $(ls 10-Lore/*.md 2>/dev/null | wc -l) -gt 0 ]]; then
        echo "## 📖 Lore" >> "$output_file"
        echo >> "$output_file"

        for file in 10-Lore/*.md; do
            if [[ -f "$file" ]] && [[ "$(basename "$file")" != "anciens_chapitres" ]]; then
                {
                    echo "### $(basename "$file" .md)"
                    echo
                    cat "$file"
                    echo
                } >> "$output_file"
            fi
        done
    fi
}

add_chapter_metadata_section() {
    local output_file="$1"
    local chapter_range="$2"

    {
        echo "## 📋 Métadonnées chapitres concernés"
        echo
    } >> "$output_file"

    for file in 01-Manuscrit/*.md; do
        if [[ -f "$file" ]] && [[ $(wc -l < "$file") -gt 15 ]]; then
            local chapter_num=$(extract_chapter_number "$file")

            if is_chapter_in_range "$chapter_num" "$chapter_range"; then
                {
                    echo "### $(basename "$file" .md)"
                    echo
                    # Extraire métadonnées (avant marqueur manuscrit)
                    extract_chapter_metadata "$file"
                    echo
                } >> "$output_file"
            fi
        fi
    done
}

add_timeline_to_manuscript() {
    local output_file="$1"
    local timeline_file="$2"

    {
        echo "## 📅 Timeline principale"
        echo
        cat "$timeline_file"
        echo
    } >> "$output_file"

    log_debug "Timeline ajoutée au manuscrit: $timeline_file"
}

add_wordcount_to_manuscript() {
    local output_file="$1"

    {
        echo "## 📊 Statistiques manuscrit"
        echo
        echo '```'

        # CORRECTION: Trouver le chemin vers silk depuis le projet
        local silk_cmd=""
        if [[ -x "../silk" ]]; then
            silk_cmd="../silk"
        elif [[ -x "../../silk" ]]; then
            silk_cmd="../../silk"
        elif command -v silk &> /dev/null; then
            silk_cmd="silk"
        fi

        if [[ -n "$silk_cmd" ]] && is_silk_project; then
            # Utiliser le script SILK wordcount en mode summary
            local wordcount_output
            if wordcount_output=$($silk_cmd wordcount --summary 2>&1); then
                echo "$wordcount_output"
            else
                echo "Erreur lors du calcul des statistiques:"
                echo "$wordcount_output"
            fi
        else
            echo "Statistiques SILK non disponibles"
            echo "Total chapitres manuscrit: $(ls 01-Manuscrit/*.md 2>/dev/null | wc -l)"

            # Calcul simple sans silk
            local total_words=0
            for file in 01-Manuscrit/*.md; do
                if [[ -f "$file" ]] && grep -q "$MANUSCRIPT_SEPARATOR" "$file"; then
                    local words=$(sed -n "/${MANUSCRIPT_SEPARATOR}/,\$p" "$file" | tail -n +2 | wc -w)
                    total_words=$((total_words + words))
                fi
            done
            echo "Total mots approximatif: $total_words"
        fi

        echo '```'
        echo
    } >> "$output_file"

    log_debug "Word count ajouté au manuscrit"
}

# === EXTRACTION CONTENU CHAPITRES ===
extract_chapters_content() {
    local chapter_range="$1"
    local chapters_included=0
    local chapters_excluded=0

    log_debug "Extraction chapitres pour range: $chapter_range"

    # Temporairement désactiver errexit pour cette section
    set +e

    for file in 01-Manuscrit/*.md; do
        if [[ -f "$file" ]] && [[ $(wc -l < "$file") -gt 15 ]]; then
            local chapter_num=$(extract_chapter_number "$file")

            if is_chapter_in_range "$chapter_num" "$chapter_range"; then
                log_debug "✅ INCLUS: $(basename "$file") (Ch$chapter_num)"
                echo "### $(basename "$file" .md)"
                echo
                extract_manuscript_content "$file"
                echo
                ((chapters_included++))
            else
                ((chapters_excluded++))
                log_debug "❌ EXCLU: $(basename "$file") (Ch$chapter_num)"
            fi
        fi
    done

    # Réactiver errexit
    set -e

    log_debug "Chapitres: $chapters_included inclus, $chapters_excluded exclus"

    # Stocker stats pour le rapport
    export SILK_CONTEXT_INCLUDED="$chapters_included"
    export SILK_CONTEXT_EXCLUDED="$chapters_excluded"
}

extract_chapter_metadata() {
    local file="$1"
    local marker="${MANUSCRIPT_SEPARATOR}"

    # Extraire tout ce qui est avant le marqueur manuscrit
    if grep -q "$marker" "$file"; then
        sed "/$marker/,\$d" "$file"
    else
        # Si pas de marqueur, prendre le header seulement
        head -20 "$file"
    fi
}

# === RAPPORT FINAL ===
show_unified_report() {
    local mode="$1"
    local chapter_range="$2"
    local duration="$3"
    local prompt_source="$4"

    local included="${SILK_CONTEXT_INCLUDED:-0}"
    local excluded="${SILK_CONTEXT_EXCLUDED:-0}"
    local output_file="${CONTEXT_OUTPUT_DIR}/${CONTEXT_UNIFIED_FILE}"

    echo
    log_success "🕸️ Contexte unifié généré en $duration"

    echo
    echo "📊 RÉSUMÉ:"
    echo "   📋 Prompt: $prompt_source"
    echo "   🎯 Mode: $mode"
    echo "   📖 Range: $chapter_range"
    echo "   ✅ Chapitres inclus: $included"
    echo "   ❌ Chapitres exclus: $excluded"

    if [[ -f "$output_file" ]]; then
        local total_words=$(wc -w < "$output_file")
        local total_lines=$(wc -l < "$output_file")
        echo "   📄 Taille: $total_words mots, $total_lines lignes"
    fi

    echo
    echo "📁 FICHIER GÉNÉRÉ:"
    echo "   🕸️ $output_file"
    echo
    echo "💡 UTILISATION:"
    echo "   📋 Copiez tout le contenu dans votre LLM"
    echo "   🤖 Le prompt, contexte et manuscrit sont unifiés"
    echo "   ⚡ Prêt pour interaction directe"

    if [[ "$chapter_range" == *","* ]]; then
        echo
        echo "🎯 CHAPITRES SÉLECTIONNÉS:"
        echo "   $(echo "$chapter_range" | tr ',' ' ')"
    fi

    echo
    echo "🕸️ SILK has woven everything into one perfect file for your LLM!"
}

# === EXPORT FONCTIONS ===
export -f cmd_context
export -f show_context_help

# Marquer module comme chargé
readonly SILK_COMMAND_CONTEXT_LOADED=true
