# Installation silk CLI

## 🚀 Installation rapide

### Linux / macOS
```bash
curl -sSL https://raw.githubusercontent.com/oinant/silk-cli/main/install.sh | bash
```

### Windows (Git Bash)
```bash
curl -o silk https://raw.githubusercontent.com/oinant/silk-cli/main/silk
chmod +x silk
mv silk ~/bin/  # Assurez-vous que ~/bin est dans PATH
```

### Manuel
```bash
git clone https://github.com/oinant/silk-cli
cd silk-cli
sudo cp silk /usr/local/bin/
```

## ⚙️ Configuration

```bash
silk config --set silk_AUTHOR_NAME="Votre Nom"
silk config --set silk_DEFAULT_GENRE="polar-psychologique"
silk config --list
```

## 🧪 Test installation

```bash
silk --version
silk init --help
```

## 🔧 Dépendances optionnelles

### Publication PDF
- **Pandoc** : https://pandoc.org/installing.html
- **XeLaTeX** : https://www.latex-project.org/get/

### Git (recommandé)
- Versioning automatique projets
- Collaboration équipe
- Backup cloud

## 🌍 Support multi-plateforme

- ✅ Linux (Ubuntu, Debian, Arch, etc.)
- ✅ macOS (Intel + Apple Silicon)  
- ✅ Windows (Git Bash, WSL)
- ✅ FreeBSD / autres Unix
