# SILK Modules Documentation

## Architecture Modulaire

SILK utilise une architecture modulaire pour la maintenabilité et l'extensibilité :

### Core Modules (`lib/core/`)
Modules fondamentaux chargés automatiquement au démarrage :

- **`utils.sh`** - Fonctions utilitaires communes
  - Logging avec couleurs
  - Détection OS et compatibilité
  - Validation et formatage
  - Gestion fichiers et projets SILK

- **`config.sh`** - Gestion configuration
  - Chargement/sauvegarde configuration utilisateur
  - Validation valeurs configuration
  - Gestion profils utilisateur

- **`vault.sh`** - Gestion projets SILK
  - Détection projets SILK
  - Navigation automatique vers racine projet
  - Validation structure projet

### Command Modules (`lib/commands/`)
Modules de commandes chargés à la demande :

- **`init.sh`** - `silk init` - Création projets
- **`context.sh`** - `silk context` - Génération contexte LLM
- **`wordcount.sh`** - `silk wordcount` - Statistiques progression
- **`publish.sh`** - `silk publish` - Publication PDF

### Template Modules (`lib/templates/`)
Modules templates par genre :

- **`polar.sh`** - Templates polar psychologique
- **`fantasy.sh`** - Templates fantasy
- **`romance.sh`** - Templates romance

## Convention de Développement

### Modules de Commandes
```bash
#!/bin/bash
# lib/commands/example.sh - Description

# Vérification dépendances
if [[ "${SILK_CORE_UTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/utils requis" >&2
    exit 1
fi

# Fonction principale
cmd_example() {
    # Implémentation commande
}

# Fonction aide
show_example_help() {
    # Aide détaillée
}

# Export fonctions
export -f cmd_example show_example_help

# Marqueur chargement
readonly SILK_COMMAND_EXAMPLE_LOADED=true
```

### Chargement Modules
```bash
# Dans script principal
load_module "commands/example.sh"

# Exécution commande
cmd_example "$@"
```

## API Modules

### Fonctions Utilitaires Disponibles

```bash
# Logging
log_info "Message informatif"
log_success "Opération réussie"
log_warning "Avertissement"
log_error "Erreur"
log_debug "Debug (si SILK_DEBUG=true)"

# Validation
is_valid_project_name "Mon Projet"
is_valid_word_count "80000"
is_valid_genre "polar-psychologique"

# Gestion projets
is_silk_project
find_silk_root
ensure_silk_context

# Formatage
format_file_size 1048576  # "1MB"
format_duration 3665      # "01:01:05"
```

### Variables Globales

```bash
SILK_VERSION          # Version SILK
SILK_HOME            # Répertoire config utilisateur
SILK_CONFIG          # Fichier configuration
SILK_LIB_DIR         # Répertoire modules
VAULT_MARKER         # "## manuscrit"
```

## Tests

Chaque module doit être testable :

```bash
# Test syntaxe
bash -n lib/commands/example.sh

# Test fonctionnel
source lib/core/utils.sh
source lib/commands/example.sh
cmd_example --help
```

## Contribution

1. Créer module dans répertoire approprié
2. Suivre conventions nommage et structure
3. Ajouter tests
4. Documenter API
5. Tester compatibilité cross-platform
