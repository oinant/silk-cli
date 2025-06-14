#!/bin/bash
# lib/commands/init.sh - Commande SILK init

# Vérification chargement des dépendances
if [[ "${SILK_CORE_UTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/utils requis" >&2
    exit 1
fi

if [[ "${SILK_CORE_CONFIG_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/config requis" >&2
    exit 1
fi

# === FONCTION PRINCIPALE ===
cmd_init() {
    local project_name=""
    local genre="$SILK_DEFAULT_GENRE"
    local language="$SILK_DEFAULT_LANGUAGE"
    local target_words="$SILK_DEFAULT_TARGET_WORDS"
    local target_chapters="$SILK_DEFAULT_CHAPTERS"
    local author_name="$SILK_AUTHOR_NAME"
    local author_pseudo="$SILK_AUTHOR_PSEUDO"
    local interactive=true
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_init_help
                return 0
                ;;
            -g|--genre)
                genre="$2"
                shift 2
                ;;
            -l|--language)
                language="$2"
                shift 2
                ;;
            -w|--words)
                target_words="$2"
                shift 2
                ;;
            -c|--chapters)
                target_chapters="$2"
                shift 2
                ;;
            -a|--author)
                author_name="$2"
                shift 2
                ;;
            -p|--pseudo)
                author_pseudo="$2"
                shift 2
                ;;
            -y|--yes)
                interactive=false
                shift
                ;;
            -*)
                log_error "Option inconnue: $1"
                return 1
                ;;
            *)
                if [[ -z "$project_name" ]]; then
                    project_name="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Mode interactif
    if [[ "$interactive" == "true" ]]; then
        run_interactive_setup project_name genre language target_words target_chapters author_name author_pseudo
    fi
    
    # Validation
    if [[ -z "$project_name" ]]; then
        log_error "Nom de projet requis"
        show_init_help
        return 1
    fi
    
    if ! is_valid_project_name "$project_name"; then
        log_error "Nom de projet invalide: $project_name"
        return 1
    fi
    
    if ! is_valid_genre "$genre"; then
        log_error "Genre invalide: $genre"
        echo "💡 Genres disponibles: $(get_available_templates | tr '\n' ' ')"
        return 1
    fi
    
    # Création du projet
    create_silk_project "$project_name" "$genre" "$language" "$target_words" "$target_chapters" "$author_name" "$author_pseudo"
}

# === AIDE INIT ===
show_init_help() {
    cat << 'HELP'
🕷️ SILK INIT - Créer un nouveau projet littéraire

USAGE:
  silk init [PROJECT_NAME] [OPTIONS]

OPTIONS:
  -g, --genre GENRE          Genre du projet 
  -l, --language LANG        Langue (fr, en, es, de)
  -w, --words NUMBER         Objectif mots (défaut: 80000)
  -c, --chapters NUMBER      Nombre de chapitres (défaut: 30)
  -a, --author NAME          Nom auteur
  -p, --pseudo PSEUDO        Pseudonyme auteur
  -y, --yes                  Mode non-interactif
  -h, --help                 Afficher cette aide

EXEMPLES:
  silk init "L'Araignée"                         # Mode interactif
  silk init "Dark Mystery" --genre fantasy       # Projet fantasy
  silk init "Love Story" -w 60000 -c 25 -y      # Romance courte

GENRES SILK DISPONIBLES:
  polar-psychologique    Polar sophistiqué avec éléments psychologiques
  fantasy               Fantasy/fantastique avec worldbuilding
  romance               Romance/sentiment avec développement relationnel
  literary              Littérature générale/contemporaine
  thriller              Thriller/suspense action
  
SILK = Smart Integrated Literary Kit
Tisse ensemble tous les éléments de votre roman comme une araignée tisse sa toile.
HELP
}

