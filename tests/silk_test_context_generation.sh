#!/bin/bash
# Test génération contexte LLM SILK

set -euo pipefail

echo "🕷️ Test Génération Contexte LLM"
echo "==============================="

# Aller dans le projet de test (créé par test précédent)
if [[ ! -d "test-polar-project" ]]; then
    echo "❌ Projet test manquant. Exécutez d'abord test_project_creation.sh"
    exit 1
fi

cd test-polar-project

# Créer du contenu de test
echo "📝 Création contenu de test..."

# Chapitre 1
cat > "01-Manuscrit/Ch01-Meurtre-Louvre.md" << 'EOF'
# Ch.01 : Meurtre au Louvre

## Objectifs SILK
- **Intrigue** : Découverte corps dans réserves du Louvre
- **Développement** : Introduction Claire Moreau, enquêtrice art
- **Révélations** : Œuvre d'art volée il y a 20 ans retrouvée
- **Tension** : Lien entre meurtre et trafic art international

## Personnages actifs
- [[Claire Moreau]] : Enquêtrice spécialisée art, 40 ans
- [[Victime]] : Conservateur Louvre, Marcel Dubois
- [[Témoin]] : Gardien de nuit, Pierre Martin

## Liens narratifs
← Début : Immersion directe scène crime
→ Ch.02 : Investigation premiers indices

## manuscrit

Le téléphone de Claire Moreau vibrait dans l'obscurité de sa chambre. 6h42, commissariat central.

— Moreau.

— Claire, on a un problème au Louvre. Corps dans les réserves.

Elle s'assit dans son lit. Vingt ans de police judiciaire lui avaient appris que les meurtres dans les lieux emblématiques ne relevaient jamais du hasard.

— J'arrive.

Le Louvre à l'aube gardait sa majesté silencieuse. Les premiers touristes n'arriveraient que dans trois heures, mais déjà l'activité bourdonnait dans les couloirs habituellement interdits au public.

Claire présenta sa carte à l'entrée des réserves. Le gardien de nuit, Pierre Martin, l'attendait. Son visage portait encore les traces du choc.

— C'est par là, dit-il d'une voix tremblante. Dans la section peintures du XIXe.

Le corps de Marcel Dubois gisait entre deux caisses d'emballage. Conservateur en chef de la section peintures, la cinquantaine distinguée, il portait encore sa veste de costume trois-pièces. Aucune trace de lutte visible.

Mais ce qui intrigua Claire, c'était le tableau posé contre la caisse voisine. Une toile qu'elle ne reconnaissait pas, pourtant son instinct lui soufflait qu'elle l'avait déjà vue quelque part.

— Monsieur Martin, ce tableau était-il là hier soir ?

— Non, madame. J'en suis certain. Cette caisse contenait des toiles en restauration.

Claire photographia la scène sous tous les angles. Quelque chose clochait dans cette mise en scène trop parfaite.
EOF

# Chapitre 2
cat > "01-Manuscrit/Ch02-Premiere-Piste.md" << 'EOF'
# Ch.02 : Première Piste

## Objectifs SILK
- **Intrigue** : Identification tableau = œuvre volée 1998
- **Développement** : Présentation équipe + méthodes Claire
- **Révélations** : Dubois enquêtait sur vol historique
- **Tension** : Menaces reçues par Dubois semaine précédente

## manuscrit

Le bureau de Claire au 36 quai des Orfèvres n'avait jamais été aussi encombré. Photos de la scène de crime, dossiers d'archives, reproductions d'œuvres d'art s'étalaient sur chaque surface disponible.

Son équipier, Lieutenant Thomas Ricard, entra avec deux cafés et une expression sombre.

— J'ai du nouveau sur le tableau. Base de données Interpol positive.

Claire leva les yeux de l'ordinateur où elle analysait les relevés de la police scientifique.

— Raconte.

— "Femme au chapeau rouge", Monet, 1887. Volé au musée d'art moderne de Zurich en octobre 1998. Valeur estimée : 12 millions d'euros.

— Et il réapparaît dans les réserves du Louvre vingt-trois ans plus tard, le soir où le conservateur en chef est assassiné.

Thomas s'assit face à elle, repoussant une pile de photos.

— Trop gros pour être une coïncidence.

Claire acquiesça. Dans sa spécialité, le trafic d'art, les coïncidences n'existaient pas. Chaque détail avait sa logique, même tordue.

— Qu'est-ce qu'on sait sur Dubois ?

— Carrière exemplaire. Quarante ans au Louvre, spécialiste reconnu de l'art du XIXe. Marié, deux enfants adultes, pas de dettes connues.

