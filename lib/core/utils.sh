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
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_header() { echo -e "${PURPLE}🕷️  $1${NC}"; }
log_debug() { 
    if [[ "${SILK_DEBUG:-false}" == "true" ]]; then
        echo -e "${CYAN}🔧 $1${NC}" >&2
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

# === VALIDATION FINALE ===
readonly SILK_CORE_UTILS_LOADED=true