# === SETUP INTERACTIF ===
run_interactive_setup() {
    local -n proj_name=$1
    local -n proj_genre=$2
    local -n proj_language=$3
    local -n proj_target_words=$4
    local -n proj_target_chapters=$5
    local -n proj_author_name=$6
    local -n proj_author_pseudo=$7
    
    log_header "SILK INIT - Smart Integrated Literary Kit"
    echo -e "${CYAN}Tissons ensemble votre nouveau projet littéraire...${NC}"
    echo
    
    if [[ -z "$proj_name" ]]; then
        read -p "📖 Nom du projet: " proj_name
    fi
    
    echo -e "\n🎭 Genres disponibles:"
    get_available_templates | while read -r template; do
        local desc=$(get_template_description "$template")
        echo "   $template - $desc"
    done
    echo
    read -p "🎭 Genre [$proj_genre]: " input_genre
    proj_genre="${input_genre:-$proj_genre}"
    
    read -p "🌍 Langue [$proj_language]: " input_language
    proj_language="${input_language:-$proj_language}"
    
    read -p "📊 Objectif mots [$proj_target_words]: " input_words
    proj_target_words="${input_words:-$proj_target_words}"
    
    read -p "📚 Nombre chapitres [$proj_target_chapters]: " input_chapters
    proj_target_chapters="${input_chapters:-$proj_target_chapters}"
    
    read -p "✍️  Nom auteur [$proj_author_name]: " input_author
    proj_author_name="${input_author:-$proj_author_name}"
    
    read -p "🎭 Pseudonyme [$proj_author_pseudo]: " input_pseudo
    proj_author_pseudo="${input_pseudo:-$proj_author_pseudo}"
}

# === CRÉATION PROJET ===
create_silk_project() {
    local project_name="$1"
    local genre="$2"
    local language="$3"
    local target_words="$4"
    local target_chapters="$5"
    local author_name="$6"
    local author_pseudo="$7"
    
    # Nom du répertoire
    local project_dir="${project_name// /-}"
    project_dir="${project_dir,,}"  # lowercase
    
    if [[ -d "$project_dir" ]]; then
        log_error "Le répertoire '$project_dir' existe déjà"
        return 1
    fi
    
    log_info "Tissage du projet '$project_name' dans '$project_dir'"
    
    # Créer structure
    mkdir -p "$project_dir"
    cd "$project_dir"
    
    # Initialiser Git
    git init --quiet
    
    # Créer structure SILK
    create_silk_structure
    
    # Créer contenu selon le genre
    create_genre_content "$genre" "$project_name" "$author_name" "$author_pseudo"
    
    # Créer README
    create_project_readme "$project_name" "$genre" "$language" "$target_words" "$target_chapters" "$author_name" "$author_pseudo"
    
    # Créer configuration publication
    create_publishing_config "$project_name" "$author_name"
    
    # Créer .gitignore
    create_gitignore
    
    # Premier commit
    git add .
    git commit --quiet -m "🕷️ Initial SILK project: $project_name

🕸️ Smart Integrated Literary Kit v$SILK_VERSION
📚 Projet: $project_name
🎭 Genre: $genre  
🎯 Objectif: $target_words mots ($target_chapters chapitres)
✍️ Auteur: $author_name

Structure tissée avec templates $genre optimisés.
Ready for: silk context, wordcount, publish"
    
    log_success "Projet '$project_name' tissé avec succès !"
    echo
    log_info "Prochaines étapes:"
    echo "  cd $project_dir"
    echo "  silk context --help     # Contexte LLM optimisé"
    echo "  silk wordcount          # Suivi progression"
    echo "  silk publish --help     # Publication PDF"
    echo
    echo "🕸️ SILK has woven your literary foundation. Begin writing!"
}

