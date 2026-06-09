#!/bash/bin
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
git clone https://github.com/ChrisTitusTech/mango-titus/ /tmp/mango-titus
mkdir -p "$CONFIG_DIR/mango"
cp -r /tmp/mango-titus/. "$CONFIG_DIR/mango/"
rm -rf /tmp/mango-titus

# 4. PULL THE NORD BACKGROUND REPOSITORY
if [ ! -d "$WALLPAPER_DIR/nord-background" ]; then
    git clone https://github.com/ChrisTitusTech/nord-background.git "$WALLPAPER_DIR/nord-background"
else
    cd "$WALLPAPER_DIR/nord-background" && git pull && cd - > /dev/null
fi

# 5. INITIALIZE THE RUNTIME BACKGROUND DEPLOYMENTS
if command -v dms &> /dev/null; then
    sleep 2
    dms ipc call wallpaper set "$TARGET_WALLPAPER"
fi

# 6. KEYBOARD INTERACTIVE SELECTION FUNCTION
choose_from_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0

    # Hide screen cursor during choice loop
    tput civis
    trap 'tput cnorm; exit 1' INT TERM

    while true; do
        # Clear menu area lines
        echo -e "\n$title"
        for i in "${!options[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                # Highlight option with an arrow pointer
                echo -e "  \e[1;32m➔  ${options[$i]}\e[0m"
            else
                echo -e "     ${options[$i]}"
            fi
        done

        # Read specific keyboard input hardware hex codes (3 bytes for arrow keys)
        read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            if [[ "$key" == "[A" ]]; then # Up Arrow
                ((selected--))
                [ "$selected" -lt 0 ] && selected=$((${#options[@]} - 1))
            elif [[ "$key" == "[B" ]]; then # Down Arrow
                ((selected++))
                [ "$selected" -ge "${#options[@]}" ] && selected=0
            fi
        elif [[ "$key" == "" ]]; then # Enter Key pressed
            break
        fi

        # Clear menu block layout to redraw cleanly over old frames
        lines_to_clear=$((${#options[@]} + 2))
        tput cuu $lines_to_clear
        tput ed
    done

    # Restore default blinking text cursor
    tput cnorm
    return "$selected"
}

# 7. EXECUTE KEYBOARD INTERACTIVE MENU
options_list=("Off" "5 Minutes" "10 Minutes")
choose_from_menu "Use your Up/Down arrow keys and press Enter to select interval:" "${options_list[@]}"
choice=$?

echo "----------------------------------------------------"
case $choice in
    0)
        echo "Halting layout background rotation ticks..."
        if command -v dms &> /dev/null; then dms ipc call wallpaper toggle_cycling false; fi
        ;;
    1)
        echo "Setting dynamic background transition frame clock to 5 minutes (300s)..."
        if command -v dms &> /dev/null; then
            dms ipc call wallpaper toggle_cycling true
            dms ipc call wallpaper set_mode "interval"
            dms ipc call wallpaper set_interval 300
            dms ipc call wallpaper next
        fi
        ;;
    2)
        echo "Setting dynamic background transition frame clock to 10 minutes (600s)..."
        if command -v dms &> /dev/null; then
            dms ipc call wallpaper toggle_cycling true
            dms ipc call wallpaper set_mode "interval"
            dms ipc call wallpaper set_interval 600
            dms ipc call wallpaper next
        fi
        ;;
esac

echo "----------------------------------------------------"
echo "🎉 Setup Complete! Your customized configuration environment is fully deployed."
