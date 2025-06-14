#!/bin/bash
# lib/commands/context.sh - Commande SILK context

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
readonly CONTEXT_MANUSCRIT_FILE="manuscrit.md"
readonly CONTEXT_SHARED_FILE="sharedcontext.md"

# === FONCTION PRINCIPALE ===
cmd_context() {
    local question="Analyse générale"
    local chapter_range="1-30"
    local mode="normal"
    local include_timeline=false
    local include_wordcount=false
    local include_sharedcontext=true
    local timeline_only=false
    
    # Vérifier contexte vault
    ensure_vault_context
    
    # Parser arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_context_help
                return 0
                ;;
            -ch|--chapters)
                chapter_range="$2"
                log_debug "Range chapitres: $chapter_range"
                shift 2
                ;;
            --full)
                mode="full"
                chapter_range="all"  # En mode full, tous les chapitres
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
            --no-metadata)
                include_sharedcontext=false
                log_debug "Métadonnées désactivées"
                shift
                ;;
            --timeline-only)
                timeline_only=true
                include_sharedcontext=false
                log_debug "Mode timeline seul"
                shift
                ;;
            -*)
                log_error "Option inconnue: $1"
                show_context_help
                return 1
                ;;
            *)
                if [[ "$timeline_only" == "false" ]]; then
                    question="$1"
                    log_debug "Question: $question"
                fi
                shift
                ;;
        esac
    done
    
    # Normaliser le range
    local original_range="$chapter_range"
    chapter_range=$(normalize_chapter_range "$chapter_range")
    
    if [[ "$original_range" != "$chapter_range" ]]; then
        log_debug "Range normalisé: $original_range -> $chapter_range"
    fi
    
    # Générer contexte
    local start_time=$(start_timer)
    
    if [[ "$timeline_only" == "true" ]]; then
        generate_timeline_only "$chapter_range"
    else
        generate_full_context "$question" "$chapter_range" "$mode" "$include_timeline" "$include_wordcount" "$include_sharedcontext"
    fi
    
    local duration=$(end_timer "$start_time")
    
    # Rapport final
    show_context_report "$mode" "$chapter_range" "$duration" "$include_sharedcontext"
}

# === AIDE CONTEXTE ===
show_context_help() {
    cat << 'HELP'
📚 SILK CONTEXT - Génération contexte pour LLM

USAGE:
  silk context [QUESTION] [OPTIONS]

OPTIONS:
  -ch, --chapters RANGE     Chapitres (ex: 1-4, 20,28,30, all)
  --full                    Mode complet (tous éléments)
  --timeline                Inclure timeline dans manuscrit
  --wc, --wordcount         Inclure statistiques mots
  --no-metadata             Manuscrit seul (pas de métadonnées)
  --timeline-only           Timeline extraction uniquement
  -h, --help                Afficher cette aide

EXEMPLES:
  silk context "Révision chapitre 15"
  silk context --chapters 1-10 --full
  silk context --timeline --wc
  silk context "Stats progression" --wc --no-metadata
  silk context --timeline-only --chapters 20-25

MODES:
  normal    Chapitres + personnages principaux + concepts
  --full    + personnages secondaires + lieux + statistiques

FORMATS CHAPITRES:
  10-15     Range de chapitres (10, 11, 12, 13, 14, 15)
  28        Chapitre unique (28)
  20,28,30  Liste spécifique (20, 28, 30)
  5,12,18-20   Mixte: chapitres + range (5, 12, 18, 19, 20)
  all       Tous les chapitres disponibles

FICHIERS GÉNÉRÉS:
  outputs/context/manuscrit.md      Texte des chapitres
  outputs/context/sharedcontext.md  Métadonnées (sauf --no-metadata)
HELP
}

# === GÉNÉRATION TIMELINE SEULE ===
generate_timeline_only() {
    local chapter_range="$1"
    
    log_info "Extraction timeline uniquement (chapitres: $chapter_range)"
    
    ensure_directory "$CONTEXT_OUTPUT_DIR"
    
    local output_file="${CONTEXT_OUTPUT_DIR}/${CONTEXT_MANUSCRIT_FILE}"
    
    # Header timeline
    {
        echo "# Timeline Extraction - Chapitres $chapter_range"
        echo
        echo "**Généré le:** $(date '+%d/%m/%Y à %H:%M:%S')"
        echo "**Chapitres:** $chapter_range"
        echo
        echo "---"
        echo
    } > "$output_file"
    
    # Extraire chapitres selon range
    extract_chapters_content "$chapter_range" >> "$output_file"
    
    log_success "Timeline extraite dans: $output_file"
}