# === STRUCTURE SILK ===
create_silk_structure() {
    local dirs=(
        "00-instructions-llm"
        "01-Manuscrit"
        "02-Personnages/Principaux"
        "02-Personnages/Secondaires"
        "03-Lieux"
        "04-Concepts"
        "07-timeline"
        "10-Lore"
        "20-Pitch-Editeurs"
        "21-Planning"
        "50-Sessions-Claude"
        "60-idees-tome-2"
        "99-Templates"
        "formats"
        "outputs/context"
        "outputs/publish"
        "outputs/temp"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done
    
    log_debug "Structure SILK créée"
}

# === CONTENU GENRE ===
create_genre_content() {
    local genre="$1"
    local project_name="$2"
    local author_name="$3"
    local author_pseudo="$4"
    
    # Charger template genre
    case "$genre" in
        "polar-psychologique")
            load_module "templates/polar.sh" && create_polar_content "$project_name" "$author_name" "$author_pseudo"
            ;;
        "fantasy")
            load_module "templates/fantasy.sh" && create_fantasy_content "$project_name" "$author_name" "$author_pseudo"
            ;;
        "romance")
            load_module "templates/romance.sh" && create_romance_content "$project_name" "$author_name" "$author_pseudo"
            ;;
        *)
            load_module "templates/generic.sh" && create_generic_content "$project_name" "$author_name" "$author_pseudo"
            ;;
    esac
    
    # Templates universels
    create_universal_templates
}

create_universal_templates() {
    # Template chapitre SILK universel
    cat > "99-Templates/Template-Chapitre.md" << 'EOF'
# Ch.X : [TITRE]

## Objectifs SILK
- **Intrigue** : Avancement enquête/conflit principal
- **Développement** : Évolution personnages
- **Révélations** : Informations dévoilées au lecteur
- **Tension** : Niveau suspense/émotion

## Personnages actifs
- [[Protagoniste]] : Actions et motivations
- [[Deutéragoniste]] : Rôle dans ce chapitre

## Liens narratifs
← Ch.X : Continuité depuis chapitre précédent
→ Ch.X : Préparation chapitre suivant

## manuscrit

*[SILK: Tout le contenu après cette ligne sera analysé par LLM]*

[Début du chapitre...]
EOF

    # Template personnage SILK
    cat > "99-Templates/Template-Personnage.md" << 'EOF'
# [Nom Personnage]

## Identité
- **Âge** : 
- **Fonction** : 
- **Statut social** : 

## Psychologie SILK
### Motivations profondes
- **Désir conscient** : Ce que le personnage pense vouloir
- **Besoin inconscient** : Ce dont il a vraiment besoin
- **Peur principale** : Ce qui le paralyse

### Failles et contradictions  
- **Défaut majeur** : Trait qui cause des problèmes
- **Force cachée** : Potentiel non exploité
- **Évolution prévue** : Arc de transformation

## Relations
- [[Personnage]] : Nature relation et évolution

## Arc narratif
- **Introduction** : Première apparition et impression
- **Développement** : Révélation progressive de la complexité  
- **Climax** : Moment de vérité/choix crucial
- **Résolution** : État final et apprentissage

## Notes développement SILK
> Intelligence narrative : Comment ce personnage sert l'intrigue
> Résonance émotionnelle : Impact sur le lecteur cible
EOF
}

