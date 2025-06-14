#!/bin/bash
# install.sh - Installation NBA modulaire

set -euo pipefail

# === CONFIGURATION ===
NBA_VERSION="1.0.0"
NBA_REPO="https://github.com/votre-repo/nba"
NBA_INSTALL_DIR="${NBA_INSTALL_DIR:-/usr/local/bin}"
NBA_LIB_DIR="${NBA_LIB_DIR:-/usr/local/lib/nba}"

# Détection OS
case "$OSTYPE" in
    msys*|cygwin*|mingw*)
        NBA_INSTALL_DIR="${NBA_INSTALL_DIR:-$HOME/bin}"
        NBA_LIB_DIR="${NBA_LIB_DIR:-$HOME/.nba/lib}"
        ;;
esac

# === COULEURS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# === FONCTIONS INSTALLATION ===
check_permissions() {
    local install_dir="$1"
    local lib_dir="$2"
    
    # Tester écriture dans install_dir
    if [[ ! -w "$(dirname "$install_dir")" ]]; then
        log_error "Permissions insuffisantes pour $install_dir"
        log_info "Essayez: sudo $0 ou NBA_INSTALL_DIR=\$HOME/bin $0"
        return 1
    fi
    
    # Créer lib_dir si nécessaire
    if [[ ! -d "$lib_dir" ]]; then
        mkdir -p "$lib_dir" || {
            log_error "Impossible de créer $lib_dir"
            return 1
        }
    fi
    
    return 0
}

download_nba() {
    local temp_dir="$1"
    
    log_info "Téléchargement NBA v$NBA_VERSION..."
    
    if command -v git &> /dev/null; then
        # Clone via Git
        git clone --depth 1 "$NBA_REPO" "$temp_dir" || {
            log_error "Échec clone Git depuis $NBA_REPO"
            return 1
        }
    elif command -v curl &> /dev/null; then
        # Download archive via curl
        local archive_url="${NBA_REPO}/archive/main.tar.gz"
        curl -L "$archive_url" | tar -xz -C "$temp_dir" --strip-components=1 || {
            log_error "Échec téléchargement depuis $archive_url"
            return 1
        }
    elif command -v wget &> /dev/null; then
        # Download archive via wget
        local archive_url="${NBA_REPO}/archive/main.tar.gz"
        wget -O- "$archive_url" | tar -xz -C "$temp_dir" --strip-components=1 || {
            log_error "Échec téléchargement depuis $archive_url"
            return 1
        }
    else
        log_error "Git, curl ou wget requis pour l'installation"
        return 1
    fi
    
    log_success "NBA téléchargé"
    return 0
}

