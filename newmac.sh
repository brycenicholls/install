#!/bin/bash

# Global variables
CONFIG_DIR="$HOME/.config"
SSH_KEY_PATH="$HOME/.ssh/id_ed25519" # ED25519 SSH key path
VENV_DIR="$HOME/venvs"
REPO_URL="git@github.com:brycenicholls/dots.git"
REPO_DIR="$HOME/dots"
# Arrays of packages to install
formulae=(
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
  yt-dlp
  zsh-autosuggestions
  zsh-syntax-highlighting
)

casks=(
  utm
  font-jetbrains-mono-nerd-font
  obsidian
  spotify
  wezterm
)

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
    git clone "$REPO_URL" "$REPO_DIR" || {
      echo "Failed to clone the repository. Exiting."
      exit 1
    }

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

# Function to ensure the $VENV_DIR exists, create if it doesn't
ensure_venv_dir() {
  if [ ! -d "$VENV_DIR" ]; then
    echo "Creating $VENV_DIR..."
    mkdir -p "$VENV_DIR" && echo "$VENV_DIR created." || echo "Failed to create $VENV_DIR."
  else
    echo "$VENV_DIR already exists."
  fi
}

# Main script execution
echo "Starting setup process..."

install_homebrew
update_homebrew
install_packages "formulae" formulae[@]
install_packages "casks" casks[@]
cleanup_homebrew
ensure_venv_dir
check_symlinks
create_ssh_key_if_not_exists

echo "Setup complete!"