# === GÉNÉRATION CONTEXTE COMPLET ===
generate_full_context() {
    local question="$1"
    local chapter_range="$2" 
    local mode="$3"
    local include_timeline="$4"
    local include_wordcount="$5"
    local include_sharedcontext="$6"
    
    log_info "Génération contexte LLM (mode: $mode, chapitres: $chapter_range)"
    
    ensure_directory "$CONTEXT_OUTPUT_DIR"
    
    # Générer manuscrit.md
    generate_manuscrit_file "$question" "$chapter_range" "$include_timeline" "$include_wordcount"
    
    # Générer sharedcontext.md si demandé
    if [[ "$include_sharedcontext" == "true" ]]; then
        generate_sharedcontext_file "$question" "$chapter_range" "$mode"
    fi
}

# === GÉNÉRATION MANUSCRIT ===
generate_manuscrit_file() {
    local question="$1"
    local chapter_range="$2"
    local include_timeline="$3"
    local include_wordcount="$4"
    
    local output_file="${CONTEXT_OUTPUT_DIR}/${CONTEXT_MANUSCRIT_FILE}"
    
    log_debug "Génération $output_file"
    
    # Header manuscrit
    {
        echo "# Manuscrit - Version Publication"
        echo
        echo "**Question:** $question"
        echo "**Chapitres:** $chapter_range"
        echo "**Généré le:** $(date '+%d/%m/%Y à %H:%M:%S')"
        echo
        echo "---"
        echo
    } > "$output_file"
    
    # Timeline si demandée
    if [[ "$include_timeline" == "true" ]]; then
        add_timeline_to_manuscrit "$output_file"
    fi
    
    # Word count si demandé
    if [[ "$include_wordcount" == "true" ]]; then
        add_wordcount_to_manuscrit "$output_file"
    fi
    
    # Contenu chapitres
    extract_chapters_content "$chapter_range" >> "$output_file"
}

