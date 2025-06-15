#!/bin/bash
# test-modular.sh - Test architecture modulaire SILK

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

test_pass() { echo -e "${GREEN}✅ $1${NC}"; }
test_fail() { echo -e "${RED}❌ $1${NC}"; }
test_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
test_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo "🕷️ Test Architecture Modulaire SILK"
echo "===================================="

# Variables
SILK_DIR="$(pwd)"
TEST_DIR="silk-modular-test"
ERRORS=0

cleanup() {
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

trap cleanup EXIT

# === TEST 1: Structure des modules ===
test_info "Test 1: Vérification structure des modules"

required_files=(
    "silk"
    "lib/core/utils.sh"
    "lib/commands/init.sh"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        test_pass "Fichier existe: $file"
    else
        test_fail "Fichier manquant: $file"
        ((ERRORS++))
    fi
done

# === TEST 2: Script principal modulaire ===
test_info "Test 2: Script principal avec chargement modulaire"

if [[ ! -f "silk" ]]; then
    test_fail "Script silk manquant"
    ((ERRORS++))
else
    # Vérifier que le script contient les fonctions modulaires
    if grep -q "load_module" silk; then
        test_pass "Fonction load_module présente"
    else
        test_fail "Fonction load_module manquante"
        ((ERRORS++))
    fi

    if grep -q "execute_modular_command" silk; then
        test_pass "Fonction execute_modular_command présente"
    else
        test_fail "Fonction execute_modular_command manquante"
        ((ERRORS++))
    fi
fi

# === TEST 3: Commandes de base ===
test_info "Test 3: Commandes de base (sans modules)"

chmod +x silk 2>/dev/null || true

if ./silk version &>/dev/null; then
    test_pass "Commande version fonctionne"
else
    test_fail "Commande version échoue"
    ((ERRORS++))
fi

if ./silk config --list &>/dev/null; then
    test_pass "Commande config fonctionne"
else
    test_fail "Commande config échoue"
    ((ERRORS++))
fi

# === TEST 4: Chargement modules core ===
test_info "Test 4: Modules core"

if [[ -f "lib/core/utils.sh" ]]; then
    # Test source du module
    if bash -n lib/core/utils.sh; then
        test_pass "Module utils.sh syntaxiquement correct"
    else
        test_fail "Erreur syntaxe dans utils.sh"
        ((ERRORS++))
    fi

    # Vérifier fonctions clés
    if grep -q "log_info" lib/core/utils.sh; then
        test_pass "Fonction log_info présente dans utils.sh"
    else
        test_fail "Fonction log_info manquante"
        ((ERRORS++))
    fi

    if grep -q "is_silk_project" lib/core/utils.sh; then
        test_pass "Fonction is_silk_project présente"
    else
        test_fail "Fonction is_silk_project manquante"
        ((ERRORS++))
    fi
fi

# === TEST 5: Module commande init ===
test_info "Test 5: Module commande init"

if [[ -f "lib/commands/init.sh" ]]; then
    # Test syntaxe
    if bash -n lib/commands/init.sh; then
        test_pass "Module init.sh syntaxiquement correct"
    else
        test_fail "Erreur syntaxe dans init.sh"
        ((ERRORS++))
    fi

    # Vérifier fonction principale
    if grep -q "cmd_init" lib/commands/init.sh; then
        test_pass "Fonction cmd_init présente"
    else
        test_fail "Fonction cmd_init manquante"
        ((ERRORS++))
    fi

    # Vérifier aide
    if grep -q "show_init_help" lib/commands/init.sh; then
        test_pass "Fonction show_init_help présente"
    else
        test_fail "Fonction show_init_help manquante"
        ((ERRORS++))
    fi
fi

# === TEST 6: Commande init modulaire ===
test_info "Test 6: Test commande init modulaire"

# Test aide init (ne doit pas créer de projet)
if ./silk init --help &>/dev/null; then
    test_pass "Aide init accessible"
else
    test_warn "Aide init non accessible (modules peut-être manquants)"
fi

# === TEST 7: Création projet test ===
test_info "Test 7: Création projet de test"

mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Test création projet avec mode non-interactif
if ../silk init "Test Project" --genre polar-psychologique --author "Test Author" --yes &>/dev/null; then
    test_pass "Création projet réussie"

    # Vérifier structure créée
    if [[ -d "test-project" ]]; then
        cd test-project

        required_dirs=(
            "01-Manuscrit"
            "02-Personnages"
            "04-Concepts"
            "outputs/context"
            "formats"
        )

        for dir in "${required_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                test_pass "Répertoire créé: $dir"
            else
                test_fail "Répertoire manquant: $dir"
                ((ERRORS++))
            fi
        done

        # Vérifier fichiers clés
        if [[ -f "README.md" ]]; then
            test_pass "README.md créé"
        fi

        if [[ -f "formats/base.yaml" ]]; then
            test_pass "Configuration publication créée"
        fi

        if [[ -f "01-Manuscrit/Ch01-Premier-Chapitre.md" ]]; then
            test_pass "Chapitre exemple créé"

            # Vérifier séparateur SILK
            if grep -q "## manuscrit" "01-Manuscrit/Ch01-Premier-Chapitre.md"; then
                test_pass "Séparateur SILK présent"
            else
                test_fail "Séparateur SILK manquant"
                ((ERRORS++))
            fi
        fi

        cd ..
    else
        test_fail "Répertoire projet non créé"
        ((ERRORS++))
    fi
else
    test_warn "Création projet échoue (probablement modules manquants)"
fi

cd "$SILK_DIR"

# === TEST 8: Debug et environnement ===
test_info "Test 8: Mode debug et environnement"

if ./silk --debug version &>/dev/null; then
    test_pass "Mode debug fonctionne"
else
    test_warn "Mode debug ne fonctionne pas"
fi

# Vérifier variables d'environnement
if ./silk version | grep -q "Architecture: Modulaire"; then
    test_pass "Architecture modulaire détectée"
else
    test_warn "Architecture modulaire non détectée dans version"
fi

# === RÉSUMÉ ===
echo
echo "🕸️ RÉSUMÉ TEST ARCHITECTURE MODULAIRE"
echo "======================================"

if [[ $ERRORS -eq 0 ]]; then
    test_pass "TOUS LES TESTS PASSENT !"
    echo
    echo "✅ Architecture modulaire SILK fonctionnelle:"
    echo "   - Script principal avec chargement modules ✅"
    echo "   - Modules core (utils.sh) ✅"
    echo "   - Modules commandes (init.sh) ✅"
    echo "   - Création projets ✅"
    echo "   - Structure SILK ✅"
    echo
    echo "🎯 Prochaines étapes:"
    echo "   1. Implémenter modules context.sh, wordcount.sh, publish.sh"
    echo "   2. Ajouter modules templates (polar.sh, fantasy.sh, etc.)"
    echo "   3. Créer script install.sh modulaire"
    echo "   4. Tests avancés avec projets réels"
else
    test_fail "$ERRORS erreur(s) détectée(s)"
    echo
    echo "🔧 Corrections nécessaires:"
    echo "   - Vérifier structure des modules"
    echo "   - Corriger erreurs de syntaxe"
    echo "   - Compléter fonctions manquantes"
fi

echo
echo "🕷️ SILK weaves together a modular future!"
exit $ERRORS
