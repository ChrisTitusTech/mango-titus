#!/bin/bash

echo "===================================================="
echo " 🚀  Ultimate MangoWM & DMS Environment Bootstrap   "
echo "===================================================="

# 1. DEFINE PATHS AND DIRECTORY TREE
REAL_HOME="/home/$USER"
CONFIG_DIR="$REAL_HOME/.config"
WALLPAPER_DIR="$REAL_HOME/Pictures/backgrounds"
TARGET_WALLPAPER="$WALLPAPER_DIR/1r1kk9qi00961.png"

mkdir -p "$CONFIG_DIR"
mkdir -p "$WALLPAPER_DIR"

# 2. DETECT PACKAGE MANAGER & DEPLOY PRIMARY INFRASTRUCTURE
if command -v dnf &> /dev/null; then
    echo "📦 System Identified: Fedora Linux (DNF)."
    echo "----------------------------------------------------"
    sudo dnf install -y git dnf-plugins-core
    sudo dnf install -y --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra\$releasever" terra-release
    sudo dnf copr enable -y avengemedia/dms
    sudo dnf copr enable -y pgdev/ghostty
    sudo dnf install -y libX11-devel libXinerama-devel libXft-devel libXrandr-devel imlib2-devel \
                        swww dms thunar firefox ghostty mangowm

elif command -v pacman &> /dev/null; then
    echo "📦 System Identified: Arch Linux (Pacman + AUR)."
    echo "----------------------------------------------------"
    sudo pacman -Syu --needed --noconfirm git base-devel libx11 libxinerama libxft libxrandr imlib2 swww thunar firefox

    AUR_HELPER=""
    if command -v paru &> /dev/null; then
        AUR_HELPER="paru"
    elif command -v yay &> /dev/null; then
        AUR_HELPER="yay"
    else
        git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
        cd /tmp/yay-bin && makepkg -si --noconfirm && cd - > /dev/null
        AUR_HELPER="yay"
    fi
    $AUR_HELPER -S --needed --noconfirm dms-shell-git ghostty mangowm-git
else
    echo "❌ Unrecognized distribution engine. Halting deployment."
    exit 1
fi

echo "----------------------------------------------------"
echo "🛠️  Deploying Git Repository Asset Packages"
echo "----------------------------------------------------"

# 3. CLONE AND STAGE CHRIS TITUS'S MANGO WINDOW MANAGER CONFIG
if [ -d "$CONFIG_DIR/mango" ]; then
    mv "$CONFIG_DIR/mango" "$CONFIG_DIR/mango.bak"
fi
git clone https://github.com/Real-MullaC/mango-titus-1/ /tmp/mango-titus
mkdir -p "$CONFIG_DIR/mango"
cp -r /tmp/mango-titus/. "$CONFIG_DIR/mango/"
rm -rf /tmp/mango-titus

# 4. PULL THE NORD BACKGROUND REPOSITORY
if [ ! -d "$WALLPAPER_DIR/nord-background" ]; then
    git clone https://github.com/ChrisTitusTech/nord-background.git "$WALLPAPER_DIR/nord-background"
else
    cd "$WALLPAPER_DIR/nord-background" && git pull && cd - > /dev/null
fi

echo "----------------------------------------------------"
echo "🎉 Setup Complete! Your customized configuration environment is fully deployed."
