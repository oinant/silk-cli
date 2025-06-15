#!/bin/bash
# Test compatibilité architecture modulaire

set -euo pipefail

echo "🕷️ Test Compatibilité Architecture Modulaire"
echo "============================================="

errors=0

# Test script principal
echo "📝 Test script principal..."
if [[ -f "silk" ]] && [[ -x "silk" ]]; then
    echo "✅ Script silk présent et exécutable"
else
    echo "❌ Script silk manquant ou non exécutable"
    ((errors++))
fi

# Test modules core
echo "📝 Test modules core..."
for module in lib/core/*.sh; do
    if [[ -f "$module" ]]; then
        echo "✅ Module: $(basename "$module")"
        if bash -n "$module" 2>/dev/null; then
            echo "   ✅ Syntaxe correcte"
        else
            echo "   ❌ Erreur syntaxe"
            ((errors++))
        fi
    fi
done

# Test modules commands
echo "📝 Test modules commands..."
for module in lib/commands/*.sh; do
    if [[ -f "$module" ]]; then
        echo "✅ Module: $(basename "$module")"
        if bash -n "$module" 2>/dev/null; then
            echo "   ✅ Syntaxe correcte"
        else
            echo "   ❌ Erreur syntaxe"
            ((errors++))
        fi
    fi
done

# Test commandes de base
echo "📝 Test commandes..."
if ./silk version &>/dev/null; then
    echo "✅ silk version"
else
    echo "❌ silk version échoue"
    ((errors++))
fi

if ./silk config --list &>/dev/null; then
    echo "✅ silk config"
else
    echo "❌ silk config échoue"
    ((errors++))
fi

if ./silk init --help &>/dev/null; then
    echo "✅ silk init --help"
else
    echo "⚠️  silk init --help (peut-être pas encore implémenté)"
fi

# Résumé
echo
if [[ $errors -eq 0 ]]; then
    echo "🎉 Tous les tests de compatibilité passent !"
    echo "🕸️ Architecture modulaire SILK opérationnelle"
else
    echo "⚠️  $errors erreur(s) détectée(s)"
    echo "🔧 Vérifiez l'implémentation des modules"
fi

exit $errors