# === GÉNÉRATION SHAREDCONTEXT ===
generate_sharedcontext_file() {
    local question="$1"
    local chapter_range="$2"
    local mode="$3"
    
    local output_file="${CONTEXT_OUTPUT_DIR}/${CONTEXT_SHARED_FILE}"
    
    log_debug "Génération $output_file"
    
    # Header métadonnées
    {
        echo "# Contexte Métadonnées"
        echo
        echo "**Question:** $question"
        echo "**Mode:** $mode"
        echo "**Chapitres:** $chapter_range"
        echo "**Généré le:** $(date '+%d/%m/%Y à %H:%M:%S')"
        echo
        
        if [[ "$mode" == "normal" ]]; then
            echo "⚠️ **MODE NORMAL** - Exclusions pour optimiser:"
            echo "- Personnages secondaires"
            echo "- Descriptions de lieux"
            echo "- Utilisez \`--full\` pour accès complet"
            echo
        fi
        
        echo "---"
        echo
    } > "$output_file"
    
    # Concepts (toujours inclus)
    add_concepts_to_context "$output_file"
    
    # Timeline
    add_timeline_files_to_context "$output_file" "$mode"
    
    # Personnages selon mode
    add_characters_to_context "$output_file" "$mode"
    
    # Lieux (mode full seulement)
    if [[ "$mode" == "full" ]]; then
        add_locations_to_context "$output_file"
    fi
    
    # Métadonnées chapitres
    add_chapter_metadata_to_context "$output_file" "$chapter_range"
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
                log_debug "Inclusion: $(basename "$file") (Ch$chapter_num)"
                echo "## $(basename "$file" .md)"
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

# === AJOUT TIMELINE ===
add_timeline_to_manuscrit() {
    local output_file="$1"
    
    if [[ -f "07-timeline/timeline-rebuild-4.md" ]]; then
        {
            echo "## 📅 Timeline Principale"
            echo
            cat "07-timeline/timeline-rebuild-4.md"
            echo
            echo "---"
            echo
        } >> "$output_file"
        log_debug "Timeline ajoutée au manuscrit"
    else
        log_warning "Timeline non trouvée: 07-timeline/timeline-rebuild-4.md"
    fi
}

# === AJOUT WORD COUNT ===
add_wordcount_to_manuscrit() {
    local output_file="$1"
    
    {
        echo "## 📊 Statistiques du Manuscrit"
        echo
        echo '```'
        
        # Exécuter module wordcount en mode silencieux
        if [[ -f "${SILK_LIB_DIR}/commands/wordcount.sh" ]]; then
            bash "${SILK_LIB_DIR}/commands/wordcount.sh" --silent 2>/dev/null || echo "Erreur calcul statistiques"
        else
            echo "Module wordcount non disponible"
        fi
        
        echo '```'
        echo
        echo "---"
        echo
    } >> "$output_file"
    
    log_debug "Word count ajouté au manuscrit"
}

# === AJOUT ÉLÉMENTS CONTEXTE ===
add_concepts_to_context() {
    local output_file="$1"
    
    echo "## 🧠 CONCEPTS" >> "$output_file"
    
    for file in 04-Concepts/*.md; do
        if [[ -f "$file" ]]; then
            {
                echo
                echo "### 📄 $(basename "$file" .md | tr '[:lower:]' '[:upper:]')"
                cat "$file"
                echo
            } >> "$output_file"
        fi
    done
}

add_timeline_files_to_context() {
    local output_file="$1"
    local mode="$2"
    
    echo "## 📅 TIMELINE" >> "$output_file"
    
    for file in 07-timeline/*.md; do
        if [[ -f "$file" ]]; then
            # En mode normal, exclure tome 2
            if [[ "$mode" == "normal" ]] && [[ "$(basename "$file")" == *"tome 2"* ]]; then
                continue
            fi
            
            {
                echo
                echo "### 📄 $(basename "$file" .md | tr '[:lower:]' '[:upper:]')"
                cat "$file"
                echo
            } >> "$output_file"
        fi
    done
}

add_characters_to_context() {
    local output_file="$1"
    local mode="$2"
    
    echo "## 👥 PERSONNAGES" >> "$output_file"
    
    # Trio principal (toujours)
    echo "### 🌟 TRIO PRINCIPAL" >> "$output_file"
    for file in 02-Personnages/{Emma,Max,Yasmine}.md; do
        if [[ -f "$file" ]]; then
            {
                echo
                echo "#### 📄 $(basename "$file" .md | tr '[:lower:]' '[:upper:]')"
                cat "$file"
                echo
            } >> "$output_file"
        fi
    done
    
    # Personnages principaux (toujours)
    echo "### 🎯 PERSONNAGES PRINCIPAUX" >> "$output_file"
    for file in 02-Personnages/Principaux/*.md; do
        if [[ -f "$file" ]]; then
            {
                echo
                echo "#### 📄 $(basename "$file" .md | tr '[:lower:]' '[:upper:]')"
                cat "$file"
                echo
            } >> "$output_file"
        fi
    done
    
    # Personnages secondaires (mode full seulement)
    if [[ "$mode" == "full" ]]; then
        echo "### 👥 PERSONNAGES SECONDAIRES" >> "$output_file"
        
        # Bad guys
        echo "#### 💀 ANTAGONISTES" >> "$output_file"
        for file in 02-Personnages/Secondaires/Bad\ guys/*.md; do
            if [[ -f "$file" ]]; then
                {
                    echo
                    echo "##### 📄 $(basename "$file" .md | tr '[:lower:]' '[:upper:]')"
                    cat "$file"
                    echo
                } >> "$output_file"
            fi
        done

        # Flics
        echo "#### 👮 FORCES DE L'ORDRE" >> "$output_file"
        for file in 02-Personnages/Secondaires/Flics/*.md; do
            if [[ -f "$file" ]]; then
                {
                    echo
                    echo "##### 📄 $(basename "$file" .md | tr '[:lower:]' '[:upper:]')"
                    cat "$file"
                    echo
                } >> "$output_file"
            fi
        done

        # Autres secondaires
        echo "#### 👥 AUTRES SECONDAIRES" >> "$output_file"
        for file in 02-Personnages/Secondaires/*.md; do
            if [[ -f "$file" ]]; then
                {
                    echo
                    echo "##### 📄 $(basename "$file" .md | tr '[:lower:]' '[:upper:]')"
                    cat "$file"
                    echo
                } >> "$output_file"
            fi
        done
    fi
}

add_locations_to_context() {
    local output_file="$1"
    
    echo "## 🗺️ LIEUX" >> "$output_file"
    for file in 03-Lieux/*.md; do
        if [[ -f "$file" ]]; then
            {
                echo
                echo "### 📄 $(basename "$file" .md | tr '[:lower:]' '[:upper:]')"
                cat "$file"
                echo
            } >> "$output_file"
        fi
    done
}

add_chapter_metadata_to_context() {
    local output_file="$1"
    local chapter_range="$2"
    
    echo "## 📋 METADATA CHAPITRES" >> "$output_file"
    
    for file in 01-Manuscrit/*.md; do
        if [[ -f "$file" ]] && [[ $(wc -l < "$file") -gt 15 ]]; then
            local chapter_num=$(extract_chapter_number "$file")
            
            # Vérifier le range pour les métadonnées aussi
            if is_chapter_in_range "$chapter_num" "$chapter_range"; then
                {
                    echo
                    echo "### 📄 $(basename "$file" .md)"
                    
                    # Extraire métadonnées (avant le marqueur manuscrit)
                    extract_chapter_metadata "$file"
                    echo
                } >> "$output_file"
            fi
        fi
    done
}

extract_chapter_metadata() {
    local file="$1"
    local marker="## manuscrit"
    
    # Extraire tout ce qui est avant le marqueur manuscrit
    if grep -q "$marker" "$file"; then
        sed "/$marker/,\$d" "$file"
    else
        # Si pas de marqueur, prendre tout le fichier
        cat "$file"
    fi
}

# === RAPPORT FINAL ===
show_context_report() {
    local mode="$1"
    local chapter_range="$2"
    local duration="$3"
    local include_sharedcontext="$4"
    
    local included="${SILK_CONTEXT_INCLUDED:-0}"
    local excluded="${SILK_CONTEXT_EXCLUDED:-0}"
    
    echo
    log_success "Génération terminée en $duration"
    
    echo
    echo "📊 RÉSULTATS:"
    echo "   - Mode: $mode"
    echo "   - Range: $chapter_range"
    echo "   - Chapitres inclus: $included"
    echo "   - Chapitres exclus: $excluded"
    echo
    
    echo "📁 FICHIERS GÉNÉRÉS:"
    if [[ -f "${CONTEXT_OUTPUT_DIR}/${CONTEXT_MANUSCRIT_FILE}" ]]; then
        local manuscrit_words=$(wc -w < "${CONTEXT_OUTPUT_DIR}/${CONTEXT_MANUSCRIT_FILE}")
        echo "   📖 manuscrit.md: $manuscrit_words mots"
    fi
    
    if [[ "$include_sharedcontext" == "true" ]] && [[ -f "${CONTEXT_OUTPUT_DIR}/${CONTEXT_SHARED_FILE}" ]]; then
        local context_words=$(wc -w < "${CONTEXT_OUTPUT_DIR}/${CONTEXT_SHARED_FILE}")
        echo "   🧠 sharedcontext.md: $context_words mots"
    elif [[ "$include_sharedcontext" == "false" ]]; then
        echo "   🧠 sharedcontext.md: NON GÉNÉRÉ (--no-metadata)"
    fi
    
    echo
    echo "💡 UTILISATION:"
    echo "   Copiez le contenu des fichiers dans votre LLM préféré"
    echo "   Commencez par manuscrit.md, puis sharedcontext.md si nécessaire"
}

# === NETTOYAGE ET VALIDATION ===
cleanup_context_temp() {
    # Nettoyer fichiers temporaires si nécessaire
    if [[ -d "${CONTEXT_OUTPUT_DIR}/temp" ]]; then
        rm -rf "${CONTEXT_OUTPUT_DIR}/temp"
        log_debug "Nettoyage fichiers temporaires"
    fi
}

validate_context_output() {
    local manuscrit_file="${CONTEXT_OUTPUT_DIR}/${CONTEXT_MANUSCRIT_FILE}"
    local context_file="${CONTEXT_OUTPUT_DIR}/${CONTEXT_SHARED_FILE}"
    
    # Vérification manuscrit
    if [[ ! -f "$manuscrit_file" ]] || [[ ! -s "$manuscrit_file" ]]; then
        log_error "Fichier manuscrit vide ou manquant"
        return 1
    fi
    
    # Vérification contexte (si demandé)
    if [[ "${include_sharedcontext:-true}" == "true" ]]; then
        if [[ ! -f "$context_file" ]] || [[ ! -s "$context_file" ]]; then
            log_warning "Fichier contexte vide ou manquant"
        fi
    fi
    
    return 0
}

# === HOOKS PRE/POST TRAITEMENT ===
pre_context_hook() {
    # Hook pour actions avant génération
    log_debug "Pre-context hook"
    
    # Vérifier espace disque
    local output_dir_parent=$(dirname "$CONTEXT_OUTPUT_DIR")
    if command -v df &> /dev/null; then
        local available_space=$(df "$output_dir_parent" | awk 'NR==2 {print $4}')
        if [[ $available_space -lt 10240 ]]; then  # Moins de 10MB
            log_warning "Espace disque faible: $(($available_space/1024))MB disponible"
        fi
    fi
}

post_context_hook() {
    # Hook pour actions après génération
    log_debug "Post-context hook"
    
    # Nettoyer temporaires
    cleanup_context_temp
    
    # Validation finale
    validate_context_output
    
    # Stats Git si disponible
    if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null; then
        local git_status=$(git status --porcelain 2>/dev/null | wc -l)
        if [[ $git_status -gt 0 ]]; then
            log_info "Git: $git_status fichiers modifiés (pensez à commit)"
        fi
    fi
}

# === EXPORT FONCTIONS ===
export -f cmd_context
export -f show_context_help
export -f generate_timeline_only
export -f generate_full_context

# Marquer module comme chargé
readonly SILK_COMMAND_CONTEXT_LOADED=true "