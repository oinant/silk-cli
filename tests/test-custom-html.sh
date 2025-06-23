#!/bin/bash
# tests/test-custom-html.sh - Tests pour génération HTML custom

source "lib/core/utils.sh" 2>/dev/null || {
    echo "❌ Framework SILK requis"
    exit 1
}

echo "🕸️ Tests génération HTML custom SILK"
echo "===================================="

# Test basique
echo
echo "📋 Test 1: Détection custom_structure"

if [[ "$(detect_custom_structure "html-custom")" == "true" ]]; then
    echo "✅ Détection format html-custom"
else
    echo "❌ Détection échoue"
fi

echo
echo "🎯 Pour test complet:"
echo "  1. Créer projet SILK: silk init \"Test HTML\""
echo "  2. Ajouter du contenu dans 01-Manuscrit/"
echo "  3. Tester: silk publish -f html-custom"
echo "  4. Vérifier: ls outputs/publish/*.html"
