#!/bin/bash
# lib/core/vault.sh - Gestion projets SILK (vault)

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

# === EXTRACTION CONTENU ===
extract_manuscript_content() {
    local file="$1"

    if grep -q "$MANUSCRIPT_SEPARATOR" "$file"; then
        sed -n "/$MANUSCRIPT_SEPARATOR/,\$p" "$file" | tail -n +2
    else
        log_warning "Fichier sans séparateur: $(basename "$file")"
        return 1
    fi
}

# === STRUCTURE PROJET SILK ===
get_silk_project_info() {
    ensure_silk_context

    local project_name=$(basename "$PWD")
    local readme_file="README.md"
    local genre="unknown"
    local author="unknown"
    local target_words="unknown"

    # Extraire infos du README si possible
    if [[ -f "$readme_file" ]]; then
        genre=$(grep "^**Genre**:" "$readme_file" | sed 's/^**Genre**: *//' | head -1)
        author=$(grep "^**Auteur**:" "$readme_file" | sed 's/^**Auteur**: *//' | head -1)
        target_words=$(grep "^**Objectif**:" "$readme_file" | sed 's/^**Objectif**: *//' | sed 's/ mots.*//' | head -1)
    fi

    echo "project_name:$project_name"
    echo "genre:${genre:-unknown}"
    echo "author:${author:-unknown}"
    echo "target_words:${target_words:-unknown}"
}

# === STATISTIQUES PROJET ===
get_silk_project_stats() {
    ensure_silk_context

    local total_files=0
    local total_chapters=0
    local total_words=0
    local total_characters=0

    # Compter fichiers manuscrit
    for file in 01-Manuscrit/*.md; do
        if [[ -f "$file" ]]; then
            ((total_files++))

            # Si le fichier a du contenu manuscrit
            if grep -q "$MANUSCRIPT_SEPARATOR" "$file"; then
                ((total_chapters++))
                local words=$(extract_manuscript_content "$file" | wc -w)
                local chars=$(extract_manuscript_content "$file" | wc -c)
                total_words=$((total_words + words))
                total_characters=$((total_characters + chars))
            fi
        fi
    done

    echo "files:$total_files"
    echo "chapters:$total_chapters"
    echo "words:$total_words"
    echo "characters:$total_characters"
    echo "pages:$((total_words / 250))"
}

# === VALIDATION STRUCTURE ===
validate_silk_structure() {
    local errors=0
    local warnings=0

    log_info "Validation structure SILK..."

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
        if [[ -f "$file" ]] && grep -q "$MANUSCRIPT_SEPARATOR" "$file"; then
            ((chapters_with_content++))
        fi
    done

    if [[ $chapters_with_content -eq 0 ]]; then
        log_warning "Aucun chapitre avec contenu '${MANUSCRIPT_SEPARATOR}' trouvé"
        ((warnings++))
    else
        log_debug "✅ $chapters_with_content chapitres avec contenu"
    fi

    # Résumé
    if [[ $errors -eq 0 ]]; then
        log_success "Structure SILK valide ($warnings avertissement(s))"
        return 0
    else
        log_error "Structure SILK invalide: $errors erreur(s), $warnings avertissement(s)"
        return 1
    fi
}

# === MAINTENANCE PROJET ===
silk_project_cleanup() {
    ensure_silk_context

    log_info "Nettoyage projet SILK..."

    # Nettoyer fichiers temporaires
    find outputs/temp -name "*.tmp" -delete 2>/dev/null || true
    find outputs/temp -name "silk_*" -mtime +7 -delete 2>/dev/null || true

    # Nettoyer sauvegardes anciennes
    find . -name "*.backup.*" -mtime +30 -delete 2>/dev/null || true

    # Nettoyer cache SILK
    if [[ -d ".silk-cache" ]]; then
        rm -rf .silk-cache
    fi

    log_success "Nettoyage terminé"
}

silk_project_backup() {
    ensure_silk_context

    local backup_name="${1:-$(date +%Y%m%d-%H%M%S)}"
    local project_name=$(basename "$PWD")
    local backup_file="${project_name}-backup-${backup_name}.tar.gz"

    log_info "Sauvegarde projet SILK: $backup_file"

    # Créer archive en excluant outputs/temp et .git
    tar --exclude='outputs/temp' \
        --exclude='.git' \
        --exclude='*.backup.*' \
        --exclude='.silk-cache' \
        -czf "$backup_file" .

    log_success "Sauvegarde créée: $backup_file"
    echo "📁 Taille: $(ls -lh "$backup_file" | awk '{print $5}')"
}

# === MIGRATION PROJETS ===
migrate_legacy_to_silk() {
    local legacy_dir="$1"

    if [[ ! -d "$legacy_dir" ]]; then
        log_error "Répertoire legacy non trouvé: $legacy_dir"
        return 1
    fi

    log_info "Migration projet legacy vers SILK: $legacy_dir"

    cd "$legacy_dir"

    # Créer structure SILK manquante
    local silk_dirs=(
        "00-instructions-llm"
        "outputs/context"
        "outputs/publish"
        "outputs/temp"
        "formats"
        "99-Templates"
    )

    for dir in "${silk_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_success "Créé: $dir"
        fi
    done

    # Convertir chapitres au format SILK
    for file in 01-Manuscrit/*.md; do
        if [[ -f "$file" ]] && ! grep -q "$MANUSCRIPT_SEPARATOR" "$file"; then
            # Ajouter séparateur manuscrit
            echo "" >> "$file"
            echo "$MANUSCRIPT_SEPARATOR" >> "$file"
            echo "" >> "$file"
            echo "[Contenu migré du format legacy]" >> "$file"
            log_success "Converti: $(basename "$file")"
        fi
    done

    # Créer fichiers SILK essentiels
    if [[ ! -f "formats/base.yaml" ]]; then
        cat > "formats/base.yaml" << 'EOF'
title: "Projet Migré"
author: "Auteur"
date: "$(date)"
lang: fr-FR
documentclass: book
EOF
        log_success "Créé: formats/base.yaml"
    fi

    # Créer .gitignore SILK
    if [[ ! -f ".gitignore" ]]; then
        cat > ".gitignore" << 'EOF'
outputs/temp/
.silk-cache/
*.backup.*
.DS_Store
EOF
        log_success "Créé: .gitignore"
    fi

    log_success "Migration vers SILK terminée"
    log_info "💡 Utilisez 'silk debug validate' pour vérifier la structure"
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

# === EXPORT MODULE ===
readonly SILK_CORE_VAULT_LOADED=true
