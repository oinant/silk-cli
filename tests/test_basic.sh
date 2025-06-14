#!/bin/bash
# Tests de base silk CLI

set -euo pipefail

echo "🧪 Tests silk CLI..."

# Test version
echo "Test version..."
if ./silk version; then
    echo "✅ Version OK"
else
    echo "❌ Version failed"
    exit 1
fi

# Test aide
echo "Test aide..."
if ./silk --help > /dev/null; then
    echo "✅ Aide OK"
else
    echo "❌ Aide failed"
    exit 1
fi

# Test init dry-run
echo "Test init..."
if ./silk init --help > /dev/null; then
    echo "✅ Init help OK"
else
    echo "❌ Init help failed"
    exit 1
fi

echo "✅ Tous les tests de base passent"
