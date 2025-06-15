#!/bin/bash
# Vérification syntaxe tous les scripts SILK

echo "🕷️ SILK CLI - Vérification Syntaxe Complète"
echo "============================================"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

errors=0
warnings=0
total=0

check_syntax() {
    local file="$1"
    local name="$(basename "$file")"
    ((total++))

    echo -n "📝 $name: "

    if bash -n "$file" 2>/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ ERREUR${NC}"
        echo -e "${YELLOW}   Détails:${NC}"
        bash -n "$file" 2>&1 | sed 's/^/   /'
        ((errors++))
        echo
    fi
}

echo "🔍 Vérification script principal:"
check_syntax "silk"

echo
echo "🔍 Vérification modules core:"
for file in lib/core/*.sh; do
    [[ -f "$file" ]] && check_syntax "$file"
done

echo
echo "🔍 Vérification modules commands:"
for file in lib/commands/*.sh; do
    [[ -f "$file" ]] && check_syntax "$file"
done

echo
echo "🔍 Vérification modules templates:"
for file in lib/templates/*.sh; do
    [[ -f "$file" ]] && check_syntax "$file"
done

echo
echo "🔍 Vérification scripts tests:"
for file in tests/*.sh; do
    [[ -f "$file" ]] && check_syntax "$file"
done

echo
echo "🔍 Vérification scripts racine:"
for file in *.sh; do
    [[ -f "$file" ]] && [[ "$file" != "check-syntax.sh" ]] && check_syntax "$file"
done

echo
echo "📊 RÉSUMÉ:"
echo "   Total fichiers : $total"
echo -e "   ✅ Corrects    : $((total - errors))"
echo -e "   ❌ Erreurs     : $errors"

if [[ $errors -eq 0 ]]; then
    echo -e "\n🎉 ${GREEN}TOUTE LA SYNTAXE EST CORRECTE !${NC}"
    echo "🕸️ SILK CLI ready for production!"
else
    echo -e "\n⚠️  ${RED}$errors ERREUR(S) À CORRIGER${NC}"
    echo "🔧 Corrigez les erreurs avant de continuer"
fi

exit $errors
