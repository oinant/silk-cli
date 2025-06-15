#!/bin/bash
# migrate-to-modular.sh - Migration vers architecture modulaire SILK

set -euo pipefail

echo "🕷️ Migration SILK vers Architecture Modulaire"
echo "============================================="

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[OK] $1${NC}"; }
log_warning() { echo -e "${YELLOW}[WARN] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }

# === ÉTAPE 1: Sauvegarde du script actuel ===
log_info "Étape 1: Sauvegarde du script silk actuel"

if [[ -f "silk" ]]; then
    cp silk "silk.backup.$(date +%Y%m%d-%H%M%S)"
    log_success "Sauvegarde créée"
else
    log_warning "Pas de script silk existant"
fi

# === ÉTAPE 2: Création structure modulaire ===
log_info "Étape 2: Création structure modulaire"

# Créer répertoires
mkdir -p lib/{core,commands,templates}
log_success "Répertoires lib/ créés"

# === ÉTAPE 3: Instructions utilisateur ===
echo
log_info "Étape 3: Instructions pour compléter la migration"
echo
echo "📋 ACTIONS REQUISES:"
echo
echo "1. 📝 Remplacer le script principal:"
echo "   - Copiez le nouveau script 'silk' modulaire"
echo "   - Assurez-vous qu'il est exécutable: chmod +x silk"
echo
echo "2. 📚 Créer les modules core:"
echo "   - lib/core/utils.sh    (fonctions utilitaires)"
echo "   - lib/core/config.sh   (gestion configuration)"
echo "   - lib/core/vault.sh    (gestion projets)"
echo
echo "3. 🛠️ Créer les modules commandes:"
echo "   - lib/commands/init.sh      (création projets)"
echo "   - lib/commands/context.sh   (génération contexte LLM)"
echo "   - lib/commands/wordcount.sh (statistiques)"
echo "   - lib/commands/publish.sh   (publication PDF)"
echo
echo "4. 🎨 Créer les templates (optionnel):"
echo "   - lib/templates/polar.sh    (templates polar)"
echo "   - lib/templates/fantasy.sh  (templates fantasy)"
echo "   - lib/templates/base.sh     (templates génériques)"
echo

# === ÉTAPE 4: Créer fichiers de structure ===
log_info "Étape 4: Création fichiers de structure"

# Créer fichier index des modules
cat > lib/README.md << 'EOF'
# Modules SILK CLI

## Structure

- `core/` - Modules fondamentaux (chargés automatiquement)
  - `utils.sh` - Fonctions utilitaires communes
  - `config.sh` - Gestion configuration
  - `vault.sh` - Gestion projets SILK

- `commands/` - Modules de commandes
  - `init.sh` - Création projets (`silk init`)
  - `context.sh` - Génération contexte LLM (`silk context`)
  - `wordcount.sh` - Statistiques (`silk wordcount`)
  - `publish.sh` - Publication PDF (`silk publish`)

- `templates/` - Modules templates par genre
  - `polar.sh` - Templates polar psychologique
  - `fantasy.sh` - Templates fantasy
  - `base.sh` - Templates génériques

## Convention de nommage

Chaque module de commande doit exposer :
- `cmd_<nom>()` - Fonction principale
- `show_<nom>_help()` - Fonction d'aide
- `readonly SILK_COMMAND_<NOM>_LOADED=true` - Marqueur de chargement

## Dépendances

Les modules peuvent charger d'autres modules via `load_module()`.
Les modules core sont chargés automatiquement au démarrage.
EOF

# Créer placeholders pour les modules manquants
create_placeholder() {
    local file="$1"
    local desc="$2"
    local func="$3"

    cat > "$file" << EOF
#!/bin/bash
# $file - $desc

# TODO: Implémenter ce module

$func() {
    echo "🚧 Module en développement: $file"
    echo "💡 Fonction: $desc"
    echo "📋 À implémenter: $func"
    return 1
}

# Marquer module comme chargé (placeholder)
readonly SILK_$(basename "$file" .sh | tr '[:lower:]' '[:upper:]')_LOADED=true
EOF
}

# Créer placeholders si modules n'existent pas
if [[ ! -f "lib/core/config.sh" ]]; then
    create_placeholder "lib/core/config.sh" "Gestion configuration SILK" "silk_config_load"
    log_success "Placeholder config.sh créé"
fi

if [[ ! -f "lib/core/vault.sh" ]]; then
    create_placeholder "lib/core/vault.sh" "Gestion projets SILK" "ensure_silk_context"
    log_success "Placeholder vault.sh créé"
fi

if [[ ! -f "lib/commands/context.sh" ]]; then
    create_placeholder "lib/commands/context.sh" "Génération contexte LLM" "cmd_context"
    log_success "Placeholder context.sh créé"
fi

if [[ ! -f "lib/commands/wordcount.sh" ]]; then
    create_placeholder "lib/commands/wordcount.sh" "Statistiques progression" "cmd_wordcount"
    log_success "Placeholder wordcount.sh créé"
fi

if [[ ! -f "lib/commands/publish.sh" ]]; then
    create_placeholder "lib/commands/publish.sh" "Publication PDF" "cmd_publish"
    log_success "Placeholder publish.sh créé"
fi

# === ÉTAPE 5: Test de la migration ===
log_info "Étape 5: Test de la structure"

# Vérifier que les répertoires existent
required_dirs=("lib/core" "lib/commands" "lib/templates")
for dir in "${required_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        log_success "Répertoire créé: $dir"
    else
        log_error "Échec création: $dir"
    fi
done

# Compter les modules
core_modules=$(find lib/core -name "*.sh" 2>/dev/null | wc -l)
command_modules=$(find lib/commands -name "*.sh" 2>/dev/null | wc -l)
template_modules=$(find lib/templates -name "*.sh" 2>/dev/null | wc -l)

echo
log_info "📊 Modules détectés:"
echo "   Core: $core_modules modules"
echo "   Commands: $command_modules modules"
echo "   Templates: $template_modules modules"

# === ÉTAPE 6: Script de test modulaire ===
log_info "Étape 6: Création script de test"

cat > test-modular.sh << 'TEST_EOF'
#!/bin/bash
# Test rapide architecture modulaire

echo "🕷️ Test Architecture Modulaire SILK"
echo "==================================="

if [[ ! -f "silk" ]]; then
    echo "❌ Script silk manquant"
    exit 1
fi

chmod +x silk

echo "📝 Test commandes de base..."
if ./silk version &>/dev/null; then
    echo "✅ version OK"
else
    echo "❌ version échoue"
fi

if ./silk config --list &>/dev/null; then
    echo "✅ config OK"
else
    echo "❌ config échoue"
fi

echo "📝 Test chargement modules..."
if ./silk init --help &>/dev/null; then
    echo "✅ init module OK"
else
    echo "⚠️  init module non fonctionnel (normal si placeholder)"
fi

echo "📁 Structure modules:"
find lib -name "*.sh" -type f | sort

echo
echo "🎯 Migration terminée ! Remplacez les placeholders par les vrais modules."
TEST_EOF

chmod +x test-modular.sh
log_success "Script test-modular.sh créé"

# === ÉTAPE 7: Instructions finales ===
echo
log_success "🎉 Migration vers architecture modulaire terminée !"
echo
echo "📋 RÉSUMÉ:"
echo "✅ Structure lib/ créée"
echo "✅ Placeholders modules créés"
echo "✅ Documentation ajoutée"
echo "✅ Script de test créé"
echo
echo "🚀 PROCHAINES ÉTAPES:"
echo
echo "1. 📝 Remplacer le script principal 'silk':"
echo "   cp silk.backup.* silk.old  # sauvegarder ancien"
echo "   # Copier nouveau script silk modulaire"
echo "   chmod +x silk"
echo
echo "2. 📚 Implémenter les modules core:"
echo "   # Remplacer lib/core/utils.sh par le vrai module"
echo "   # Remplacer lib/core/config.sh par le vrai module"
echo "   # Remplacer lib/core/vault.sh par le vrai module"
echo
echo "3. 🛠️ Implémenter les modules commandes:"
echo "   # Remplacer lib/commands/init.sh par le vrai module"
echo "   # etc. pour context, wordcount, publish"
echo
echo "4. 🧪 Tester l'architecture:"
echo "   ./test-modular.sh"
echo
echo "5. 🔧 Débugger si nécessaire:"
echo "   ./silk --debug version"
echo "   ./silk --debug init --help"
echo
echo "📖 Documentation: lib/README.md"
echo "🧪 Tests: ./test-modular.sh"
echo
echo "🕸️ SILK weaves a modular future! Architecture ready for scaling."
