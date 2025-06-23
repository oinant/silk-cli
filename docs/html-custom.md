# HTML Custom SILK - Documentation

## 🎯 Objectif

Le générateur HTML custom de SILK permet de créer des pages web avec une structure sémantique spécifique, remplaçant Pandoc par un parser bash natif qui respecte les conventions SILK.

## 🏗️ Structure générée

```html
<section class="chapter" id="ch-7">
  <h2>Ch.7 : La Sorbonne sous Surveillance</h2>

  <article class="narrative-block">
    <p>Premier bloc narratif...</p>
    <p>Contenu jusqu'au premier ---</p>
  </article>

  <article class="narrative-block">
    <p>Deuxième bloc narratif...</p>
    <p>Contenu jusqu'au deuxième ---</p>
  </article>
</section>
```

## 📁 Fichiers nécessaires

### 1. Module principal : `lib/commands/custom_html.sh`
Contient toutes les fonctions de génération HTML custom.

### 2. Format HTML custom : `formats/html-custom.yaml`
Configuration avec `custom_structure: true` et CSS intégré.

### 3. Patch d'intégration : modifications dans `lib/commands/publish.sh`
Détection automatique et appel du générateur custom.

## 🚀 Installation

1. **Copier les fichiers :**
```bash
# Module principal
cp custom_html.sh lib/commands/

# Format custom
cp html-custom.yaml formats/

# Appliquer le patch d'intégration dans lib/commands/publish.sh
```

2. **Modifications à appliquer manuellement :**

Dans `generate_silk_output()`, après `local output_type=$(detect_output_format "$format")` :

```bash
# Détecter si génération HTML custom demandée
if [[ "$output_type" == "html" ]] && [[ "$(detect_custom_structure "$format")" == "true" ]]; then
    log_debug "🕸️ Structure HTML custom détectée pour format: $format"

    # Sourcer les fonctions custom HTML si pas déjà fait
    if ! declare -f generate_custom_html > /dev/null; then
        if [[ -f "lib/commands/custom_html.sh" ]]; then
            source "lib/commands/custom_html.sh"
        else
            log_error "Fichier lib/commands/custom_html.sh introuvable"
            return 1
        fi
    fi

    # Appeler générateur custom
    generate_custom_html "$format" "$max_chapters" "$french_quotes" "$auto_dashes" "$output_name" "$include_toc" "$include_stats" "$embeddable"
    return $?
fi
```

Ajouter la fonction `detect_custom_structure()` :

```bash
detect_custom_structure() {
    local format="$1"
    local format_config="formats/$format.yaml"

    if [[ -f "$format_config" ]]; then
        if grep -q "^custom_structure:[[:space:]]*true" "$format_config"; then
            echo "true"
            return 0
        fi
    fi
    echo "false"
}
```

## 🎨 Conventions SILK supportées

| Convention | HTML généré | Description |
|------------|-------------|-------------|
| `---` | `</article><article class="narrative-block">` | Séparateur de blocs narratifs |
| `~` | `<div class="blank-space"></div>` | Blanc typographique (⁂) |
| `*texte*` | `<p class="time-location"><em>texte</em></p>` | Indications temporelles/lieu |
| `# Titre` | `<h2>Titre</h2>` | Titre de chapitre |
| Dialogue `—` | `<p class="dialogue">texte</p>` | Dialogue avec style spécial |

## 📱 Fonctionnalités

### ✅ Structure sémantique
- `<section class="chapter">` pour chaque chapitre
- `<article class="narrative-block">` pour chaque bloc entre `---`
- IDs uniques : `id="ch-7"` pour navigation

### ✅ CSS intégré responsive
- Design typographique français
- Mode sombre automatique (`prefers-color-scheme: dark`)
- Responsive mobile/tablette
- Styles optimisés impression

### ✅ Options flexibles
- `--embeddable` : fragment HTML sans `<html>/<body>`
- `--no-toc` : désactiver table des matières
- `--french-quotes` : guillemets français « »
- `--auto-dashes` : tirets cadratins automatiques
- Sélection chapitres : `1-5`, `1,3,7`, `10`

### ✅ Performance
- Parser bash pur (pas de dépendance Pandoc)
- Traitement ligne par ligne optimisé
- Gestion mémoire efficace pour gros manuscrits

## 🎮 Utilisation

### Commandes de base

```bash
# HTML complet avec structure sémantique
silk publish -f html-custom

# Fragment embeddable pour intégration
silk publish -f html-custom --embeddable

# Chapitres spécifiques
silk publish -f html-custom -ch 1-5
silk publish -f html-custom -ch 1,3,7,12

# Avec options typographiques
silk publish -f html-custom --french-quotes --auto-dashes

# Sans table des matières
silk publish -f html-custom --no-toc

# Nom personnalisé
silk publish -f html-custom -o "mon-manuscrit"
```

