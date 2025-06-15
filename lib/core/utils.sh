#!/bin/bash
# lib/core/utils.sh - Fonctions utilitaires SILK

# === COULEURS ===
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly PURPLE='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' NC=''
fi

# === LOGGING ===
log_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[OK] $1${NC}"; }
log_warning() { echo -e "${YELLOW}[WARN] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }
log_header() { echo -e "${PURPLE}[SILK] $1${NC}"; }
log_debug() {
    if [[ "${SILK_DEBUG:-false}" == "true" ]]; then
        echo -e "${CYAN}[DEBUG] $1${NC}" >&2
    fi
}

# === DÉTECTION SYSTÈME ===
detect_os() {
    case "$OSTYPE" in
        msys*|cygwin*|mingw*) echo "windows" ;;
        darwin*) echo "macos" ;;
        linux*) echo "linux" ;;
        *) echo "unknown" ;;
    esac
}

get_sed_args() {
    if [[ "$(detect_os)" == "macos" ]]; then
        echo "-i ''"
    else
        echo "-i"
    fi
}

# === VALIDATION ===
is_valid_project_name() {
    local name="$1"
    [[ -n "$name" && "$name" =~ ^[a-zA-Z0-9_\ \-\'\"]+$ ]]
}

is_valid_word_count() {
    local count="$1"
    [[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 && "$count" -le 1000000 ]]
}

is_valid_genre() {
    local genre="$1"
    case "$genre" in
        polar-psychologique|fantasy|romance|literary|thriller) return 0 ;;
        *) return 1 ;;
    esac
}

# === FICHIERS ET RÉPERTOIRES ===
ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_debug "Répertoire créé: $dir"
    fi
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d-%H%M%S)"
        cp "$file" "$backup"
        log_debug "Sauvegarde créée: $backup"
    fi
}

# === DÉTECTION PROJETS SILK ===
is_silk_project() {
    [[ -d "01-Manuscrit" && -d "02-Personnages" && -d "04-Concepts" ]]
}

find_silk_root() {
    local current_dir="$PWD"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -d "$current_dir/01-Manuscrit" ]]; then
            echo "$current_dir"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done
    return 1
}

ensure_silk_context() {
    if ! is_silk_project; then
        local silk_root
        if silk_root=$(find_silk_root); then
            log_info "Projet SILK trouvé dans: $silk_root"
            cd "$silk_root"
        else
            log_error "Pas dans un projet SILK. Utilisez 'silk init' pour créer un projet."
            exit 1
        fi
    fi
}

# === EXTRACTION DONNÉES ===
extract_chapter_number() {
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

    echo "${chapter_num:-0}"
}

extract_manuscript_content() {
    local file="$1"
    local marker="${2:-## manuscrit}"

    if grep -q "$marker" "$file"; then
        sed -n "/$marker/,\$p" "$file" | tail -n +2
    else
        log_warning "Fichier sans séparateur: $(basename "$file")"
        return 1
    fi
}

# === GESTION RANGES CHAPITRES ===
normalize_chapter_range() {
    local range="$1"

    # Si "all" ou range simple sans virgule, pas de traitement
    if [[ "$range" == "all" ]] || [[ "$range" != *","* ]]; then
        echo "$range"
        return
    fi

    # Pour les listes, les trier par ordre numérique croissant
    IFS=',' read -ra chapter_list <<< "$range"
    local sorted_chapters=()

    # Collecter tous les chapitres individuels
    for ch in "${chapter_list[@]}"; do
        ch=$(echo "$ch" | tr -d ' ')
        # Si c'est un range (ex: 18-20), l'expandre
        if [[ "$ch" == *"-"* ]]; then
            local start_ch=$(echo "$ch" | cut -d'-' -f1)
            local end_ch=$(echo "$ch" | cut -d'-' -f2)
            for ((i=start_ch; i<=end_ch; i++)); do
                sorted_chapters+=("$i")
            done
        else
            sorted_chapters+=("$ch")
        fi
    done

    # Trier et dédupliquer
    printf '%s\n' "${sorted_chapters[@]}" | sort -n | uniq | tr '\n' ',' | sed 's/,$//'
}

