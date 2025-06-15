# SILK DevTools 🛠️

Scripts et outils pour le développement et la maintenance de SILK CLI.

## 🔍 Debug & Diagnostic

- **`debug-chapters.sh`** - Debug détection et extraction chapitres
- **`validate-silk-architecture.sh`** - Validation complète architecture

## ✅ Validation & Tests

- **`check-syntax.sh`** - Vérification syntaxe tous les scripts
- **`../tests/`** - Suite de tests complète (voir README principal)

## 🔧 Migration & Intégration

- **`migrate-to-modular.sh`** - Migration vers architecture modulaire
- **`integrate-modular-silk.sh`** - Intégration complète modules

## 📋 Utilisation

```bash
# Debug problème extraction
./devtools/debug-chapters.sh

# Validation architecture complète
./devtools/validate-silk-architecture.sh

# Vérification syntaxe
./devtools/check-syntax.sh

# Tests complets
./tests/silk_master_test_suite.sh
```

## 🎯 Workflow Développement

1. **Développement** : Modifier modules dans `lib/`
2. **Validation** : `./devtools/check-syntax.sh`
3. **Test** : `./tests/test-modular-compatibility.sh`
4. **Debug** : `SILK_DEBUG=true ./silk command`
5. **Validation finale** : `./devtools/validate-silk-architecture.sh`

Ces outils supportent le cycle de développement SILK ! 🕷️
