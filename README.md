# 🕷️ SILK CLI - Smart Integrated Literary Kit
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
silk init "My Novel"

# Generate LLM context
silk context "Character development"

# Track progress
silk wordcount 80000

# Publish professional PDF
silk publish -f digital
```

## 🏗️ Architecture

SILK uses a modular architecture for maintainability and extensibility:

```
silk-cli/
├── silk                    # Main script (loads modules)
├── lib/
│   ├── core/              # Core modules (auto-loaded)
│   │   ├── utils.sh       # Utility functions
│   │   ├── config.sh      # Configuration management
│   │   └── vault.sh       # Project management
│   ├── commands/          # Command modules
│   │   ├── init.sh        # silk init
│   │   ├── context.sh     # silk context
│   │   ├── wordcount.sh   # silk wordcount
│   │   └── publish.sh     # silk publish
│   └── templates/         # Genre templates
│       ├── polar.sh       # Crime/thriller templates
│       └── fantasy.sh     # Fantasy templates
├── install.sh             # Modular installer
└── tests/                 # Test suite
```

## 💡 Usage

```bash
# Create new project
silk init "My Novel"

# In project directory
silk context "Question for Claude"    # Generate LLM context
silk wordcount 80000                  # Progress statistics
silk publish -f iphone                # Generate PDF
```

## 🎯 Features

- ✅ **Smart Templates** : Project generators by genre (crime, fantasy, romance)
- ✅ **Integrated Workflow** : From idea to PDF in 4 commands
- ✅ **Literary Focus** : Templates adapted by market (FR, US, UK, DE)
- ✅ **Kit Complete** : LLM context + statistics + publishing
- ✅ **Multi-Platform** : Compatible Windows/Linux/macOS

## 📚 Typical Workflow

1. **🕷️ Weaving** : `silk init "Project"` → Complete structure generated
2. **✍️ Writing** : Write in `01-Manuscrit/Ch*.md` with `## manuscrit`
3. **🧠 Analysis** : `silk context "Question"` → Context for LLM
4. **📊 Tracking** : `silk wordcount` → Intelligent progress stats
5. **📖 Publishing** : `silk publish` → Professional multi-format PDF

## 🤖 LLM Integration

### Standard SILK separator
```markdown
# Ch.15 : Title

## SILK Objectives
- Metadata for planning...

## manuscrit
[Pure content analyzed by LLM]
```

### Intelligent context
```bash
silk context "Coherence Emma" -ch 15,18,20-25  # Flexible range
silk context --full --wordcount                # Complete mode + stats
```

## 🛠️ Development

### Adding New Modules

1. Create module in appropriate directory (`lib/core/`, `lib/commands/`, `lib/templates/`)
2. Follow naming convention: `cmd_<name>()` for commands
3. Export functions and set `readonly SILK_MODULE_<NAME>_LOADED=true`
4. Test with `./tests/test-modular-compatibility.sh`

### Module Dependencies

```bash
# In module file
if [[ "${SILK_CORE_UTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/utils required" >&2
    exit 1
fi
```

## 🧪 Testing

```bash
# Basic compatibility
./tests/test-modular-compatibility.sh

# Full test suite
./tests/silk_master_test_suite.sh

# Platform compatibility
./tests/test-compatibility.sh
```

## 🌍 Supported Genres

### Crime/Thriller (🇫🇷 specialty)
- Investigation/revelation structured templates
- Target audience women CSP+ 35-55
- Specialized LLM prompts for investigation

### Fantasy/Romance
- Coherent worldbuilding (fantasy)
- Authentic relationship arcs (romance)
- Templates adapted for international markets

## 🛠️ Technologies

- **Core** : Portable Bash (Windows Git Bash compatible)
- **Publishing** : Pandoc + XeLaTeX for professional PDF
- **Future** : .NET Core migration planned (GUI)
- **LLM** : Multi-provider (Claude, GPT, etc.)

## 📈 Roadmap

- [x] **v1.0** : Modular CLI Smart Integrated Literary Kit
- [ ] **v1.1** : Complete multilingual support + extended genre templates
- [ ] **v1.2** : Advanced progression analytics + market metrics
- [ ] **v2.0** : .NET Core version + GUI + cloud integration
- [ ] **v2.1** : Integrated AI + personalized writing coaching

## 🤝 Contributing

Based on real author workflow with 30+ chapters, 450 pages, optimized LLM pipeline.

SILK was born from the concrete need to optimize modern writing with AI.

1. Fork the project
2. Create feature branch (`git checkout -b feature/silk-amazing`)
3. Commit (`git commit -m 'Add SILK amazing feature'`)
4. Push (`git push origin feature/silk-amazing`)
5. Create Pull Request

## 📊 Project Stats

![GitHub stars](https://img.shields.io/github/stars/oinant/silk-cli)
![GitHub downloads](https://img.shields.io/github/downloads/oinant/silk-cli/total)
![GitHub issues](https://img.shields.io/github/issues/oinant/silk-cli)

## 🕷️ Philosophy

*"Just like a spider weaves its web, SILK helps you weave together characters, plot, and narrative into compelling fiction."*

**SILK weaves your story together.**

Generated with ❤️ by an author for authors.
*Smart Integrated Literary Kit - Structured Intelligence for Literary Kreation*
