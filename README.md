# 🕷️ SILK - Smart Integrated Literary Kit
*Structured Intelligence for Literary Kreation*

Modern CLI workflow for authors with LLM integration.

## 🎯 What is SILK?

SILK weaves together all aspects of modern novel writing:
- **Smart** templates adapted by genre and market
- **Integrated** workflow from concept to publication  
- **Literary** focus on sophisticated fiction
- **Kit** complete toolbox for authors

The name reflects both meanings:
- **Smart Integrated Literary Kit** - What it does
- **Structured Intelligence for Literary Kreation** - How it works

Just like a spider weaves its web, SILK helps you weave together characters, plot, and narrative into compelling fiction.

## 🚀 Quick Start

```bash
# Install SILK
curl -sSL https://raw.githubusercontent.com/oinant/silk-cli/main/install.sh | bash

# Create new project  
silk init "My Psychological Thriller"

# Generate LLM context
silk context "Character development Emma"

# Track progress
silk wordcount 80000

# Publish professional PDF
silk publish -f digital# 🕷️ silk - Nerd Book Author

CLI pour l'écriture de romans avec intégration LLM moderne.

## 🚀 Installation rapide

```bash
# Installation directe
curl -o silk https://raw.githubusercontent.com/oinant/silk-cli/main/silk
chmod +x silk
sudo mv silk /usr/local/bin/

# Ou via script
curl -sSL https://raw.githubusercontent.com/oinant/silk-cli/main/install.sh | bash
```

## 💡 Usage

```bash
# Créer nouveau projet
silk init "Mon Roman Polar"

# Dans le projet  
silk context "Question pour Claude"
silk wordcount 80000
silk publish -f iphone
```

## 🎯 Fonctionnalités

- ✅ Générateur projets par genre (polar, fantasy, romance)
- ✅ Templates adaptés par marché (FR, US, UK, DE)
- ✅ Contexte LLM optimisé (Claude, GPT, etc.)
- ✅ Publication PDF multi-format
- ✅ Statistiques progression avancées
- ✅ Compatible Windows/Linux/macOS

## 📚 Workflow typique

1. **Création** : `silk init "Projet"` → Structure complète générée
2. **Rédaction** : Écrire dans `01-Manuscrit/Ch*.md`
3. **Analyse** : `silk context "Question"` → Contexte pour LLM
4. **Suivi** : `silk wordcount` → Stats progression
5. **Publication** : `silk publish` → PDF professionnel

## 🌍 Support multilingue

- **Français** : Polar parisien, marché hexagonal
- **Anglais** : Crime thriller, marchés US/UK  
- **Allemand** : Krimi, marché DACH
- **Espagnol** : Thriller, marchés ES/LATAM

## 🎭 Genres supportés

### Polar psychologique (🇫🇷 spécialité)
- Templates enquête/révélations
- Structure trilogique 
- Public cible femmes CSP+ 35-55

### Fantasy/Fantastique
- Système worldbuilding
- Templates magie/peuples
- Cohérence narrative

### Romance/Sentimental  
- Arc relationnel structuré
- Développement émotionnel
- Marché $1.44B (US)

## 🛠️ Technologies

- **Core** : Bash portable (Windows Git Bash compatible)
- **Publication** : Pandoc + XeLaTeX
- **Future** : Migration .NET Core prévue
- **LLM** : Intégration multi-provider

## 📖 Documentation

- [Guide Installation](docs/install.md)
- [Templates par Genre](docs/genres.md) 
- [Intégration LLM](docs/llm.md)
- [Publication PDF](docs/publish.md)
- [Contribution](CONTRIBUTING.md)

## 🤝 Contribution

Basé sur un workflow d'auteur réel avec 30+ chapitres, 450 pages, pipeline LLM optimisé.

1. Fork le projet
2. Créer branche feature (`git checkout -b feature/amazing`)
3. Commit (`git commit -m 'Add amazing feature'`)
4. Push (`git push origin feature/amazing`)
5. Créer Pull Request

## 📈 Roadmap

- [x] **v1.0** : CLI bash unifié
- [ ] **v1.1** : Support multilingue complet
- [ ] **v1.2** : Templates genre étendus
- [ ] **v2.0** : Version .NET Core + GUI
- [ ] **v2.1** : Intégration cloud/collaboration

## 📊 Stats projet

![GitHub stars](https://img.shields.io/github/stars/oinant/silk-cli)
![GitHub downloads](https://img.shields.io/github/downloads/oinant/silk-cli/total)
![GitHub issues](https://img.shields.io/github/issues/oinant/silk-cli)

Généré avec ❤️ par un auteur pour les auteurs.
