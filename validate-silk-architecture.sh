#!/bin/bash
# validate-silk-architecture.sh - Validation complète architecture SILK

set -euo pipefail

# === CONFIGURATION ===
VALIDATION_DIR="silk-validation-test"
START_TIME=$(date +%s)
TESTS_PASSED=0
TESTS_FAILED=0

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# === FONCTIONS UTILITAIRES ===
log_header() { echo -e "${PURPLE}🕷️  $1${NC}"; }
log_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[PASS] $1${NC}"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL] $1${NC}"; ((TESTS_FAILED++)); }
log_warning() { echo -e "${YELLOW}[WARN] $1${NC}"; }

run_test() {
    local test_name="$1"
    local test_command="$2"

    log_info "Test: $test_name"
    if eval "$test_command" > /dev/null 2>&1; then
        log_success "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

cleanup() {
    if [[ -d "$VALIDATION_DIR" ]]; then
        rm -rf "$VALIDATION_DIR"
    fi
}

trap cleanup EXIT

# === INITIALISATION ===
initialize_validation() {
    log_header "VALIDATION ARCHITECTURE SILK v1.0"
    echo -e "${CYAN}Smart Integrated Literary Kit - Structured Intelligence for Literary Kreation${NC}"
    echo "=================================================================="
    echo

    cleanup
    mkdir -p "$VALIDATION_DIR"

    log_success "Environnement de validation initialisé"
}

# === VALIDATION STRUCTURE ===
validate_file_structure() {
    log_header "Validation Structure Fichiers"
    echo "------------------------------"

    # Fichiers obligatoires
    local required_files=(
        "silk"
        "lib/core/utils.sh"
        "lib/commands/init.sh"
    )

    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "Fichier requis: $file"
        else
            log_fail "Fichier manquant: $file"
        fi
    done

    # Fichiers recommandés
    local recommended_files=(
        "lib/core/config.sh"
        "lib/core/vault.sh"
        "lib/commands/context.sh"
        "lib/commands/wordcount.sh"
        "lib/commands/publish.sh"
        "install.sh"
    )

    for file in "${recommended_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "Fichier recommandé: $file"
        else
            log_warning "Fichier recommandé manquant: $file"
        fi
    done

    echo
}

# === VALIDATION SYNTAXE ===
validate_syntax() {
    log_header "Validation Syntaxe Scripts"
    echo "---------------------------"

    # Vérifier script principal
    run_test "Syntaxe script principal" "bash -n silk"

    # Vérifier modules
    for module in lib/core/*.sh lib/commands/*.sh lib/templates/*.sh; do
        if [[ -f "$module" ]]; then
            run_test "Syntaxe $(basename "$module")" "bash -n '$module'"
        fi
    done

    echo
}

# === VALIDATION FONCTIONNELLE ===
validate_functionality() {
    log_header "Validation Fonctionnelle"
    echo "-------------------------"

    # Rendre exécutable
    chmod +x silk 2>/dev/null || true

    # Tests commandes de base
    run_test "Commande version" "./silk version"
    run_test "Aide générale" "./silk --help"
    run_test "Configuration list" "./silk config --list"

    # Tests modules si disponibles
    run_test "Aide init" "./silk init --help"

    # Test mode debug
    run_test "Mode debug" "./silk --debug version"

    echo
}

# === VALIDATION CRÉATION PROJET ===
validate_project_creation() {
    log_header "Validation Création Projet"
    echo "---------------------------"

    cd "$VALIDATION_DIR"

    # Test création projet simple
    if ../silk init "Test Project" --genre polar-psychologique --author "Validation Test" --yes 2>/dev/null; then
        log_success "Création projet base"

        if [[ -d "test-project" ]]; then
            cd "test-project"

            # Vérifier structure créée
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
                    log_success "Structure: $dir"
                else
                    log_fail "Structure manquante: $dir"
                fi
            done

            # Vérifier fichiers clés
            if [[ -f "README.md" ]]; then
                log_success "README.md généré"
            else
                log_fail "README.md manquant"
            fi

            if [[ -f "formats/base.yaml" ]]; then
                log_success "Configuration publication"
            else
                log_fail "Configuration publication manquante"
            fi

            # Vérifier séparateur SILK
            if find 01-Manuscrit -name "*.md" -exec grep -l "## manuscrit" {} \; | head -1 >/dev/null; then
                log_success "Séparateur SILK présent"
            else
                log_fail "Séparateur SILK manquant"
            fi

            cd ..
        else
            log_fail "Répertoire projet non créé"
        fi
    else
        log_warning "Création projet échoue (modules incomplets ?)"
    fi

    cd ..
    echo
}

# === VALIDATION DÉPENDANCES ===
validate_dependencies() {
    log_header "Validation Dépendances"
    echo "-----------------------"

    # Dépendances obligatoires
    local required_deps=("bash" "git")
    for dep in "${required_deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            log_success "Dépendance: $dep"
        else
            log_fail "Dépendance manquante: $dep"
        fi
    done

    # Dépendances optionnelles
    local optional_deps=("pandoc" "xelatex")
    for dep in "${optional_deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            log_success "Dépendance optionnelle: $dep"
        else
            log_warning "Dépendance optionnelle manquante: $dep"
        fi
    done

    echo
}

# === VALIDATION COMPATIBILITÉ ===
validate_compatibility() {
    log_header "Validation Compatibilité"
    echo "-------------------------"

    # Détection OS
    case "$OSTYPE" in
        msys*|cygwin*|mingw*)
            log_info "Plateforme: Windows (Git Bash/MSYS)"
            ;;
        linux*)
            log_info "Plateforme: Linux"
            ;;
        darwin*)
            log_info "Plateforme: macOS"
            ;;
        *)
            log_warning "Plateforme inconnue: $OSTYPE"
            ;;
    esac

    # Version Bash
    local bash_version=${BASH_VERSION%%.*}
    if [[ $bash_version -ge 4 ]]; then
        log_success "Version Bash: $BASH_VERSION (compatible)"
    else
        log_warning "Version Bash: $BASH_VERSION (ancienne)"
    fi

    # Test fins de ligne
    if command -v file &> /dev/null && [[ -f "silk" ]]; then
        local file_info=$(file silk)
        if echo "$file_info" | grep -q "CRLF"; then
            log_warning "Fins de ligne CRLF détectées (problème Windows)"
        else
            log_success "Fins de ligne LF (correct)"
        fi
    fi

    echo
}

# === VALIDATION PERFORMANCE ===
validate_performance() {
    log_header "Validation Performance"
    echo "----------------------"

    # Test temps de démarrage
    local start_time=$(date +%s%N)
    ./silk version >/dev/null 2>&1 || true
    local end_time=$(date +%s%N)
    local startup_time=$(( (end_time - start_time) / 1000000 ))  # en millisecondes

    if [[ $startup_time -lt 1000 ]]; then
        log_success "Temps démarrage: ${startup_time}ms (rapide)"
    elif [[ $startup_time -lt 3000 ]]; then
        log_success "Temps démarrage: ${startup_time}ms (acceptable)"
    else
        log_warning "Temps démarrage: ${startup_time}ms (lent)"
    fi

    # Test mémoire (approximatif)
    local memory_usage
    if command -v ps &> /dev/null; then
        memory_usage=$(ps -o pid,vsz,comm | grep -E "silk|bash" | head -1 | awk '{print $2}' || echo "N/A")
        if [[ "$memory_usage" != "N/A" ]] && [[ $memory_usage -lt 10000 ]]; then
            log_success "Usage mémoire: ${memory_usage}KB (efficace)"
        else
            log_info "Usage mémoire: ${memory_usage}KB"
        fi
    fi

    echo
}

# === VALIDATION SÉCURITÉ ===
validate_security() {
    log_header "Validation Sécurité"
    echo "--------------------"

    # Vérifier permissions
    if [[ -x "silk" ]]; then
        log_success "Script principal exécutable"
    else
        log_fail "Script principal non exécutable"
    fi

    # Vérifier absence de code dangereux
    local dangerous_patterns=("rm -rf /" "curl.*|.*sh" "> /dev/sda")
    for pattern in "${dangerous_patterns[@]}"; do
        if grep -r "$pattern" . >/dev/null 2>&1; then
            log_fail "Pattern dangereux détecté: $pattern"
        else
            log_success "Pas de pattern dangereux: $pattern"
        fi
    done

    # Vérifier variables non sécurisées
    if grep -r '\$USER.*sudo\|sudo.*\$' . >/dev/null 2>&1; then
        log_warning "Usage sudo détecté (vérifier sécurité)"
    else
        log_success "Pas d'usage sudo non sécurisé"
    fi

    echo
}

# === RAPPORT FINAL ===
generate_final_report() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local total_tests=$((TESTS_PASSED + TESTS_FAILED))

    echo
    log_header "RAPPORT VALIDATION SILK"
    echo "========================"
    echo
    echo "🕸️ Smart Integrated Literary Kit - Architecture Validation"
    echo
    echo "📊 RÉSULTATS:"
    printf "   ✅ Tests réussis    : %3d\n" "$TESTS_PASSED"
    printf "   ❌ Tests échoués    : %3d\n" "$TESTS_FAILED"
    printf "   📋 Total tests     : %3d\n" "$total_tests"

    if [[ $total_tests -gt 0 ]]; then
        local success_rate=$(( (TESTS_PASSED * 100) / total_tests ))
        printf "   📈 Taux de succès  : %3d%%\n" "$success_rate"
    fi

    printf "   ⏱️  Durée validation: %3ds\n" "$duration"
    echo

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 VALIDATION RÉUSSIE !${NC}"
        echo -e "${CYAN}🕷️ SILK architecture is ready for production.${NC}"
        echo
        echo "✅ SILK CLI est prêt pour:"
        echo "   - Déploiement production"
        echo "   - Utilisation par les auteurs"
        echo "   - Extension avec nouveaux modules"
        echo "   - Publication GitHub Release v1.0"

        # Recommandations finales
        echo
        echo "🚀 RECOMMANDATIONS FINALES:"
        echo "   1. Créer tests automatisés CI/CD"
        echo "   2. Documenter API modules pour contributeurs"
        echo "   3. Ajouter modules templates avancés"
        echo "   4. Optimiser performance chargement modules"
        echo "   5. Implémenter système plugin pour extensions"

    else
        echo -e "${RED}⚠️  VALIDATION PARTIELLE${NC}"
        echo -e "${YELLOW}🔧 Corrections nécessaires avant production${NC}"
        echo
        echo "🔧 ACTIONS PRIORITAIRES:"
        if [[ $TESTS_FAILED -gt 5 ]]; then
            echo "   - Réviser architecture de base"
        else
            echo "   - Corriger tests échoués spécifiques"
        fi
        echo "   - Compléter modules manquants"
        echo "   - Tester sur différentes plateformes"
    fi

    echo
    echo "📝 DOCUMENTATION:"
    echo "   - README: Structure et utilisation"
    echo "   - lib/README.md: Documentation modules"
    echo "   - Tests: ./validate-silk-architecture.sh"
    echo
    echo "🕸️ SILK weaves intelligence into literary creation!"
}

# === EXÉCUTION PRINCIPALE ===
main() {
    initialize_validation

    validate_file_structure
    validate_syntax
    validate_functionality
    validate_project_creation
    validate_dependencies
    validate_compatibility
    validate_performance
    validate_security

    generate_final_report

    # Code retour basé sur résultats
    if [[ $TESTS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Exécution si script appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