# === README PROJET ===
create_project_readme() {
    local project_name="$1"
    local genre="$2"
    local language="$3"
    local target_words="$4"
    local target_chapters="$5"
    local author_name="$6"
    local author_pseudo="$7"
    
    cat > README.md << EOF
# 🕷️ $project_name
*Projet SILK - Smart Integrated Literary Kit*

**Genre**: $genre  
**Langue**: $language  
**Objectif**: $target_words mots ($target_chapters chapitres)  
**Auteur**: $author_name${author_pseudo:+ (pseudo: $author_pseudo)}

Généré avec SILK v$SILK_VERSION - *Structured Intelligence for Literary Kreation*

## 🕸️ Structure SILK

SILK tisse ensemble tous les éléments de votre roman :

- \`01-Manuscrit/\` - Chapitres du manuscrit (avec séparateur \`## manuscrit\`)
- \`02-Personnages/\` - Fiches personnages hiérarchisées  
- \`04-Concepts/\` - Mécaniques narratives et intrigue
- \`outputs/\` - Fichiers générés (contexte LLM, PDF)

## 🚀 Workflow SILK

\`\`\`bash
silk context              # Générer contexte optimisé pour LLM
silk wordcount           # Statistiques progression intelligentes
silk publish             # Générer PDF professionnel multi-format
\`\`\`

## 🤖 Intégration LLM

### Séparateur standardisé
Chaque chapitre utilise la convention SILK :
\`\`\`markdown
# Ch.X : Titre

## Objectifs
[Métadonnées pour planification]

## manuscrit
[Contenu pur pour analyse LLM]
\`\`\`

### Contexte intelligent
- Range flexible : \`-ch 1-10\`, \`-ch 15,20,25\`
- Mode normal : Essentiel (personnages + concepts)
- Mode complet : \`--full\` (+ lieux + statistiques)

## 📖 Documentation

Ce projet suit les conventions SILK pour l'écriture moderne avec IA.
Chaque génération inclut templates optimisés par genre et marché.

*SILK weaves your story together - like a spider weaves its web*
EOF
}

# === CONFIGURATION PUBLICATION ===
create_publishing_config() {
    local project_name="$1"
    local author_name="$2"
    
    # Configuration de base
    cat > "formats/base.yaml" << EOF
title: "$project_name"
author: "$author_name"
date: "$(date '+%Y-%m-%d')"
lang: fr-FR
fontsize: 11pt
linestretch: 1.2
documentclass: book
classoption: 
  - openany
  - twoside
mainfont: "EB Garamond"
mainfontoptions:
  - Numbers=OldStyle
  - Ligatures=TeX
indent: true
block-headings: true
header-includes: |
  \usepackage[french]{babel}
  \usepackage{microtype}
  \clubpenalty=10000
  \widowpenalty=10000
EOF

    # Formats spécialisés
    local formats=("digital:6in,9in,0.5in" "iphone:4.7in,8.3in,0.3in" "kindle:5in,7.5in,0.4in" "book:a5paper,0.8in")
    
    for format_spec in "${formats[@]}"; do
        local format_name="${format_spec%%:*}"
        local geometry="${format_spec#*:}"
        
        cat > "formats/$format_name.yaml" << EOF
# Format $format_name SILK
geometry: "paperwidth=${geometry%%,*},paperheight=${geometry#*,}"
geometry: "${geometry#*,}"
EOF
    done
}

# === GITIGNORE ===
create_gitignore() {
    cat > .gitignore << 'EOF'
# SILK CLI - Gitignore

# OS
.DS_Store
Thumbs.db
*.tmp
*~

# IDE
.vscode/
.idea/
*.swp
*.swo

# SILK temporaires
outputs/temp/
.silk-cache/

# Sauvegardes
*.backup.*

# Log files
*.log
logs/

# Distribution  
dist/
build/
*.tar.gz
*.zip

# Local config
.env
.env.local
config.local
EOF
}

# === FALLBACK CONTENU GÉNÉRIQUE ===
create_generic_content() {
    local project_name="$1"
    local author_name="$2"
    local author_pseudo="$3"
    
    # Instructions LLM génériques
    cat > "00-instructions-llm/instructions.md" << EOF
# Instructions LLM - $project_name
*Projet SILK - Smart Integrated Literary Kit*

## 🎯 CONTEXTE PROJET
**Auteur** : $author_name${author_pseudo:+ (pseudo: $author_pseudo)}
**Architecture** : SILK - Structured Intelligence for Literary Kreation

## 🕷️ APPROCHE SILK
SILK tisse une œuvre cohérente et engageante :
- **Smart** : Analyse intelligente des éléments narratifs
- **Integrated** : Cohérence entre tous les aspects du récit
- **Literary** : Focus sur la qualité d'écriture
- **Kit** : Outils complets pour l'auteur moderne

## 📋 INSTRUCTIONS GÉNÉRALES
### Style et cohérence
- Voix narrative consistante et personnelle
- Développement des personnages crédible
- Structure narrative équilibrée et maîtrisée
- Dialogue authentique et différencié

### Révision et amélioration
- Cohérence temporelle et factuelle
- Qualité des transitions et du rythme
- Profondeur psychologique des personnages
- Résolution satisfaisante des conflits
EOF

    # Concept exemple
    cat > "04-Concepts/Structure-Narrative.md" << 'EOF'
# Structure Narrative

## Architecture SILK
- **Introduction** : Établissement monde et personnages
- **Développement** : Progression conflits et relations
- **Climax** : Point culminant tension narrative
- **Résolution** : Dénouement et conclusions

## Mécaniques récit
- **Rythme** : Alternance tension/respiration
- **Révélations** : Information progressive au lecteur
- **Arcs personnages** : Évolution psychologique
- **Thèmes** : Exploration cohérente des idées centrales

## Outils SILK
- Séparateur `## manuscrit` pour analyse LLM
- Range syntax pour contexte ciblé
- Templates personnages et chapitres
- Publication multi-format automatisée
EOF

    # Exemple chapitre
    cat > "01-Manuscrit/Ch01-Premier-Chapitre.md" << 'EOF'
# Ch.01 : Premier Chapitre

## Objectifs SILK
- **Intrigue** : Établir le conflit principal et accrocher le lecteur
- **Développement** : Présenter le protagoniste avec ses forces/failles
- **Révélations** : Éléments d'exposition nécessaires
- **Tension** : Créer questions qui motivent la lecture

## Personnages actifs
- [[Protagoniste]] : Introduction avec vulnérabilité humaine
- [[Personnages secondaires]] : Établir relations principales

## Liens narratifs
← Début : Immersion directe dans l'action/situation
→ Ch.02 : Développement du conflit établi

## manuscrit

[Commencez votre récit ici...]

[SILK analysera automatiquement tout le contenu après le séparateur "## manuscrit"]

[Utilisez les templates dans 99-Templates/ pour structurer vos chapitres et personnages]
EOF

    # Personnage exemple
    cat > "02-Personnages/Protagoniste.md" << 'EOF'
# [Nom du Protagoniste]

## Identité
- **Âge** : 
- **Profession** : 
- **Statut social** : 

## Psychologie SILK
### Motivations profondes
- **Désir conscient** : Ce que le personnage pense vouloir
- **Besoin inconscient** : Ce dont il a vraiment besoin
- **Peur principale** : Ce qui le paralyse ou le limite

### Failles et forces
- **Défaut majeur** : Trait qui cause des problèmes
- **Talent particulier** : Compétence ou don spécial
- **Évolution prévue** : Comment il va changer

## Arc narratif
- **Point départ** : État initial du personnage
- **Catalyseur** : Événement qui lance le changement
- **Obstacles** : Défis internes et externes
- **Transformation** : Nouvelle version de lui-même

## Relations
- [[Autres personnages]] : Nature des liens

## Notes développement SILK
> Comment ce personnage sert-il l'intrigue principale ?
> Quel impact émotionnel aura-t-il sur le lecteur ?
EOF
}

