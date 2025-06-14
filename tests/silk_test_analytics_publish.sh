#!/bin/bash
# Test analytics et publication SILK

set -euo pipefail

echo "🕷️ Test Analytics et Publication SILK"
echo "====================================="

# Aller dans le projet de test
if [[ ! -d "test-polar-project" ]]; then
    echo "❌ Projet test manquant. Exécutez d'abord les tests précédents"
    exit 1
fi

cd test-polar-project

# Test wordcount
echo "📊 Test 1: Statistiques wordcount"
if ./silk wordcount; then
    echo "✅ Wordcount par défaut"
else
    echo "❌ Échec wordcount"
fi

echo
echo "📊 Test 2: Wordcount avec objectif"
if ./silk wordcount 50000; then
    echo "✅ Wordcount avec objectif personnalisé"
else
    echo "❌ Échec wordcount objectif"
fi

echo
echo "📊 Test 3: Wordcount résumé"
if ./silk wordcount --summary; then
    echo "✅ Wordcount mode résumé"
else
    echo "❌ Échec wordcount résumé"
fi

# Test configuration
echo
echo "⚙️ Test 4: Configuration SILK"
if ./silk config --set SILK_DEFAULT_TARGET_WORDS=75000; then
    echo "✅ Configuration modifiée"
else
    echo "❌ Échec modification config"
fi

if ./silk config --get SILK_DEFAULT_TARGET_WORDS | grep -q "75000"; then
    echo "✅ Configuration lue correctement"
else
    echo "❌ Configuration non persistée"
fi

# Vérifier que Pandoc/XeLaTeX sont disponibles pour publication
echo
echo "🔧 Vérification dépendances publication:"
if command -v pandoc &> /dev/null; then
    echo "✅ Pandoc disponible"
    PANDOC_AVAILABLE=true
else
    echo "⚠️  Pandoc non disponible (test publication limité)"
    PANDOC_AVAILABLE=false
fi

if command -v xelatex &> /dev/null; then
    echo "✅ XeLaTeX disponible"
    XELATEX_AVAILABLE=true
else
    echo "⚠️  XeLaTeX non disponible (test publication limité)"
    XELATEX_AVAILABLE=false
fi

# Test publication (aide seulement si pas de dépendances)
echo
echo "📖 Test 5: Publication"
if [[ "$PANDOC_AVAILABLE" == true && "$XELATEX_AVAILABLE" == true ]]; then
    echo "🎯 Test publication complète..."
    if ./silk publish -f digital --chapters 2 2>/dev/null; then
        echo "✅ Publication PDF réussie"
        
        # Vérifier fichier généré
        if ls outputs/publish/*.pdf &> /dev/null; then
            echo "✅ PDF généré dans outputs/publish/"
            pdf_file=$(ls outputs/publish/*.pdf | head -1)
            pdf_size=$(ls -lh "$pdf_file" | awk '{print $5}')
            echo "   📁 Taille: $pdf_size"
        else
            echo "❌ PDF non trouvé"
        fi
    else
        echo "❌ Échec publication PDF"
    fi
else
    echo "ℹ️  Test aide publication (dépendances manquantes):"
    if ./silk publish --help > /dev/null; then
        echo "✅ Aide publication accessible"
    else
        echo "❌ Aide publication échoue"
    fi
fi

# Test formats disponibles
echo
echo "📄 Test 6: Formats publication"
formats=("digital" "iphone" "kindle" "book")
for format in "${formats[@]}"; do
    if [[ -f "formats/$format.yaml" ]]; then
        echo "✅ Format $format disponible"
    else
        echo "❌ Format $format manquant"
    fi
done

# Test structure outputs
echo
echo "📁 Vérification structure outputs:"
expected_output_dirs=(
    "outputs/context"
    "outputs/publish" 
    "outputs/temp"
)

for dir in "${expected_output_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        echo "✅ $dir"
    else
        echo "❌ $dir manquant"
    fi
done

# Test détection projet SILK
echo
echo "🕸️ Test 7: Détection projet SILK"
cd ..
mkdir -p test-non-silk
cd test-non-silk

if ./silk wordcount 2>/dev/null; then
    echo "❌ Commande devrait échouer hors projet SILK"
else
    echo "✅ Détection correcte hors projet SILK"
fi

cd ..
rm -rf test-non-silk

echo "✅ Test analytics et publication terminé"