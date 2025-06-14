#!/bin/bash
# Installation automatique silk CLI

set -euo pipefail

silk_VERSION="1.0.0"
silk_REPO="https://github.com/oinant/silk-cli"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

echo "🕷️ Installation silk CLI v$silk_VERSION"

# Détection OS  
case "$OSTYPE" in
    msys*|cygwin*|mingw*)
        INSTALL_DIR="${INSTALL_DIR:-$HOME/bin}"
        ;;
esac

# Download
echo "📥 Téléchargement..."
curl -sSL "$silk_REPO/raw/main/silk" -o silk
chmod +x silk

# Installation
echo "📦 Installation dans $INSTALL_DIR..."
if [[ -w "$(dirname "$INSTALL_DIR")" ]]; then
    mv silk "$INSTALL_DIR/"
else
    sudo mv silk "$INSTALL_DIR/"
fi

# Test
if command -v silk &> /dev/null; then
    echo "✅ silk CLI installé avec succès!"
    echo "📖 Usage: silk --help"
else
    echo "⚠️  Installation OK, mais $INSTALL_DIR pas dans PATH"
    echo "   Ajoutez: export PATH=\"$INSTALL_DIR:\$PATH\""
fi