is_chapter_in_range() {
    local chapter_num="$1"
    local range="$2"

    # Si "all", inclure tout
    if [[ "$range" == "all" ]]; then
        return 0
    fi

    # Vérifier si le chapitre_num est vide ou non numérique
    if [[ -z "$chapter_num" ]] || ! [[ "$chapter_num" =~ ^[0-9]+$ ]]; then
        return 0  # Inclus par défaut
    fi

    # Support pour liste de chapitres séparés par ,
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

    # Support pour range (ex: "1-30")
    if [[ "$range" == *"-"* ]]; then
        local start_ch=$(echo "$range" | cut -d'-' -f1)
        local end_ch=$(echo "$range" | cut -d'-' -f2)

        if [[ "$chapter_num" -ge "$start_ch" ]] && [[ "$chapter_num" -le "$end_ch" ]]; then
            return 0
        else
            return 1
        fi
    else
        # Range d'un seul chapitre (ex: "28")
        if [[ "$chapter_num" -eq "$range" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# === FORMATAGE DONNÉES ===
format_file_size() {
    local bytes="$1"

    if command -v numfmt &> /dev/null; then
        numfmt --to=iec-i --suffix=B "$bytes"
    elif [[ $bytes -gt 1073741824 ]]; then
        echo "$(($bytes / 1073741824))GB"
    elif [[ $bytes -gt 1048576 ]]; then
        echo "$(($bytes / 1048576))MB"
    elif [[ $bytes -gt 1024 ]]; then
        echo "$(($bytes / 1024))KB"
    else
        echo "${bytes}B"
    fi
}

format_duration() {
    local seconds="$1"

    if [[ $seconds -ge 3600 ]]; then
        printf "%02d:%02d:%02d" $((seconds/3600)) $(((seconds%3600)/60)) $((seconds%60))
    elif [[ $seconds -ge 60 ]]; then
        printf "%02d:%02d" $((seconds/60)) $((seconds%60))
    else
        printf "%ds" "$seconds"
    fi
}

# === TEMPLATES ET SUBSTITUTION ===
substitute_template_vars() {
    local template="$1"
    shift
    local result="$template"

    # Substitution variables $1 = key, $2 = value, $3 = key, $4 = value...
    while [[ $# -ge 2 ]]; do
        local key="$1"
        local value="$2"
        result=$(echo "$result" | sed "s/{{[[:space:]]*${key}[[:space:]]*}}/${value}/g")
        shift 2
    done

    echo "$result"
}

# === VÉRIFICATIONS DÉPENDANCES ===
check_dependency() {
    local cmd="$1"
    local package="${2:-$cmd}"

    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd requis mais non trouvé"
        log_info "Installation: $package"
        return 1
    fi

    log_debug "Dépendance OK: $cmd"
    return 0
}

check_required_dependencies() {
    local missing=0

    check_dependency "git" || ((missing++))

    return $missing
}

check_publish_dependencies() {
    local missing=0

    check_dependency "pandoc" "https://pandoc.org/installing.html" || ((missing++))
    check_dependency "xelatex" "https://www.latex-project.org/get/" || ((missing++))

    return $missing
}

# === PERFORMANCE ET DEBUG ===
start_timer() {
    echo "$(date +%s)"
}

end_timer() {
    local start_time="$1"
    local end_time="$(date +%s)"
    local duration=$((end_time - start_time))
    format_duration "$duration"
}

debug_vars() {
    if [[ "${SILK_DEBUG:-false}" == "true" ]]; then
        log_debug "Variables d'environnement SILK:"
        env | grep ^SILK_ | while read -r line; do
            log_debug "  $line"
        done
    fi
}

# === TEMPLATES PROJET ===
get_available_templates() {
    echo "polar-psychologique"
    echo "fantasy"
    echo "romance"
    echo "literary"
    echo "thriller"
}

get_template_description() {
    local template="$1"

    case "$template" in
        polar-psychologique)
            echo "Polar sophistiqué avec éléments psychologiques - Public CSP+ 35-55 ans"
            ;;
        fantasy)
            echo "Fantasy/fantastique avec worldbuilding structuré et système magique"
            ;;
        romance)
            echo "Romance avec développement relationnel authentique et arc émotionnel"
            ;;
        literary)
            echo "Littérature contemporaine avec thèmes universels et style soigné"
            ;;
        thriller)
            echo "Thriller/suspense avec tension constante et rythme soutenu"
            ;;
        *)
            echo "Template inconnu"
            ;;
    esac
}