install_nba_files() {
    local temp_dir="$1"
    local install_dir="$2"
    local lib_dir="$3"
    
    log_info "Installation fichiers NBA..."
    
    # Installer script principal
    if [[ -f "$temp_dir/nba" ]]; then
        # Adapter les chemins dans le script
        sed "s|NBA_LIB_DIR=.*|NBA_LIB_DIR=\"$lib_dir\"|" "$temp_dir/nba" > "$install_dir/nba"
        chmod +x "$install_dir/nba"
        log_success "Script principal installé: $install_dir/nba"
    else
        log_error "Script principal nba non trouvé dans $temp_dir"
        return 1
    fi
    
    # Installer modules lib/
    if [[ -d "$temp_dir/lib" ]]; then
        cp -r "$temp_dir/lib"/* "$lib_dir/"
        
        # Rendre exécutables les scripts de commandes
        find "$lib_dir" -name "*.sh" -type f -exec chmod +x {} \;
        
        log_success "Modules installés: $lib_dir"
        
        # Compter modules installés
        local module_count=$(find "$lib_dir" -name "*.sh" -type f | wc -l)
        log_info "$module_count modules installés"
    else
        log_warning "Répertoire lib/ non trouvé, installation script seul"
    fi
    
    return 0
}

verify_installation() {
    local install_dir="$1"
    
    log_info "Vérification installation..."
    
    # Tester commande
    if [[ -x "$install_dir/nba" ]]; then
        # Test basique
        if "$install_dir/nba" version &> /dev/null; then
            log_success "NBA installé et fonctionnel"
            
            # Afficher version
            local version=$("$install_dir/nba" version 2>/dev/null)
            log_info "Version installée: $version"
            
            return 0
        else
            log_error "NBA installé mais ne fonctionne pas"
            return 1
        fi
    else
        log_error "NBA non installé ou non exécutable"
        return 1
    fi
}

setup_shell_integration() {
    local install_dir="$1"
    
    # Vérifier si install_dir est dans PATH
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        log_warning "$install_dir n'est pas dans PATH"
        
        # Proposer ajout automatique
        echo
        echo "Ajout suggéré au PATH:"
        echo "  echo 'export PATH=\"$install_dir:\$PATH\"' >> ~/.bashrc"
        echo "  source ~/.bashrc"
        echo
        
        # Pour zsh
        if [[ -f "$HOME/.zshrc" ]]; then
            echo "Pour zsh:"
            echo "  echo 'export PATH=\"$install_dir:\$PATH\"' >> ~/.zshrc"
            echo "  source ~/.zshrc"
            echo
        fi
        
        # Git Bash Windows
        case "$OSTYPE" in
            msys*|cygwin*|mingw*)
                echo "Pour Git Bash (Windows):"
                echo "  echo 'export PATH=\"$install_dir:\$PATH\"' >> ~/.bash_profile"
                echo "  source ~/.bash_profile"
                echo
                ;;
        esac
    else
        log_success "NBA accessible via PATH"
    fi
}

show_post_install_help() {
    cat << 'EOF'

🎉 INSTALLATION NBA TERMINÉE!

PREMIERS PAS:
  nba --help              # Aide générale
  nba init "Mon Roman"    # Créer nouveau projet
  
COMMANDES PRINCIPALES:
  nba init                # Nouveau projet
  nba context             # Contexte LLM  
  nba wordcount           # Statistiques
  nba publish             # Générer PDF
  
CONFIGURATION:
  nba config --list       # Voir configuration
  nba config --set NBA_AUTHOR_NAME="Votre Nom"
  
DOCUMENTATION:
  Chaque commande a son aide: nba COMMAND --help
  
Pour commencer: nba init --help
EOF
}

# === DÉSINSTALLATION ===
uninstall_nba() {
    local install_dir="$1"
    local lib_dir="$2"
    
    log_info "Désinstallation NBA..."
    
    # Supprimer script principal
    if [[ -f "$install_dir/nba" ]]; then
        rm "$install_dir/nba"
        log_success "Script principal supprimé"
    fi
    
    # Supprimer modules
    if [[ -d "$lib_dir" ]]; then
        rm -rf "$lib_dir"
        log_success "Modules supprimés"
    fi
    
    # Nettoyer config utilisateur (optionnel)
    if [[ -d "$HOME/.nba" ]]; then
        echo
        read -p "Supprimer aussi la configuration utilisateur ~/.nba ? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$HOME/.nba"
            log_success "Configuration utilisateur supprimée"
        fi
    fi
    
    log_success "NBA désinstallé"
}

# === MISE À JOUR ===
update_nba() {
    local install_dir="$1"
    local lib_dir="$2"
    
    log_info "Mise à jour NBA..."
    
    # Sauvegarder configuration
    local backup_config=""
    if [[ -f "$HOME/.nba/config" ]]; then
        backup_config=$(cat "$HOME/.nba/config")
        log_info "Configuration sauvegardée"
    fi
    
    # Réinstaller
    install_nba_main "$install_dir" "$lib_dir"
    
    # Restaurer configuration
    if [[ -n "$backup_config" ]]; then
        echo "$backup_config" > "$HOME/.nba/config"
        log_success "Configuration restaurée"
    fi
    
    log_success "NBA mis à jour"
}

# === FONCTION PRINCIPALE INSTALLATION ===
install_nba_main() {
    local install_dir="$1"
    local lib_dir="$2"
    
    # Vérifier permissions
    if ! check_permissions "$install_dir" "$lib_dir"; then
        return 1
    fi
    
    # Créer répertoire temporaire
    local temp_dir
    temp_dir=$(mktemp -d) || {
        log_error "Impossible de créer répertoire temporaire"
        return 1
    }
    
    # Nettoyage automatique
    trap "rm -rf '$temp_dir'" EXIT
    
    # Télécharger
    if ! download_nba "$temp_dir"; then
        return 1
    fi
    
    # Installer
    if ! install_nba_files "$temp_dir" "$install_dir" "$lib_dir"; then
        return 1
    fi
    
    # Vérifier
    if ! verify_installation "$install_dir"; then
        return 1
    fi
    
    return 0
}

# === POINT D'ENTRÉE ===
main() {
    echo "🕷️ NBA - Nerd Book Author v$NBA_VERSION"
    echo "Installation modulaire"
    echo
    
    case "${1:-install}" in
        install)
            install_nba_main "$NBA_INSTALL_DIR" "$NBA_LIB_DIR"
            setup_shell_integration "$NBA_INSTALL_DIR"
            show_post_install_help
            ;;
        uninstall)
            uninstall_nba "$NBA_INSTALL_DIR" "$NBA_LIB_DIR"
            ;;
        update)
            update_nba "$NBA_INSTALL_DIR" "$NBA_LIB_DIR"
            ;;
        --help|-h)
            cat << 'HELP'
NBA INSTALLER

USAGE:
  ./install.sh [ACTION]

ACTIONS:
  install     Installation complète (défaut)
  update      Mise à jour NBA
  uninstall   Désinstallation complète
  
VARIABLES D'ENVIRONNEMENT:
  NBA_INSTALL_DIR    Répertoire installation script (défaut: /usr/local/bin)
  NBA_LIB_DIR        Répertoire modules (défaut: /usr/local/lib/nba)
  
EXEMPLES:
  ./install.sh                                    # Installation standard
  NBA_INSTALL_DIR=$HOME/bin ./install.sh         # Installation utilisateur
  sudo ./install.sh                              # Installation système
  ./install.sh uninstall                         # Désinstallation
HELP
            ;;
        *)
            log_error "Action inconnue: $1"
            echo "Utilisez: $0 --help"
            exit 1
            ;;
    esac
}

main "$@"