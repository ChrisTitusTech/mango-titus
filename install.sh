#!/bin/bash

echo "===================================================="
echo " 🚀  Ultimate MangoWM & DMS Environment Bootstrap   "
echo "===================================================="

# 1. DEFINE PATHS AND DIRECTORY TREE
REAL_HOME="/home/$USER"
CONFIG_DIR="$REAL_HOME/.config"
WALLPAPER_DIR="$REAL_HOME/Pictures/backgrounds"
TARGET_WALLPAPER="$WALLPAPER_DIR/1r1kk9qi00961.png"

echo "Creating core system directory paths..."
mkdir -p "$CONFIG_DIR"
mkdir -p "$WALLPAPER_DIR"

# 2. DETECT PACKAGE MANAGER & DEPLOY PRIMARY INFRASTRUCTURE
if command -v dnf &> /dev/null; then
    echo "📦 System Identified: Fedora Linux (DNF)."
    echo "----------------------------------------------------"

    # Configure custom app streams & repositories
    echo "🔧 Registering system repositories for DMS, Ghostty, and MangoWM..."
    sudo dnf copr enable -y avengemedia/dms
    sudo dnf copr enable -y pgdev/ghostty
    sudo dnf copr enable -y gregoryloscombe/mangowc

    # Bulk install git, compiler components, app stacks, and the compositor itself
    echo "📥 Fetching system dependencies and core window manager binaries..."
    sudo dnf install -y git libX11-devel libXinerama-devel libXft-devel libXrandr-devel imlib2-devel \
                        swww dms thunar firefox ghostty mangowm

elif command -v pacman &> /dev/null; then
    echo "📦 System Identified: Arch Linux (Pacman + AUR)."
    echo "----------------------------------------------------"

    # Update core frameworks and ensure git is present
    sudo pacman -Syu --needed --noconfirm git base-devel libx11 libxinerama libxft libxrandr imlib2 swww thunar firefox

    # Locate or bootstrap the AUR wrapper cleanly
    AUR_HELPER=""
    if command -v paru &> /dev/null; then
        AUR_HELPER="paru"
    elif command -v yay &> /dev/null; then
        AUR_HELPER="yay"
    else
        echo "⚠️ Bootstrapping yay helper temporarily..."
        git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
        cd /tmp/yay-bin && makepkg -si --noconfirm && cd - > /dev/null
        AUR_HELPER="yay"
    fi

    # Fetch compositor components, shell components, and terminal environments
    echo "📥 Invoking AUR helper to fetch window compositor modules..."
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
    echo "⚠️ Existing mango configuration detected. Backing it up to mango.bak..."
    mv "$CONFIG_DIR/mango" "$CONFIG_DIR/mango.bak"
fi

echo "📥 Cloning ChrisTitusTech/mango-titus directly into configuration path..."
git clone https://github.com/ChrisTitusTech/mango-titus/ /tmp/mango-titus
mv /tmp/mango-titus/mango "$CONFIG_DIR/mango"
rm -rf /tmp/mango-titus

# 4. PULL THE NORD BACKGROUND REPOSITORY
if [ ! -d "$WALLPAPER_DIR/nord-background" ]; then
    echo "🎨 Fetching Chris Titus Nord backgrounds..."
    git clone https://github.com/ChrisTitusTech/nord-background.git "$WALLPAPER_DIR/nord-background"
else
    echo "🎨 Nord backgrounds already present. Pulling latest master commits..."
    cd "$WALLPAPER_DIR/nord-background" && git pull && cd - > /dev/null
fi

# 5. INITIALIZE THE RUNTIME BACKGROUND DEPLOYMENTS
sleep 2
echo "Configuring default asset background mapping keys..."
dms ipc call wallpaper set "$TARGET_WALLPAPER"

# 6. INTERACTIVE WALLPAPER CYCLING DIALOGUE
echo "----------------------------------------------------"
echo "Configure your desktop Wallpaper Cycling Interval behavior:"

PS3="Select an option (1-3): "
options=("Off" "5 Minutes" "10 Minutes")

select opt in "${options[@]}"
do
    case $opt in
        "Off")
            echo "Halting layout background rotation ticks..."
            dms ipc call wallpaper toggle_cycling false
            break
            ;;
        "5 Minutes")
            echo "Setting dynamic background transition frame clock to 5 minutes (300s)..."
            dms ipc call wallpaper toggle_cycling true
            dms ipc call wallpaper set_mode "interval"
            dms ipc call wallpaper set_interval 300
            dms ipc call wallpaper next
            break
            ;;
        "10 Minutes")
            echo "Setting dynamic background transition frame clock to 10 minutes (600s)..."
            dms ipc call wallpaper toggle_cycling true
            dms ipc call wallpaper set_mode "interval"
            dms ipc call wallpaper set_interval 600
            dms ipc call wallpaper next
            break
            ;;
        *)
            echo "Invalid selection $REPLY. Please pass an indexing integer from 1 to 3."
            ;;
    esac
done

echo "----------------------------------------------------"
echo "🎉 Setup Complete! Your customized configuration environment is fully deployed."
