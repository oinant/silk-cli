#!/bin/bash
# Script de normalisation pour compatibilité WSL/Windows

set -euo pipefail

echo "🔧 Normalisation scripts pour compatibilité WSL/Windows"

# Fonction pour convertir un fichier
normalize_file() {
    local file="$1"

    if [[ -f "$file" ]]; then
        # Vérifier si dos2unix est disponible
        if command -v dos2unix &> /dev/null; then
            dos2unix "$file" 2>/dev/null
        else
            # Conversion manuelle CRLF -> LF
            sed -i 's/\r$//' "$file" 2>/dev/null || true
        fi

        # S'assurer que le fichier est exécutable
        if [[ "$file" == *.sh ]] || [[ "$(basename "$file")" == "silk" ]] || [[ "$(basename "$file")" == "install.sh" ]]; then
            chmod +x "$file"
        fi

        echo "✅ $(basename "$file")"
    fi
}

# Normaliser le script principal
normalize_file "silk"
normalize_file "install.sh"

# Normaliser tous les scripts .sh
find . -name "*.sh" -type f | while read -r script; do
    normalize_file "$script"
done

# Normaliser scripts dans lib/ si existe
if [[ -d "lib" ]]; then
    find lib -name "*.sh" -type f | while read -r script; do
        normalize_file "$script"
    done
fi

echo "✅ Normalisation terminée"

# Vérification Git
if git status --porcelain 2>/dev/null | grep -q .; then
    echo "📝 Changements détectés par Git (fins de ligne normalisées)"
    echo "💡 Commitez ces changements pour finaliser la normalisation"
else
    echo "✅ Aucun changement Git nécessaire"
fi