# === VALIDATION STRUCTURE SILK ===
validate_silk_structure() {
    local errors=0
    local warnings=0

    log_debug "Validation structure SILK..."

    # Répertoires obligatoires
    local required_dirs=(
        "01-Manuscrit"
        "02-Personnages"
        "04-Concepts"
        "outputs/context"
        "outputs/publish"
        "formats"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_debug "✅ $dir"
        else
            log_error "❌ Répertoire manquant: $dir"
            ((errors++))
        fi
    done

    # Fichiers recommandés
    local recommended_files=(
        "README.md"
        "formats/base.yaml"
        "formats/digital.yaml"
        ".gitignore"
    )

    for file in "${recommended_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_debug "✅ $file"
        else
            log_warning "⚠️  Fichier recommandé manquant: $file"
            ((warnings++))
        fi
    done

    # Vérifier contenu manuscrit
    local chapters_with_content=0
    for file in 01-Manuscrit/*.md; do
        if [[ -f "$file" ]] && grep -q "${VAULT_MARKER:-## manuscrit}" "$file"; then
            ((chapters_with_content++))
        fi
    done

    if [[ $chapters_with_content -eq 0 ]]; then
        log_warning "Aucun chapitre avec contenu '${VAULT_MARKER:-## manuscrit}' trouvé"
        ((warnings++))
    else
        log_debug "✅ $chapters_with_content chapitres avec contenu"
    fi

    # Résumé validation
    if [[ $errors -eq 0 ]]; then
        log_success "Structure SILK valide ($warnings avertissement(s))"
        return 0
    else
        log_error "Structure SILK invalide: $errors erreur(s), $warnings avertissement(s)"
        return 1
    fi
}

# === UTILITAIRES TEXTE ===
trim_whitespace() {
    local text="$1"
    # Supprimer espaces début/fin
    text="${text#"${text%%[![:space:]]*}"}"   # début
    text="${text%"${text##*[![:space:]]}"}"   # fin
    echo "$text"
}

truncate_text() {
    local text="$1"
    local max_length="${2:-50}"

    if [[ ${#text} -gt $max_length ]]; then
        echo "${text:0:$max_length}..."
    else
        echo "$text"
    fi
}

# === GESTION COULEURS ===
strip_colors() {
    # Supprimer séquences d'échappement ANSI
    sed 's/\x1b\[[0-9;]*m//g'
}

# === SÉCURITÉ ===
sanitize_filename() {
    local filename="$1"
    # Remplacer caractères dangereux par tirets
    echo "$filename" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g'
}

# === CALCULS ÉDITORIAUX ===
calculate_pages() {
    local word_count="$1"
    local words_per_page="${2:-250}"
    echo $((word_count / words_per_page))
}

calculate_reading_time() {
    local word_count="$1"
    local words_per_minute="${2:-200}"
    local minutes=$((word_count / words_per_minute))

    if [[ $minutes -ge 60 ]]; then
        local hours=$((minutes / 60))
        local remaining_minutes=$((minutes % 60))
        echo "${hours}h${remaining_minutes}min"
    else
        echo "${minutes}min"
    fi
}

# === GESTION GIT ===
silk_git_info() {
    if ! command -v git &> /dev/null; then
        echo "git_available:false"
        return
    fi

    if ! git rev-parse --git-dir &> /dev/null 2>&1; then
        echo "git_available:true"
        echo "git_repo:false"
        return
    fi

    local branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local commits=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    local status=$(git status --porcelain 2>/dev/null | wc -l)

    echo "git_available:true"
    echo "git_repo:true"
    echo "git_branch:$branch"
    echo "git_commits:$commits"
    echo "git_modified_files:$status"
}

# === HELPERS MARKDOWN ===
markdown_escape() {
    local text="$1"
    # Échapper caractères spéciaux Markdown
    echo "$text" | sed 's/\([*_`[\\]\)/\\\1/g'
}

# === VALIDATION FINALE ===
silk_utils_self_test() {
    log_debug "Auto-test module utils.sh..."

    # Test fonctions de base
    if ! is_valid_word_count "80000"; then
        log_error "Self-test échoué: is_valid_word_count"
        return 1
    fi

    if ! is_valid_genre "polar-psychologique"; then
        log_error "Self-test échoué: is_valid_genre"
        return 1
    fi

    # Test formatage
    local test_size=$(format_file_size 1048576)
    if [[ "$test_size" != *"MB"* && "$test_size" != *"1048576"* ]]; then
        log_error "Self-test échoué: format_file_size"
        return 1
    fi

    log_debug "Auto-test utils.sh réussi"
    return 0
}

# === EXPORT FONCTIONS ===
export -f log_info log_success log_warning log_error log_header log_debug
export -f detect_os get_sed_args
export -f is_valid_project_name is_valid_word_count is_valid_genre
export -f ensure_directory backup_file
export -f is_silk_project find_silk_root ensure_silk_context
export -f extract_chapter_number extract_manuscript_content
export -f normalize_chapter_range is_chapter_in_range
export -f format_file_size format_duration
export -f substitute_template_vars
export -f check_dependency check_required_dependencies check_publish_dependencies
export -f start_timer end_timer debug_vars
export -f get_available_templates get_template_description
export -f validate_silk_structure
export -f trim_whitespace truncate_text strip_colors sanitize_filename
export -f calculate_pages calculate_reading_time
export -f silk_git_info markdown_escape

# Marquer module comme chargé
readonly SILK_CORE_UTILS_LOADED=true
