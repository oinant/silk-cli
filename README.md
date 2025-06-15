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

## 🧪 Testing & Debugging

### Running Tests

SILK includes comprehensive test suites to ensure reliability across platforms:

```bash
# Basic functionality tests
./tests/test-modular-compatibility.sh

# Full test suite with project creation
./tests/silk_master_test_suite.sh

# Platform compatibility (Windows/Linux/macOS)
./tests/test-compatibility.sh

# Architecture validation
./validate-silk-architecture.sh
```

### Debug Mode

Enable detailed logging to troubleshoot issues:

```bash
# Enable debug mode for any command
SILK_DEBUG=true silk context "Your prompt" --chapters 1-5

# Debug specific modules
SILK_DEBUG=true silk init "Debug Project" --yes

# Debug extraction issues
SILK_DEBUG=true silk wordcount --summary
```

**Debug output shows:**
- Module loading sequence
- File detection and processing
- Chapter extraction logic
- Range validation
- Context generation steps

### Common Issues

**Chapter detection fails:**
```bash
# Check file patterns and extraction
SILK_DEBUG=true silk context "Test" --chapters 1-3
# Look for "extract_chapter_number" debug lines
```

**Context generation stops early:**
```bash
# Verify bash strict mode compatibility
set +e  # Temporarily disable in problematic functions
```

**Module loading errors:**
```bash
# Check module dependencies
SILK_DEBUG=true silk --version
```

## 🤝 Contributing

SILK was born from a real author's workflow with 30+ chapters, 450 pages, and optimized LLM integration. We welcome contributions that enhance the modern writing experience!

### Development Setup

1. **Fork and clone:**
   ```bash
   git clone https://github.com/your-username/silk-cli
   cd silk-cli
   chmod +x silk
   ```

2. **Test your environment:**
   ```bash
   ./tests/test-modular-compatibility.sh
   SILK_DEBUG=true ./silk version
   ```

3. **Create a test project:**
   ```bash
   ./silk init "Development Test" --genre polar-psychologique --yes
   cd development-test
   ../silk context "Test development setup"
   ```

### Architecture Guidelines

**Core Modules (`lib/core/`):**
- `utils.sh` - Utility functions (logging, validation, file operations)
- `config.sh` - Configuration management
- `vault.sh` - Project detection and navigation

**Command Modules (`lib/commands/`):**
- Follow naming: `cmd_<name>()` for main function
- Include `show_<name>_help()` for detailed help
- Add dependency checks for required core modules
- Export functions and set `readonly SILK_COMMAND_<NAME>_LOADED=true`

**Template Modules (`lib/templates/`):**
- Genre-specific project generators
- Market-adapted content (FR, US, UK, DE)
- LLM-optimized prompts and structures

### Code Standards

```bash
#!/bin/bash
# lib/commands/example.sh - Brief description

# Dependency verification
if [[ "${SILK_CORE_UTILS_LOADED:-false}" != "true" ]]; then
    echo "❌ Module core/utils required" >&2
    exit 1
fi

cmd_example() {
    # Implementation with proper error handling
    # Use set +e around problematic loops if needed
}

show_example_help() {
    cat << 'HELP'
🕷️ SILK EXAMPLE - Brief description
# Detailed help content
HELP
}

# Export functions
export -f cmd_example show_example_help
readonly SILK_COMMAND_EXAMPLE_LOADED=true
```

### Testing Your Changes

1. **Syntax validation:**
   ```bash
   bash -n lib/commands/your-module.sh
   ./check-syntax.sh  # Validates all modules
   ```

2. **Functionality testing:**
   ```bash
   # Test your specific command
   SILK_DEBUG=true ./silk your-command --help
   SILK_DEBUG=true ./silk your-command test-args

   # Full integration test
   ./tests/silk_master_test_suite.sh
   ```

3. **Platform compatibility:**
   ```bash
   # Test on different environments
   ./tests/test-compatibility.sh
   ```

### Contribution Areas

**High Priority:**
- **Genre Templates:** Expand beyond polar/fantasy/romance
- **LLM Integration:** New prompt strategies and context optimizations
- **Publication Formats:** Additional PDF layouts and export options
- **Analytics:** Advanced progression tracking and writing metrics

**Multilingual Support:**
- Template localization (ES, DE, IT)
- Market-specific publishing formats
- Cultural adaptation of narrative structures

**Platform Extensions:**
- VS Code extension for SILK projects
- Integration with writing tools (Scrivener, Notion)
- Cloud sync and collaboration features

### Pull Request Process

1. **Create feature branch:**
   ```bash
   git checkout -b feature/silk-amazing-feature
   ```

2. **Develop with tests:**
   ```bash
   # Make changes
   # Add tests
   ./tests/test-modular-compatibility.sh
   ```

3. **Document your changes:**
   - Update relevant help text
   - Add examples to documentation
   - Include any breaking changes in commit message

4. **Submit PR:**
   ```bash
   git commit -m 'Add SILK amazing feature

   - Implements new context generation strategy
   - Adds support for screenplay format
   - Includes tests and documentation

   BREAKING CHANGE: Updates context.sh API'
   git push origin feature/silk-amazing-feature
   ```

### Development Philosophy

**Author-Centric Design:**
- Every feature should solve a real writing problem
- Optimize for daily workflow efficiency
- Maintain compatibility with existing projects

**LLM-First Approach:**
- Context generation is the core feature
- Templates should produce optimal prompts
- Support multiple LLM providers and styles

**Cross-Platform Reliability:**
- Test on Windows (Git Bash), Linux, and macOS
- Handle path differences and shell variations
- Maintain POSIX compatibility where possible

### Community

- **Issues:** Report bugs, request features, ask questions
- **Discussions:** Share writing workflows, LLM strategies
- **Wiki:** Contribute templates, examples, best practices

**Recognition:** Contributors are credited in releases and documentation. Major contributions may be highlighted in the project showcase.

SILK weaves together the contributions of the writing community! 🕸️

## 📊 Project Stats

![GitHub stars](https://img.shields.io/github/stars/oinant/silk-cli)
![GitHub downloads](https://img.shields.io/github/downloads/oinant/silk-cli/total)
![GitHub issues](https://img.shields.io/github/issues/oinant/silk-cli)

## 🕷️ Philosophy

*"Just like a spider weaves its web, SILK helps you weave together characters, plot, and narrative into compelling fiction."*

**SILK weaves your story together.**

Generated with ❤️ by an author for authors.
*Smart Integrated Literary Kit - Structured Intelligence for Literary Kreation*
