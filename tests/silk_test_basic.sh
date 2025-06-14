#!/bin/bash
# Tests basiques SILK CLI

set -euo pipefail

echo "🕷️ Tests SILK CLI - Smart Integrated Literary Kit"
echo "=================================================="

# Couleurs pour les tests
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

test_pass() { echo -e "${GREEN}✅ $1${NC}"; }
test_fail() { echo -e "${RED}❌ $1${NC}"; }
test_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Vérifier que le script existe et est exécutable
echo
test_info "Test 1: Vérification script silk"
if [[ -f "./silk" && -x "./silk" ]]; then
    test_pass "Script silk trouvé et exécutable"
else
    test_fail "Script silk manquant ou pas exécutable"
    echo "   💡 Exécutez: chmod +x silk"
    exit 1
fi

# Test version
echo
test_info "Test 2: Commande version"
if ./silk version; then
    test_pass "Version affichée correctement"
else
    test_fail "Erreur commande version"
fi

# Test aide générale
echo
test_info "Test 3: Aide générale"
if ./silk --help > /dev/null 2>&1; then
    test_pass "Aide générale fonctionne"
else
    test_fail "Erreur aide générale"
fi

# Test aides sous-commandes
echo
test_info "Test 4: Aides sous-commandes"
commands=("init" "context" "wordcount" "publish" "config")
for cmd in "${commands[@]}"; do
    if ./silk "$cmd" --help > /dev/null 2>&1; then
        test_pass "Aide $cmd OK"
    else
        test_fail "Aide $cmd échoue"
    fi
done

# Test configuration
echo
test_info "Test 5: Configuration"
if ./silk config --list > /dev/null 2>&1; then
    test_pass "Configuration accessible"
else
    test_fail "Erreur configuration"
fi

echo
echo "🕸️ Tests basiques terminés"
echo "Pour tests avancés, voir: ./tests/test_silk_advanced.sh"