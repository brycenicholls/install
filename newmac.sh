#!/bin/bash

# Global variables
CONFIG_DIR="$HOME/.config"
SSH_KEY_PATH="$HOME/.ssh/id_ed25519" # ED25519 SSH key path
VENV_DIR="$HOME/venvs"
REPO_URL="git@github.com:brycenicholls/dots.git"
REPO_DIR="$HOME/dots"

# Default computer type
USE_CASE=""

# Parse command line options
while getopts ":wh" opt; do
  case $opt in
  w)
    USE_CASE="work"
    ;;
  h)
    USE_CASE="home"
    ;;
  *)
    echo "Usage: $0 -w (for work) or -h (for home)"
    exit 1
    ;;
  esac
done

# Check if USE_CASE is set
if [ -z "$USE_CASE" ]; then
  echo "No use case specified. Use -w for work or -h for home."
  exit 1
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
    /bin/bash NONINTERACTIVE=1 -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && {
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
      eval "$(/opt/homebrew/bin/brew shellenv)"
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
    if ! brew list --formula | grep -q "^$package\$"; then
      brew install "$package" || {
        echo "Failed to install $package. Exiting."
        exit 1
      }
    else
      echo "$package is already installed."
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
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "$USER@$(hostname)" || {
      echo "Failed to create ED25519 SSH key."
      return 1
    }
    echo "SSH key created at $SSH_KEY_PATH."
  fi
}

# Function to check for specific symlinks in the $CONFIG_DIR
check_symlinks() {
  echo "Checking for specific symlinks in $CONFIG_DIR..."
  [ -d "$CONFIG_DIR" ] || {
    echo "$CONFIG_DIR does not exist."
    return
  }

  local found_symlinks=false
  for symlink in "${symlinks[@]}"; do
    local full_symlink_path="$CONFIG_DIR/$symlink"
    if [ -L "$full_symlink_path" ]; then
      local symlink_info
      symlink_info=$(stat -f "%Sp@ %l %Su %Sm %N -> %Y" "$full_symlink_path")
      echo "$symlink_info"
      found_symlinks=true
    else
      echo "$symlink not found or is not a symlink."
    fi
  done

  # Pause the script if no symlinks were found
  if [ "$found_symlinks" = false ]; then
    echo "No symlinks found in $CONFIG_DIR. Press any key to download the repository and continue..."
    read -n 1 -s # Wait for user input
    echo         # Print a newline for better readability

    # Download the repository
    echo "Downloading the repository from $REPO_URL..."
    if ! git clone "$REPO_URL" "$REPO_DIR"; then
      echo "Failed to clone the repository. Exiting."
      exit 1
    fi

    # Change to the repository directory and run the stow command
    cd "$REPO_DIR" || {
      echo "Failed to enter $REPO_DIR. Exiting."
      exit 1
    }
    echo "Running 'stow' for the symlinks..."
    stow "${symlinks[@]}" || {
      echo "Failed to run 'stow' for symlinks. Exiting."
      exit 1
    }
  fi
}

# Function to ensure the $CONFIG_DIR exists, create if it doesn't
ensure_config_dir() {
  if [ ! -d "$CONFIG_DIR" ]; then
    echo "Creating $CONFIG_DIR..."
    mkdir -p "$CONFIG_DIR" && echo "$CONFIG_DIR created." || echo "Failed to create $CONFIG_DIR."
  else
    echo "$CONFIG_DIR already exists."
  fi
}

# Function to ensure the $VENV_DIR exists, create if it doesn't
ensure_venv_dir() {
  if [ ! -d "$VENV_DIR" ]; then
    echo "Creating $VENV_DIR..."
    mkdir -p "$VENV_DIR" && echo "$VENV_DIR created." || echo "Failed to create $VENV_DIR."
  else
    echo "$VENV_DIR already exists."
  fi
}

# Function to configure iTerm2 preferences
configure_iterm2_preferences() {
  if [[ "$(uname)" == "Darwin" ]]; then
    echo "Configuring iTerm2 preferences..."
    curl -o "$HOME/Library/Preferences/com.googlecode.iterm2.plist" https://raw.githubusercontent.com/nordtheme/iterm2/refs/heads/develop/src/xml/Nord.itermcolors
    echo "iTerm2 preferences configured."
  else
    echo "This script only runs on macOS."
  fi
}

import_iterm_profile() {
  # Path to your profile JSON file
  local profile_json_path="$HOME/path/to/your/profile.json"

  # Check if the profile JSON file exists
  if [[ ! -f "$profile_json_path" ]]; then
    echo "Profile JSON file not found at: $profile_json_path"
    return 1
  fi

  # Import the profile using osascript
  osascript <<EOF
tell application "iTerm2"
    set profilePath to POSIX file "$profile_json_path"
    set importedProfiles to (import profile profilePath)
    repeat with p in importedProfiles
        if name of p is "Your Profile Name" then -- Change this to your actual profile name
            set default profile to p
        end if
    end repeat
end tell
EOF

  echo "Profile imported and set to default."
}

# Main script execution
echo "Starting setup process..."

install_homebrew
update_homebrew
install_packages "formulae" formulae[@]
install_packages "casks" additional_casks[@]
cleanup_homebrew
ensure_config_dir
ensure_venv_dir
check_symlinks
create_ssh_key_if_not_exists
configure_iterm2_preferences
import_iterm_profile

echo "Setup complete!"
