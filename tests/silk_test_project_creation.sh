#!/bin/bash
# Test création projet SILK

set -euo pipefail

echo "🕷️ Test Création Projet SILK"
echo "============================="

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

test_pass() { echo -e "${GREEN}✅ $1${NC}"; }
test_fail() { echo -e "${RED}❌ $1${NC}"; }
test_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Nettoyage préventif
cleanup() {
    if [[ -d "test-polar-project" ]]; then
        rm -rf test-polar-project
        echo "🧹 Nettoyage projet test existant"
    fi
}

# Cleanup au début et à la sortie
cleanup
trap cleanup EXIT

# Test création projet
echo
test_info "Test 1: Création projet SILK"
if ./silk init "Test Polar Project" --genre polar-psychologique --author "Test Author" --yes; then
    test_pass "Projet créé avec succès"
else
    test_fail "Échec création projet"
    exit 1
fi

# Vérifier structure créée
echo
test_info "Test 2: Vérification structure"
if [[ -d "test-polar-project" ]]; then
    test_pass "Répertoire projet créé"

    cd test-polar-project

    # Vérifier répertoires SILK
    required_dirs=("01-Manuscrit" "02-Personnages" "04-Concepts" "outputs/context" "formats")
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            test_pass "Structure: $dir"
        else
            test_fail "Structure manquante: $dir"
        fi
    done

    # Vérifier fichiers clés
    if [[ -f "README.md" ]]; then
        test_pass "README.md généré"
    fi

    if [[ -f "formats/base.yaml" ]]; then
        test_pass "Configuration publication"
    fi

    # Vérifier Git
    if [[ -d ".git" ]]; then
        test_pass "Repository Git initialisé"
    fi

    cd ..
else
    test_fail "Répertoire projet non créé"
    exit 1
fi

# Test commandes de base dans le projet
echo
test_info "Test 3: Commandes dans projet"
cd test-polar-project

if ../silk context --help > /dev/null 2>&1; then
    test_pass "Aide context accessible"
else
    test_fail "Aide context non accessible"
fi

if ../silk wordcount --help > /dev/null 2>&1; then
    test_pass "Aide wordcount accessible"
else
    test_info "Aide wordcount non implémentée (normal)"
fi

cd ..

echo
echo "✅ Test création projet terminé"
echo "💡 Projet 'test-polar-project' prêt pour tests suivants"

# Ne pas nettoyer à la fin pour les tests suivants
trap - EXIT