# === VALIDATION POST-CRÉATION ===
validate_created_project() {
    local project_dir="$1"
    
    if [[ ! -d "$project_dir" ]]; then
        log_error "Projet non créé: $project_dir"
        return 1
    fi
    
    cd "$project_dir"
    
    # Vérifier structure
    if validate_silk_structure; then
        log_success "Structure projet validée"
    else
        log_warning "Structure projet incomplète"
    fi
    
    # Vérifier Git
    if [[ -d ".git" ]]; then
        local commits=$(git rev-list --count HEAD 2>/dev/null || echo "0")
        if [[ "$commits" -gt 0 ]]; then
            log_success "Projet Git initialisé avec $commits commit(s)"
        else
            log_warning "Git initialisé mais pas de commits"
        fi
    else
        log_warning "Git non initialisé"
    fi
    
    return 0
}

# === NETTOYAGE EN CAS D'ERREUR ===
cleanup_failed_project() {
    local project_dir="$1"
    
    if [[ -n "$project_dir" && -d "$project_dir" ]]; then
        log_warning "Nettoyage projet incomplet: $project_dir"
        rm -rf "$project_dir"
    fi
}

# === EXPORT FONCTIONS ===
export -f cmd_init
export -f show_init_help
export -f create_silk_project

# Marquer module comme chargé
readonly SILK_COMMAND_INIT_LOADED=true