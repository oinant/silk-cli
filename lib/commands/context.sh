#!/bin/bash
# lib/commands/context.sh - Commande SILK context (version unifiée)

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
    local prompt_file="prompt.md"

    # Vérifier contexte vault
    ensure_silk_context

    # Parser arguments pour détecter le mode prompt
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_context_help
                return 0
                ;;
            -p|--prompt)
                local predefined_key="$2"
                if [[ -n "${PREDEFINED_PROMPTS[$predefined_key]}" ]]; then
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
                if [[ -n "$2" && "$2" != -* ]]; then
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
                chapter_range="$2"
                log_debug "Range chapitres: $chapter_range"
                shift 2
                ;;
            --full)
                mode="full"
                chapter_range="all"
                log_debug "Mode full activé"
                shift
                ;;
            --timeline)
                include_timeline=true
                log_debug "Timeline incluse"
                shift
                ;;
            --wc|--wordcount)
                include_wordcount=true
                log_debug "Word count inclus"
                shift
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

    # Normaliser le range
    local original_range="$chapter_range"
    chapter_range=$(normalize_chapter_range "$chapter_range")

    if [[ "$original_range" != "$chapter_range" ]]; then
        log_debug "Range normalisé: $original_range -> $chapter_range"
    fi

    # Générer contexte unifié
    local start_time=$(start_timer)

    log_info "🕸️ SILK tisse votre contexte unifié..."

    generate_unified_context "$prompt_text" "$prompt_source" "$chapter_range" "$mode" "$include_timeline" "$include_wordcount" "$original_range"

    local duration=$(end_timer "$start_time")

    # Rapport final
    show_unified_report "$mode" "$chapter_range" "$duration" "$prompt_source"
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
  --full                        Mode complet (tous éléments)
  --timeline                    Inclure timeline
  --wc, --wordcount            Inclure statistiques mots
  -h, --help                   Afficher cette aide

PROMPTS PRÉDÉFINIS:
  coherence     Analyse cohérence narrative et temporelle
  revision      Révision style et rythme narratif
  characters    Développement et psychologie personnages
  dialogue      Amélioration authenticité des dialogues
  plot          Progression intrigue et tensions
  style         Analyse et amélioration style d'écriture
  continuity    Vérification continuité entre chapitres
  editing       Révision éditoriale complète

EXEMPLES:
  silk context "Révise le dialogue d'Emma au chapitre 15"
  silk context -p coherence --chapters 1-10
  silk context -p characters --full
  silk context --withpromptfile analyse-complete.md -ch 20,25,30
  silk context --withpromptfile --timeline --wc

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

# === GÉNÉRATION CONTEXTE UNIFIÉ ===
generate_unified_context() {
    local prompt_text="$1"
    local prompt_source="$2"
    local chapter_range="$3"
    local mode="$4"
    local include_timeline="$5"
    local include_wordcount="$6"
    local original_range="$7"

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
    add_unified_context "$output_file" "$mode" "$chapter_range"

    # === 3. MANUSCRIT ===
    add_unified_manuscript "$output_file" "$chapter_range" "$include_timeline" "$include_wordcount"

    log_success "Contexte unifié généré: $output_file"
}

# === AJOUT CONTEXTE MÉTADONNÉES ===
add_unified_context() {
    local output_file="$1"
    local mode="$2"
    local chapter_range="$3"

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

    # Concepts
    add_concepts_section "$output_file"

    # Personnages selon mode
    add_characters_section "$output_file" "$mode"

    # Timeline
    add_timeline_section "$output_file" "$mode"

    # Lieux si mode full
    if [[ "$mode" == "full" ]]; then
        add_locations_section "$output_file"
    fi

    # Métadonnées chapitres concernés
    add_chapter_metadata_section "$output_file" "$chapter_range"
}

# === AJOUT MANUSCRIT ===
add_unified_manuscript() {
    local output_file="$1"
    local chapter_range="$2"
    local include_timeline="$3"
    local include_wordcount="$4"

    {
        echo "---"
        echo
        echo "# 📖 MANUSCRIT"
        echo
    } >> "$output_file"

    # Timeline si demandée
    if [[ "$include_timeline" == "true" ]]; then
        add_timeline_to_manuscript "$output_file"
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

    # Trio principal
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

    # Personnages principaux
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

    # Personnages secondaires (mode full seulement)
    if [[ "$mode" == "full" ]]; then
        if [[ -d "02-Personnages/Secondaires" ]]; then
            echo "### 👥 Personnages secondaires" >> "$output_file"

            # Parcourir tous les fichiers dans Secondaires/ et ses sous-dossiers
            find 02-Personnages/Secondaires -name "*.md" | while read -r file; do
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
    local mode="$2"

    if [[ $(ls 07-timeline/*.md 2>/dev/null | wc -l) -gt 0 ]]; then
        echo "## 📅 Timeline" >> "$output_file"
        echo >> "$output_file"

        for file in 07-timeline/*.md; do
            if [[ -f "$file" ]]; then
                # En mode normal, exclure tome 2
                if [[ "$mode" == "normal" ]] && [[ "$(basename "$file")" == *"tome 2"* ]]; then
                    continue
                fi

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

    if [[ -f "07-timeline/timeline-rebuild-4.md" ]]; then
        {
            echo "## 📅 Timeline principale"
            echo
            cat "07-timeline/timeline-rebuild-4.md"
            echo
        } >> "$output_file"
        log_debug "Timeline ajoutée au manuscrit"
    fi
}

add_wordcount_to_manuscript() {
    local output_file="$1"

    {
        echo "## 📊 Statistiques manuscrit"
        echo
        echo '```'

        # Utiliser silk wordcount si disponible
        if command -v silk &> /dev/null; then
            silk wordcount --summary 2>/dev/null || echo "Erreur calcul statistiques"
        else
            echo "Statistiques non disponibles"
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
            fi
        fi
    done

    log_debug "Chapitres: $chapters_included inclus, $chapters_excluded exclus"

    # Stocker stats pour le rapport
    export SILK_CONTEXT_INCLUDED="$chapters_included"
    export SILK_CONTEXT_EXCLUDED="$chapters_excluded"
}

extract_chapter_metadata() {
    local file="$1"
    local marker="${VAULT_MARKER:-## manuscrit}"

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
