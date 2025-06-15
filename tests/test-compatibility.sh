#!/bin/bash
# Test compatibilité WSL/Windows/Linux

set -euo pipefail

echo "🔧 Test compatibilité environnements"
echo "===================================="

# Détection environnement
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    ENV="WSL ($WSL_DISTRO_NAME)"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "mingw"* ]]; then
    ENV="Git Bash Windows"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    ENV="Linux natif"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    ENV="macOS"
else
    ENV="Inconnu ($OSTYPE)"
fi

echo "📍 Environnement détecté: $ENV"
echo "📁 Répertoire: $PWD"
echo "👤 Utilisateur: $USER"
echo "🏠 HOME: $HOME"

# Test script principal
echo
echo "🧪 Test script silk..."
if [[ -f "./silk" ]]; then
    if [[ -x "./silk" ]]; then
        echo "✅ silk exécutable"
        if ./silk version 2>/dev/null; then
            echo "✅ silk fonctionne"
        else
            echo "❌ silk ne fonctionne pas"
        fi
    else
        echo "⚠️ silk pas exécutable, tentative de correction..."
        chmod +x ./silk
        if ./silk version 2>/dev/null; then
            echo "✅ silk fonctionne après chmod"
        else
            echo "❌ silk ne fonctionne toujours pas"
        fi
    fi
else
    echo "❌ silk non trouvé"
fi

# Test fins de ligne
echo
echo "🔍 Vérification fins de ligne..."
if command -v file &> /dev/null; then
    if [[ -f "./silk" ]]; then
        file_info=$(file ./silk)
        if echo "$file_info" | grep -q "CRLF"; then
            echo "⚠️ silk contient des CRLF (fins de ligne Windows)"
            echo "💡 Exécutez: ./normalize-scripts.sh"
        else
            echo "✅ silk utilise LF (fins de ligne Unix)"
        fi
    fi
else
    echo "ℹ️ Commande 'file' non disponible, vérification sautée"
fi

# Test Git
echo
echo "📝 Vérification Git..."
if command -v git &> /dev/null; then
    if git rev-parse --git-dir &> /dev/null; then
        echo "✅ Repo Git détecté"

        # Vérifier config core.autocrlf
        autocrlf=$(git config --get core.autocrlf 2>/dev/null || echo "non défini")
        echo "   core.autocrlf: $autocrlf"

        if [[ "$autocrlf" != "false" ]]; then
            echo "⚠️ Recommandation: git config core.autocrlf false"
        fi

        # Vérifier .gitattributes
        if [[ -f ".gitattributes" ]]; then
            echo "✅ .gitattributes présent"
        else
            echo "⚠️ .gitattributes manquant (recommandé pour normalisation)"
        fi
    else
        echo "ℹ️ Pas dans un repo Git"
    fi
else
    echo "❌ Git non disponible"
fi

# Test outils nécessaires
echo
echo "🛠️ Outils disponibles:"
tools=("bash" "chmod" "grep" "sed" "wc" "find")
for tool in "${tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "✅ $tool"
    else
        echo "❌ $tool (requis)"
    fi
done

# Outils optionnels
echo
echo "🔧 Outils optionnels:"
optional_tools=("dos2unix" "unix2dos" "pandoc" "xelatex")
for tool in "${optional_tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "✅ $tool"
    else
        echo "⚪ $tool (optionnel)"
    fi
done

echo
echo "✅ Test compatibilité terminé"