— Pas de dettes officielles, corrigea Claire. Il faut creuser sa vie privée. Et vérifier ses communications récentes.

Le téléphone de Dubois, retrouvé dans sa poche, révéla effectivement quelque chose d'intriguant : trois appels manqués d'un numéro masqué la semaine précédente, et un SMS reçu la veille de sa mort : "Arrêtez vos recherches ou assumez les conséquences."
EOF

# Personnage principal
cat > "02-Personnages/Claire-Moreau.md" << 'EOF'
# Claire Moreau

## Identité
- **Âge** : 42 ans
- **Fonction** : Commissaire adjointe, spécialiste trafic d'art
- **Statut social** : Divorcée, appartement 16ème arrondissement

## Psychologie SILK
### Motivations profondes
- **Justice artistique** : Rendre les œuvres à leur place légitime
- **Rédemption personnelle** : Prouver sa valeur après divorce difficile
- **Passion art** : Études art interrompues pour police

### Failles et contradictions
- **Perfectionnisme** : N'accepte pas l'échec, s'épuise
- **Méfiance relationnelle** : Divorce l'a rendue prudente
- **Obsession travail** : Compense vide affectif par enquêtes

## Relations
- [[Thomas Ricard]] : Équipier loyal, seule personne de confiance
- [[Ex-mari]] : Divorce conflictuel, garde partagée fille 15 ans
- [[Directrice musée]] : Rivale professionnelle, ambition commune

## Arc narratif
- **Introduction** : Enquêtrice compétente mais isolée
- **Développement** : Découverte réseau trafic international
- **Climax** : Choix entre sécurité personnelle et justice
- **Résolution** : Acceptation vulnérabilité, ouverture aux autres
EOF

# Concept enquête
cat > "04-Concepts/Réseau-Trafic-Art.md" << 'EOF'
# Réseau Trafic Art International

## Structure criminelle
- **Commanditaires** : Collectionneurs privés fortunés
- **Intermédiaires** : Conservateurs corrompus, experts complices
- **Exécutants** : Voleurs spécialisés, faussaires de génie
- **Blanchiment** : Ventes aux enchères, galeries complices

## Mécaniques SILK
### Mode opératoire
1. **Repérage** : Identification œuvres sous-évaluées
2. **Vol orchestré** : Pendant transferts ou restaurations
3. **Disparition temporaire** : Stockage sécurisé 15-20 ans
4. **Réapparition légale** : Fausse provenance, vente officielle

### Vulnérabilités réseau
- **Ego collectionneurs** : Besoin de montrer leurs "trophées"
- **Rivalités internes** : Conflits d'intérêts et de territoire
- **Traces numériques** : Communications, transferts financiers
- **Témoins** : Petites mains qui en savent trop

## Ancrage réaliste
Basé sur affaires réelles : vol Gardner Museum Boston, réseau Giacomo Medici, affaire Wildenstein.
EOF

echo "✅ Contenu de test créé"

# Test génération contexte normal
echo
echo "🧠 Test 1: Contexte normal"
if ../silk context "Analyse cohérence Ch1-2" --chapters 1-2; then
    echo "✅ Génération contexte normale"
else
    echo "❌ Échec contexte normal"
fi

# Vérifier fichiers générés
echo
echo "📄 Vérification fichiers générés:"
if [[ -f "outputs/context/silk-context.md" ]]; then
    echo "✅ silk-context.md généré"
    word_count=$(wc -w < "outputs/context/silk-context.md")
    echo "   📊 $word_count mots"
else
    echo "❌ silk-context.md manquant"
fi


# Test mode complet
echo
echo "🧠 Test 2: Contexte complet"
if ../silk context "Analyse complète" --mode full --wordcount; then
    echo "✅ Génération contexte complète"
else
    echo "❌ Échec contexte complet"
fi

# Test range complexe
echo
echo "🧠 Test 3: Range complexe"
if ../silk context "Test range" --chapters 1,2; then
    echo "✅ Range complexe + fichier combiné"
else
    echo "❌ Échec range complexe"
fi

# Vérifier contenu contexte
echo
echo "🔍 Vérification contenu contexte:"
if grep -q "Claire Moreau" "outputs/context/silk-context.md"; then
    echo "✅ Contenu chapitre extrait"
else
    echo "❌ Contenu chapitre manquant"
fi

if grep -q "SILK" "outputs/context/silk-context.md"; then
    echo "✅ Branding SILK dans contexte"
else
    echo "❌ Branding SILK manquant"
fi

cd ..
echo "✅ Test contexte LLM terminé"
