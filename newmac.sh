#!/bin/bash

# Global variables
CONFIG_DIR="$HOME/.config"
SSH_KEY_PATH="$HOME/.ssh/id_ed25519" # ED25519 SSH key path
VENV_DIR="$HOME/venvs"
REPO_URL="git@github.com:brycenicholls/dots.git"
REPO_DIR="$HOME/dots"

# Default computer type
USE_CASE=""
VERBOSE=false

# Parse command line options
while getopts ":whv" opt; do
  case $opt in
  w)
    USE_CASE="work"
    ;;
  h)
    USE_CASE="home"
    ;;
  v)
    VERBOSE=true
    ;;
  *)
    echo "Usage: $0 -w (for work) or -h (for home) [-v for verbose mode]"
    exit 1
    ;;
  esac
done

# Check if USE_CASE is set
if [ -z "$USE_CASE" ]; then
  echo "No use case specified. Use -w for work or -h for home."
  exit 1
fi

# Enable verbose mode if -v option is passed
if [ "$VERBOSE" = true ]; then
  set -x
fi

# Common array of packages
common_formulae=(
  ansible-language-server
  ansible-lint
  bat
  bat-extras
  eza
  fd
  fuzzy-find
  fzf
  lazygit
  lolcat
  luarocks
  neovim
  ripgrep
  rust
  starship
  stow
  tree
  tree-sitter
  wget
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Additional packages based on USE_CASE
case $USE_CASE in
work)
  additional_formulae=(
    google-chrome
    teleport
  )
  ;;
home)
  additional_formulae=(
    yt-dlp
    firefox
  )
  ;;
esac

# Merged array of formulae
formulae=("${common_formulae[@]}" "${additional_formulae[@]}")

# Array of casks (common for both types)
common_casks=(
  font-jetbrains-mono-nerd-font
  obsidian
  spotify
)

case $USE_CASE in
work)
  additional_casks=(
    iterm2
    slack
  )
  ;;
home)
  additional_casks=(
    utm
    wezterm
  )
  ;;
esac

# Array of symlinks to check
symlinks=(
  "btop"
  "nvim"
  "starship.toml"
  "wezterm"
)

# Function to install Homebrew if not installed
install_homebrew() {
  if ! command -v brew &>/dev/null; then
    echo "Homebrew not found. Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && {
      if [[ "$(uname -m)" == "x86_64" ]]; then
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >>~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
      else
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi
    } || {
      echo "Failed to install Homebrew. Exiting."
      exit 1
    }
  else
    echo "Homebrew is already installed."
  fi
}

# Function to update Homebrew
update_homebrew() {
  echo "Updating Homebrew..."
  brew update || {
    echo "Failed to update Homebrew. Exiting."
    exit 1
  }
}

# Function to install packages from Homebrew
install_packages() {
  local package_type=$1
  local packages=("${!2}")

  echo "Installing Homebrew $package_type..."
  for package in "${packages[@]}"; do
    if [ "$package_type" == "formulae" ]; then
      if ! brew list --formula | grep -q "^$package\$"; then
        brew install "$package" || {
          echo "Failed to install $package. Exiting."
          exit 1
        }
      else
        echo "$package is already installed."
      fi
    elif [ "$package_type" == "casks" ]; then
      if ! brew list --cask | grep -q "^$package\$"; then
        brew install --cask "$package" || {
          echo "Failed to install $package. Exiting."
          exit 1
        }
      else
        echo "$package is already installed."
      fi
    fi
  done
}

# Function to cleanup Homebrew
cleanup_homebrew() {
  echo "Cleaning up outdated Homebrew versions..."
  brew cleanup || echo "Failed to cleanup Homebrew."
}

# Function to create ED25519 SSH key if it doesn't exist
create_ssh_key_if_not_exists() {
  if [ -f "$SSH_KEY_PATH" ]; then
    echo "ED25519 SSH key already exists at $SSH_KEY_PATH."
  else
    echo "Creating ED25519 SSH key..."
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "$USE_CASE"
    echo "SSH key created at $SSH_KEY_PATH."
  fi
}

# Function to clone repo if not already cloned
ensure_config_dir() {
  if [ ! -d "$REPO_DIR" ]; then
    echo "Config directory not found. Cloning repository..."
    git clone "$REPO_URL" "$REPO_DIR" || {
      echo "Failed to clone repository. Exiting."
      exit 1
    }
  else
    echo "Config repository already exists at $REPO_DIR."
  fi
}

# Function to create Python virtual environment directory if it doesn't exist
ensure_venv_dir() {
  if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment directory..."
    mkdir -p "$VENV_DIR"
  else
    echo "Virtual environment directory already exists at $VENV_DIR."
  fi
}

# Function to check if symlinks are in place and create them if necessary
check_symlinks() {
  cd "$REPO_DIR" || {
    echo "Could not change directory to $REPO_DIR. Exiting."
    exit 1
  }

  for symlink in "${symlinks[@]}"; do
    if [ ! -L "$CONFIG_DIR/$symlink" ]; then
      echo "Creating symlink for $symlink in $CONFIG_DIR"
      stow "$symlink" || {
        echo "Failed to stow $symlink. Exiting."
        exit 1
      }
    else
      echo "Symlink for $symlink already exists."
    fi
  done
}

# Function to import iTerm2 profile
import_iterm_profile() {
  if [[ "$(uname)" == "Darwin" ]]; then
    echo "Importing iTerm2 profile..."
    osascript <<EOF
      tell application "iTerm2"
        do shell script "open '$HOME/path/to/your/profile.json'"
      end tell
EOF
    echo "iTerm2 profile imported."
  fi
}

# Function to install .dmg apps
install_dmg() {
  local dmg_url="$1"
  local app_name="$2"

  dmg_file="/tmp/${app_name}.dmg"
  mount_point="/Volumes/${app_name}"

  echo "Downloading $app_name from $dmg_url..."
  curl -L "$dmg_url" -o "$dmg_file"

  echo "Mounting DMG..."
  hdiutil attach "$dmg_file" -mountpoint "$mount_point"

  echo "Copying $app_name to Applications folder..."
  cp -R "$mount_point"/*.app /Applications/

  echo "Unmounting DMG..."
  hdiutil detach "$mount_point"

  echo "Cleaning up..."
  rm "$dmg_file"
}

# Main execution flow
install_homebrew
update_homebrew
install_packages "formulae" formulae[@]
install_packages "casks" common_casks[@]
cleanup_homebrew

create_ssh_key_if_not_exists
ensure_config_dir
ensure_venv_dir
check_symlinks
