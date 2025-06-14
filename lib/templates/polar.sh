#!/bin/bash
# lib/templates/polar.sh - Templates polar psychologique SILK

# === CRÉATION CONTENU POLAR ===
create_polar_content() {
    local project_name="$1"
    local author_name="$2"
    local author_pseudo="$3"
    
    # Instructions LLM spécialisées polar
    create_polar_llm_instructions "$project_name" "$author_name" "$author_pseudo"
    
    # Concepts spécifiques polar
    create_polar_concepts
    
    # Personnages types polar
    create_polar_characters
    
    # Structure narrative polar
    create_polar_structure
    
    # Exemple chapitre polar
    create_polar_sample_chapter
    
    log_success "Templates polar psychologique créés"
}

# === INSTRUCTIONS LLM POLAR ===
create_polar_llm_instructions() {
    local project_name="$1"
    local author_name="$2"
    local author_pseudo="$3"
    
    cat > "00-instructions-llm/instructions.md" << EOF
# Instructions LLM - $project_name
*Projet SILK Polar - Smart Integrated Literary Kit*

## 🎯 CONTEXTE PROJET
**Genre** : Polar sophistiqué/psychologique  
**Public cible** : Lectrices CSP/CSP+ 35-55 ans (expertise L'Araignée)
**Auteur** : $author_name${author_pseudo:+ (pseudo: $author_pseudo)}
**Architecture** : SILK - Structure intelligence intégrée

## 🕷️ PHILOSOPHIE SILK POLAR
SILK tisse ensemble tous les éléments narratifs comme une araignée tisse sa toile :
- **Smart** : Templates adaptés genre polar et marché français
- **Integrated** : Workflow unifié conception→publication
- **Literary** : Focus sur sophistication psychologique
- **Kit** : Boîte à outils complète pour polar moderne

## 🧠 MÉCANIQUES POLAR SILK
### Structure enquête intelligente
- **Mystère central** : Révélations progressives calculées
- **Enquête méthodique** : Logique déductive crédible
- **Psychologie approfondie** : Motivations complexes et nuancées
- **Fausses pistes** : Misdirection élégante sans frustration lecteur

### Style et ton (public femmes CSP+ 35-55)
- **Sophistication accessible** : Intelligent sans prétention
- **Développement émotionnel** : Profondeur psychologique
- **Dialogue authentique** : Voix différenciées par personnage
- **Rythme maîtrisé** : Alternance tension/respiration

### Conventions polar français
- **Ancrage géographique** : Paris/régions françaises précis
- **Codes sociaux** : CSP+ intégrés naturellement
- **Références culturelles** : Françaises contemporaines
- **Éviter clichés** : Pas de décalques polars américains

## 📋 INSTRUCTIONS SPÉCIFIQUES SILK
### Analyse Personnages
- Psychologie crédible et évolutive
- Motivations claires avec contradictions humaines
- Relations authentiques et dynamiques
- Arc de transformation satisfaisant

### Structure Narrative  
- Équilibre investigation/développement personnel
- Rythme soutenu avec respirations émotionnelles
- Révélations préparées et logiquement satisfaisantes
- Résolution surprenante mais inévitable rétrospectivement

### Gestion Suspense
- Information distillée avec parcimonie
- Indices authentiques mais pas évidents
- Red herrings crédibles et fair-play
- Montée en tension progressive et maîtrisée

## 🎭 SPÉCIFICITÉS MARCHÉ FRANÇAIS
### Public cible (femmes CSP+ 35-55)
- **Sophistication** : Complexité psychologique appréciée
- **Réalisme social** : Crédibilité environnement professionnel
- **Développement relationnel** : Importance des liens humains
- **Justice nuancée** : Pas de manichéisme simpliste

### Codes culturels
- **Géographie parisienne** : Arrondissements, lieux précis
- **Institutions françaises** : Police, justice, système réaliste
- **Références contemporaines** : Actualité, culture, société
- **Langue française** : Registres appropriés par personnage
EOF
}

# === CONCEPTS POLAR ===
create_polar_concepts() {
    # Structure d'enquête
    cat > "04-Concepts/Enquête-Structure.md" << 'EOF'
# Structure d'Enquête SILK

## Méthodologie narrative
- **Scène de crime** : Établissement mystère avec éléments intriguants
- **Collecte indices** : Progression logique avec surprises
- **Interrogatoires** : Révélation personnalités et relations
- **Fausses pistes** : Maintien suspense sans manipulation lecteur
- **Révélation finale** : Résolution logique et émotionnellement satisfaisante

## Rythme SILK (30 chapitres standard)
- **Setup** : Accroche et établissement univers (Ch1-3)
- **Investigation** : Développement enquête et personnages (Ch4-20)
- **Complications** : Escalade tension et révélations (Ch21-26)
- **Climax** : Confrontation et révélation (Ch27-28)
- **Résolution** : Dénouement et ouverture (Ch29-30)

## Spécificités public cible
- **Lectrices CSP+ 35-55** : Sophistication psychologique
- **Attentes genre** : Justice, mais nuancée
- **Engagement émotionnel** : Identification protagonistes
- **Réalisme social** : Crédibilité environnement professionnel/social

## Types révélations
- **Indices physiques** : Preuves tangibles et logiques
- **Révélations psychologiques** : Motivations cachées
- **Connections inattendues** : Liens entre personnages
- **Retournements temporels** : Chronologie révisée
EOF

    # Psychologie criminelle
    cat > "04-Concepts/Psychologie-Criminelle.md" << 'EOF'
# Psychologie Criminelle SILK

## Profils psychologiques crédibles
### Meurtrier Type A - Passionnel
- **Motivation** : Emotion dévastatrice (jalousie, rage, désespoir)
- **Méthode** : Impulsive, peu organisée
- **Comportement post-crime** : Culpabilité, déni, tentatives dissimulation maladroites
- **Révélateurs** : Inconsistances émotionnelles, stress physiologique

### Meurtrier Type B - Calculateur
- **Motivation** : Gain (argent, pouvoir, protection secret)
- **Méthode** : Planifiée, organisée, mise en scène
- **Comportement post-crime** : Sang-froid apparent, coopération calculée
- **Révélateurs** : Perfection suspecte, détails trop cohérents

### Meurtrier Type C - Psychopathe
- **Motivation** : Plaisir, contrôle, jeu intellectuel
- **Méthode** : Sophistiquée, signatures personnelles
- **Comportement post-crime** : Détachement, possible provocation
- **Révélateurs** : Absence empathie, manipulation subtile

## Victimologie SILK
- **Victime hasard** : Mauvais lieu/moment, crime opportuniste
- **Victime ciblée**
EOF