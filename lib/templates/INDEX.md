# Index Templates SILK

## 📚 Templates Communs (common/)
### Concepts
- `Structure-Projet.template` - Organisation projet SILK
- `Structure-Narrative.template` - Architecture récit
- `instructions-generiques.template` - Instructions LLM de base

### Exemples
- `Chapitre-Type.template` - Modèle chapitre standard
- `Premier-Chapitre-Generique.template` - Premier chapitre générique
- `Template-Personnage.template` - Fiche personnage
- `Protagoniste.template` - Personnage principal

### Base
- `README.template` - README projet
- `gitignore.template` - Exclusions Git
- `Template-Chapitre.template` - Structure chapitre

## 🕵️ Templates Polar (polar-psychologique/)
### Concepts
- `Enquête-Structure.template` - Mécaniques investigation
- `Mécaniques-Suspense.template` - Gestion tension
- `Révélations-Timeline.template` - Planning révélations
- `Psychologie-Personnages.template` - Profils psycho
- `Techniques-Investigation.template` - Méthodes enquête

### Exemples
- `Premier-Chapitre.template` - Chapitre d'ouverture polar
- `Scène-Interrogatoire.template` - Modèle interrogatoire

### Base
- `instructions.template` - Instructions LLM polar

## 🐉 Templates Fantasy (fantasy/)
### Concepts
- `Système-Magique.template` - Règles magie
- `Géographie-Peuples.template` - Cartographie cultures
- `Histoire-Mythologie.template` - Background univers
- `Conflits-Politiques.template` - Tensions pouvoir
- `Économie-Magique.template` - Système économique

### Exemples
- `Premier-Chapitre.template` - Ouverture fantasy
- `Scène-Magie.template` - Démonstration magie

### Base
- `instructions.template` - Instructions LLM fantasy

## 💕 Templates Romance (romance/)
### Concepts
- `Arc-Relationnel.template` - Développement couple
- `Développement-Émotionnel.template` - Progression sentiments
- `Dynamiques-Couple.template` - Relations interpersonnelles
- `Obstacles-Narratifs.template` - Complications romantiques
- `Tension-Sexuelle.template` - Construction attraction

### Exemples
- `Premier-Chapitre.template` - Ouverture romance
- `Première-Rencontre.template` - Scène rencontre

### Base
- `instructions.template` - Instructions LLM romance

## 📄 Formats Publication (formats/)
- `base.yaml` - Configuration de base
- `digital.yaml` - Format digital
- `iphone.yaml` - Format mobile
- `kindle.yaml` - Format e-reader
- `book.yaml` - Format impression

## 🎯 Usage
Chaque template utilise la syntaxe `{{VARIABLE}}` pour substitutions.
Utilisé par `lib/core/templates.sh` fonction `substitute_template()`.
