#!/bin/bash
# Suite de tests maître SILK CLI

set -euo pipefail

# === CONFIGURATION TESTS ===
SILK_TEST_DIR="silk-test-suite"
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
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}❌ $1${NC}"; ((TESTS_FAILED++)); }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log_info "Exécution: $test_name"
    if eval "$test_command" > /dev/null 2>&1; then
        log_success "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

run_test_verbose() {
    local test_name="$1"
    local test_command="$2"
    
    log_info "Exécution: $test_name"
    if eval "$test_command"; then
        log_success "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

# === NETTOYAGE ===
cleanup() {
    if [[ -d "$SILK_TEST_DIR" ]]; then
        log_info "Nettoyage environnement test..."
        rm -rf "$SILK_TEST_DIR"
    fi
}

trap cleanup EXIT

# === INITIALISATION ===
initialize_test_environment() {
    log_header "SILK CLI - Test Suite Maître v1.0"
    echo -e "${CYAN}Smart Integrated Literary Kit - Structured Intelligence for Literary Kreation${NC}"
    echo "=================================================================="
    echo
    
    # Créer environnement test propre
    cleanup
    mkdir -p "$SILK_TEST_DIR"
    cd "$SILK_TEST_DIR"
    
    # Copier silk script
    cp ../silk . 2>/dev/null || {
        log_fail "Script silk non trouvé dans répertoire parent"
        exit 1
    }
    
    chmod +x silk
    log_success "Environnement test initialisé"
}

# === TESTS UNITAIRES ===
test_basic_functionality() {
    log_header "Tests Basiques"
    echo "-------------"
    
    run_test "Version SILK" "./silk version"
    run_test "Aide générale" "./silk --help"
    run_test "Aide init" "./silk init --help"
    run_test "Aide context" "./silk context --help"
    run_test "Aide wordcount" "./silk wordcount --help"
    run_test "Aide publish" "./silk publish --help"
    run_test "Aide config" "./silk config --help"
    
    echo
}

test_configuration() {
    log_header "Tests Configuration"
    echo "-------------------"
    
    run_test "Config list" "./silk config --list"
    run_test "Config set" "./silk config --set SILK_AUTHOR_NAME='Test Author'"
    run_test "Config get" "./silk config --get SILK_AUTHOR_NAME"
    run_test "Config validation" "test \"\$(./silk config --get SILK_AUTHOR_NAME)\" = 'Test Author'"
    
    echo
}

test_project_creation() {
    log_header "Tests Création Projet"
    echo "---------------------"
    
    # Test polar (genre principal)
    run_test_verbose "Création projet polar" \
        "./silk init 'Test Polar' --genre polar-psychologique --author 'Test Author' --words 60000 --chapters 25 --yes"
    
    if [[ -d "test-polar" ]]; then
        cd test-polar
        
        # Vérifier structure
        local structure_ok=true
        for dir in "01-Manuscrit" "02-Personnages" "04-Concepts" "outputs/context" "formats"; do
            if [[ ! -d "$dir" ]]; then
                structure_ok=false
                break
            fi
        done
        
        if [[ "$structure_ok" == true ]]; then
            log_success "Structure projet polar"
        else
            log_fail "Structure projet polar incomplète"
        fi
        
        # Vérifier contenu spécialisé
        if grep -q "polar-psychologique" "00-instructions-llm/instructions.md" 2>/dev/null; then
            log_success "Templates polar spécialisés"
        else
            log_fail "Templates polar manquants"
        fi
        
        cd ..
    else
        log_fail "Répertoire projet non créé"
    fi
    
    # Test fantasy
    run_test "Création projet fantasy" \
        "./silk init 'Test Fantasy' --genre fantasy --author 'Test Author' --yes"
    
    if [[ -d "test-fantasy" && -d "test-fantasy/05-Worldbuilding" ]]; then
        log_success "Projet fantasy avec worldbuilding"
    else
        log_fail "Structure fantasy incomplète"
    fi
    
    echo
}

test_content_and_context() {
    log_header "Tests Contenu et Contexte"
    echo "-------------------------"
    
    if [[ ! -d "test-polar" ]]; then
        log_fail "Projet test manquant - créer d'abord"
        return 1
    fi
    
    cd test-polar
    
    # Créer contenu test
    cat > "01-Manuscrit/Ch01-Test.md" << 'EOF'
# Ch.01 : Chapitre Test

## Objectifs SILK
- **Intrigue** : Test contexte LLM
- **Développement** : Validation extraction

## manuscrit

Ceci est un test de contenu pour SILK CLI.

Le commissaire Claire Moreau observait la scène de crime. Quelque chose clochait dans cette mise en scène trop parfaite.

— Des indices ? demanda son équipier.
— Trop d'indices, justement, répondit-elle.
EOF

    cat > "01-Manuscrit/Ch02-Suite.md" << 'EOF'
# Ch.02 : Suite Test

## manuscrit

La suite de l'enquête révéla des éléments troublants.

Claire découvrit que la victime avait reçu des menaces la semaine précédente.
EOF

    cat > "02-Personnages/Claire-Moreau.md" << 'EOF'
# Claire Moreau

## Identité
- **Âge** : 42 ans  
- **Fonction** : Commissaire enquêtrice

## Psychologie SILK
Déterminée mais vulnérable.
EOF

    # Tests contexte
    run_test "Contexte normal" "../silk context 'Test cohérence'"
    run_test "Contexte avec range" "../silk context 'Test range' --chapters 1-2"
    run_test "Contexte complet" "../silk context 'Test complet' --full"
    
    # Vérifier fichiers générés
    if [[ -f "outputs/context/manuscrit.md" ]]; then
        local word_count=$(wc -w < "outputs/context/manuscrit.md")
        if [[ $word_count -gt 50 ]]; then
            log_success "Contexte manuscrit généré ($word_count mots)"
        else
            log_fail "Contexte manuscrit trop court"
        fi
    else
        log_fail "Fichier contexte manuscrit non généré"
    fi
    
    # Test contenu contexte
    if grep -q "Claire Moreau" "outputs/context/manuscrit.md" 2>/dev/null; then
        log_success "Contenu chapitre extrait correctement"
    else
        log_fail "Contenu chapitre non extrait"
    fi
    
    cd ..
    echo
}

test_analytics() {
    log_header "Tests Analytics"
    echo "---------------"
    
    if [[ ! -d "test-polar" ]]; then
        log_fail "Projet test manquant"
        return 1
    fi
    
    cd test-polar
    
    run_test "Wordcount par défaut" "../silk wordcount"
    run_test "Wordcount objectif" "../silk wordcount 50000"
    run_test "Wordcount résumé" "../silk wordcount --summary"
    
    # Vérifier calculs
    local output
    output=$(../silk wordcount --summary 2>/dev/null || echo "")
    if echo "$output" | grep -q "Total.*mots"; then
        log_success "Calculs statistiques fonctionnels"
    else
        log_fail "Calculs statistiques défaillants"
    fi
    
    cd ..
    echo
}

test_publishing() {
    log_header "Tests Publication"
    echo "----------------"
    
    # Vérifier dépendances
    local pandoc_available=false
    local xelatex_available=false
    
    if command -v pandoc &> /dev/null; then
        pandoc_available=true
        log_success "Pandoc disponible"
    else
        log_warning "Pandoc non disponible (tests limités)"
    fi
    
    if command -v xelatex &> /dev/null; then
        xelatex_available=true
        log_success "XeLaTeX disponible"
    else
        log_warning "XeLaTeX non disponible (tests limités)"
    fi
    
    if [[ ! -d "test-polar" ]]; then
        log_fail "Projet test manquant"
        return 1
    fi
    
    cd test-polar
    
    # Tests basiques publication
    run_test "Aide publish" "../silk publish --help"
    
    # Vérifier formats
    local formats_ok=true
    for format in "digital" "iphone" "kindle" "book"; do
        if [[ ! -f "formats/$format.yaml" ]]; then
            formats_ok=false
            break
        fi
    done
    
    if [[ "$formats_ok" == true ]]; then
        log_success "Formats publication disponibles"
    else
        log_fail "Formats publication manquants"
    fi
    
    # Test publication réelle si dépendances présentes
    if [[ "$pandoc_available" == true && "$xelatex_available" == true ]]; then
        if ../silk publish -f digital --chapters 2 2>/dev/null; then
            if ls outputs/publish/*.pdf &> /dev/null; then
                log_success "Publication PDF réussie"
            else
                log_fail "PDF non généré"
            fi
        else
            log_fail "Échec publication PDF"
        fi
    else
        log_warning "Publication PDF non testée (dépendances manquantes)"
    fi
    
    cd ..
    echo
}

test_error_handling() {
    log_header "Tests Gestion Erreurs"
    echo "---------------------"
    
    # Commande inexistante
    if ./silk inexistante 2>/dev/null; then
        log_fail "Commande inexistante acceptée"
    else
        log_success "Commande inexistante rejetée"
    fi
    
    # Hors projet SILK
    mkdir temp-non-silk
    cd temp-non-silk
    
    if ../silk wordcount 2>/dev/null; then
        log_fail "Commande hors projet acceptée"
    else
        log_success "Détection hors projet SILK"
    fi
    
    cd ..
    rm -rf temp-non-silk
    
    # Configuration invalide
    if ./silk config --set INVALID_KEY=value 2>/dev/null; then
        log_fail "Configuration invalide acceptée"
    else
        log_success "Configuration invalide rejetée"
    fi
    
    echo
}

test_integration() {
    log_header "Tests Intégration"
    echo "-----------------"
    
    # Test workflow complet
    log_info "Test workflow complet SILK..."
    
    # 1. Création projet
    if ./silk init "Integration Test" --genre literary --author "Integration Bot" --yes; then
        cd integration-test
        
        # 2. Ajout contenu
        echo -e "# Ch.01 : Test\n\n## manuscrit\n\nContenu intégration." > "01-Manuscrit/Ch01-Integration.md"
        
        # 3. Contexte
        if ../silk context "Test intégration" >/dev/null 2>&1; then
            # 4. Analytics  
            if ../silk wordcount >/dev/null 2>&1; then
                # 5. Configuration
                if ../silk config --set SILK_DEFAULT_TARGET_WORDS=45000 >/dev/null 2>&1; then
                    log_success "Workflow intégration complet"
                else
                    log_fail "Workflow intégration - config"
                fi
            else
                log_fail "Workflow intégration - analytics"
            fi
        else
            log_fail "Workflow intégration - contexte"
        fi
        
        cd ..
    else
        log_fail "Workflow intégration - création"
    fi
    
    echo
}

# === RAPPORT FINAL ===
generate_report() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local total_tests=$((TESTS_PASSED + TESTS_FAILED))
    
    echo
    log_header "RAPPORT TESTS SILK CLI"
    echo "======================"
    echo
    echo "🕸️ Smart Integrated Literary Kit - Suite de Tests"
    echo
    echo "📊 RÉSULTATS:"
    echo "   ✅ Tests réussis    : $TESTS_PASSED"
    echo "   ❌ Tests échoués    : $TESTS_FAILED"
    echo "   📋 Total tests     : $total_tests"
    
    if [[ $total_tests -gt 0 ]]; then
        local success_rate=$(( (TESTS_PASSED * 100) / total_tests ))
        echo "   📈 Taux de succès  : $success_rate%"
    fi
    
    echo "   ⏱️  Durée          : ${duration}s"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 TOUS LES TESTS SILK PASSENT !${NC}"
        echo -e "${CYAN}🕷️ SILK is ready to weave literary magic.${NC}"
        echo
        echo "✅ SILK CLI est prêt pour:"
        echo "   - Déploiement production"
        echo "   - Distribution aux utilisateurs"
        echo "   - Intégration CI/CD"
        echo "   - Publication GitHub Release"
    else
        echo -e "${RED}⚠️  CERTAINS TESTS ÉCHOUENT${NC}"
        echo -e "${YELLOW}🔧 Corrections nécessaires avant déploiement${NC}"
    fi
    
    echo
    echo "📝 PROCHAINES ÉTAPES:"
    echo "   1. Corriger tests échoués si nécessaire"
    echo "   2. Intégrer script silk dans votre repo"
    echo "   3. Mettre à jour README avec branding SILK"
    echo "   4. Configurer CI/CD pour tests automatiques"
    echo "   5. Créer release GitHub v1.0.0"
    echo
    echo "🕸️ SILK weaves your development into success!"
}

# === EXÉCUTION PRINCIPALE ===
main() {
    initialize_test_environment
    
    test_basic_functionality
    test_configuration  
    test_project_creation
    test_content_and_context
    test_analytics
    test_publishing
    test_error_handling
    test_integration
    
    generate_report
    
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