# Contribution à silk CLI

## 🎯 Philosophie

silk CLI est né d'un besoin réel d'auteur : workflow moderne, intégration LLM, publication professionnelle.

## 🛠️ Développement

### Setup local
```bash
git clone https://github.com/oinant/silk-cli
cd silk-cli
./silk --help  # Test fonctionnement
```

### Standards code
- **Bash** : Compatible POSIX, shellcheck clean
- **Fonctions** : Une responsabilité par fonction
- **Documentation** : Inline + aide détaillée
- **Tests** : Scenarios utilisateur réels

### Genres prioritaires
1. **Polar** (expertise auteur) 
2. **Fantasy** (gros marché)
3. **Romance** ($1.4B marché US)

### Marchés prioritaires  
1. **France** (développement initial)
2. **US/UK** (gros marchés anglophones)
3. **Allemagne** (fort numérique)

## 📋 Types contribution

### Templates genre
- Structure narrative appropriée
- Conventions marché local
- Prompts LLM spécialisés

### Support langue
- i18n interface utilisateur
- Templates culturellement adaptés
- Configuration marché éditorial

### Fonctionnalités
- Workflow auteur réel
- Intégration LLM moderne
- Publication multi-format

## 🧪 Tests

```bash
# Test commandes principales
./tests/test_init.sh
./tests/test_context.sh  
./tests/test_publish.sh

# Test compatibilité
./tests/test_windows_gitbash.sh
./tests/test_macos.sh
./tests/test_linux.sh
```

## 🚀 Release

1. Update version dans script
2. Update CHANGELOG.md
3. Tag git : `git tag v1.x.x`
4. Génération artifacts release GitHub

Merci de contribuer au workflow auteur moderne ! 🕷️
