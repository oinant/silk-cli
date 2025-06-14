# Exemple Projet Polar

Structure générée par `silk init "Mon Polar" --genre polar-psychologique`:

```
mon-polar/
├── 01-Manuscrit/
│   ├── Ch01-Premier-Meurtre.md
│   ├── Ch02-Enquete-Commence.md
│   └── ...
├── 02-Personnages/
│   ├── Detective-Principal.md
│   ├── Principaux/
│   │   ├── Antagoniste.md
│   │   └── Temoin-Cle.md
│   └── Secondaires/
├── 04-Concepts/
│   ├── Enquete-Structure.md
│   └── Revelations-Timeline.md
├── outputs/
│   ├── context/     # Contexte LLM
│   └── publish/     # PDF générés
└── formats/         # Templates publication
```

## Workflow typique

1. **Génération** : `silk init "Mon Polar"`
2. **Écriture** : Rédiger chapitres avec structure `## manuscrit`
3. **Analyse** : `silk context "Vérifier cohérence Ch1-5"`
4. **Stats** : `silk wordcount 80000`
5. **Publication** : `silk publish -f digital`

## Templates polar

- **Structure trilogique** pré-configurée
- **Révélations progressives** planifiées  
- **Prompts LLM** spécialisés investigation
- **Public cible** femmes CSP+ 35-55 ans