### Exemples d'intégration

#### Mode embeddable dans site web
```html
<!DOCTYPE html>
<html>
<head>
    <title>Mon site</title>
    <style>
        /* Vos styles existants */
        .content-wrapper { max-width: 1200px; }
    </style>
</head>
<body>
    <header>Navigation du site</header>

    <main class="content-wrapper">
        <!-- Fragment SILK généré avec --embeddable -->
        <div class="silk-manuscript">
            <section class="chapter" id="ch-1">
                <!-- Contenu généré automatiquement -->
            </section>
        </div>
    </main>

    <footer>Pied de page</footer>
</body>
</html>
```

#### Mode standalone
Le HTML généré est complet et autonome, prêt pour :
- Publication web directe
- Intégration CMS (WordPress, etc.)
- Génération d'ebooks
- Archives numériques

## 🔧 Personnalisation

### CSS personnalisé

Modifier `formats/html-custom.yaml` section `css:` :

```yaml
css: |
  /* Vos styles personnalisés */
  .chapter h2 {
    color: #your-brand-color;
    font-family: "Your-Font", serif;
  }

  .narrative-block {
    background: rgba(0,0,0,0.02);
    padding: 1rem;
    margin: 2rem 0;
    border-radius: 8px;
  }
```

### Variables de substitution

Le template YAML supporte les variables :

```yaml
title: "{{TITLE}}"        # Nom du projet
author: "{{AUTHOR}}"      # Variable SILK_AUTHOR_NAME
date: "{{DATE}}"          # Date de génération
```

### Format dérivé

Créer un nouveau format basé sur html-custom :

```yaml
# formats/my-custom.yaml
output_type: html
custom_structure: true

# Hériter du CSS de base et ajouter le vôtre
css: |
  /* CSS de base html-custom ici */

  /* Vos ajouts */
  .my-special-class {
    /* styles spécifiques */
  }
```

## 🧪 Tests et validation

### Test automatisé
```bash
# Lancer les tests
./tests/test-custom-html.sh

# Vérifications :
# ✅ Détection custom_structure
# ✅ Extraction CSS YAML
# ✅ Parser Markdown
# ✅ Génération complète
# ✅ Mode embeddable
```

### Validation manuelle

1. **Structure HTML valide :**
```bash
# Générer fichier test
silk publish -f html-custom -ch 1

# Valider avec W3C ou outil local
validator outputs/publish/votre-fichier.html
```

2. **Vérifications visuelles :**
- Ouvrir dans navigateur
- Tester responsive (F12 → mode mobile)
- Vérifier mode sombre
- Test impression (Ctrl+P)

3. **Performance :**
```bash
# Mesurer temps génération
time silk publish -f html-custom

# Vérifier taille fichier
du -h outputs/publish/*.html
```

## 🐛 Dépannage

### Erreurs courantes

#### `custom_structure: true` non détecté
```bash
# Vérifier format YAML
cat formats/html-custom.yaml | grep custom_structure

# Doit afficher : custom_structure: true
```

#### Module custom_html.sh non trouvé
```bash
# Vérifier présence
ls -la lib/commands/custom_html.sh

# Vérifier permissions
chmod +x lib/commands/custom_html.sh
```

#### CSS non appliqué
```bash
# Vérifier extraction CSS
grep -A 10 "css:" formats/html-custom.yaml

# Test extraction
source lib/commands/custom_html.sh
extract_yaml_css formats/html-custom.yaml
```

### Debug mode

Activer logs détaillés :
```bash
export SILK_DEBUG=true
silk publish -f html-custom
```

### Logs utiles
- `📄 Création structure HTML` : début génération
- `📖 Ch.X: Titre` : traitement chapitre
- `🎯 N blocs narratifs` : parsing réussi
- `✅ HTML généré` : succès complet

## 🔮 Évolutions futures

### Fonctionnalités prévues
- [ ] Table des matières dynamique avec JavaScript
- [ ] Export vers formats additionnels (AMP, EPUB)
- [ ] Intégration moteur de recherche
- [ ] Mode lecteur avec progression
- [ ] Annotations et commentaires
- [ ] API REST pour CMS

### Optimisations
- [ ] Cache des parsers pour gros manuscrits
- [ ] Compression CSS/HTML
- [ ] Lazy loading pour chapitres longs
- [ ] Service Worker pour mode hors-ligne

## 📚 Ressources

### Documentation complémentaire
- [Structure sémantique HTML5](https://developer.mozilla.org/fr/docs/Web/HTML/Element/section)
- [CSS Grid et Flexbox](https://css-tricks.com/snippets/css/complete-guide-grid/)
- [Accessibility Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)

### Exemples avancés
- Templates CMS WordPress/Drupal
- Intégration GitBook/VitePress
- Pipeline CI/CD avec génération automatique

---

**🕸️ SILK weaves beautiful HTML from your manuscript.**
