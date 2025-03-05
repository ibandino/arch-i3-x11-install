#!/bin/bash

# Farben für bessere Optik
PURPLE=${PURPLE:-'\033[0;35m'}  # Lila (Violett)
CYAN=${CYAN:-'\033[0;36m'}      # Cyan
GRAY=${GRAY:-'\033[0;37m'}      # Grau
DARK_GRAY=${DARK_GRAY:-'\033[1;30m'}  # Dunkelgrau
LIGHT_RED=${LIGHT_RED:-'\033[1;31m'}  # Hellrot
LIGHT_GREEN=${LIGHT_GREEN:-'\033[1;32m'}  # Hellgrün
LIGHT_YELLOW=${LIGHT_YELLOW:-'\033[1;33m'}  # Hellgelb
LIGHT_BLUE=${LIGHT_BLUE:-'\033[1;34m'}  # Hellblau
LIGHT_PURPLE=${LIGHT_PURPLE:-'\033[1;35m'}  # Helllila (Hellviolett)
LIGHT_CYAN=${LIGHT_CYAN:-'\033[1;36m'}  # Hellcyan
WHITE=${WHITE:-'\033[1;37m'}  # Weiß
RED=${RED:-'\033[0;31m'} # Rot
GREEN=${GREEN:-'\033[0;32m'} # Grün
YELLOW=${YELLOW:-'\033[0;33m'} # Gelb
BLUE=${BLUE:-'\033[0;34m'} # Blau
NC=${NC:-'\033[0m'} # Keine Farbe

# Einführende Informationen
clear

echo -e "${RED}######################################################################${NC}"
echo -e "${GRAY}         Willkommen zum ${RED}Band!no ${GRAY}Skript                  ${NC}"
echo -e "${GRAY}      Dieses Skript benötigt eine frische Arch-Installation          ${NC}"
echo -e "${GRAY} Das Skript sollte fehlerfrei laufen und ist vollständig auf Deutsch.${NC}"
echo -e "${RED}######################################################################${NC}"
echo -e "${DARK_GRAY}Skript zum Einrichten eines Arch Linux Systems mit i3 unter X11 ${NC}"

# Prüfen, ob das Skript als Root läuft
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Fehler: Dieses Skript sollte nicht als Root ausgeführt werden.${NC}"
    exit 1
fi

echo -e "${YELLOW}Prüfe sudo-Berechtigungen...${NC}"

# Sudo-Berechtigungen anfordern
if ! sudo -v; then
    echo -e "${RED}Fehler: Bitte führe das Skript mit sudo-Berechtigungen aus.${NC}"
    exit 1
fi

echo -e "${GREEN}Sudo-Berechtigungen erfolgreich erhalten.${NC}"

# Funktion für Fehlermeldungen
error_exit() {
    echo -e "${RED}$1${NC}" 1>&2
    exit 1
}

# Funktion für Fortschrittsmeldungen
info() {
    echo -e "${YELLOW}$1${NC}"
}

# Funktion für Erfolgsmeldungen
success() {
    echo -e "${GREEN}$1${NC}"
}

# Prüfen, ob Arch Linux läuft
echo -e "${YELLOW}Prüfe, ob das System Arch Linux ist...${NC}"
if [[ ! -f /etc/os-release ]] || ! grep -q "Arch Linux" /etc/os-release; then
    error_exit "Fehler: Dieses Skript ist nur für Arch Linux gedacht."
fi
success "Arch Linux ${GREEN}ERKANNT${NC}. Fortfahren…"

# Paketlisten definieren
# X11, i3 und Desktop-Komponenten
packages_pacman_base=(
    "xorg" "xorg-xinit" "i3-gaps" "sddm" "polybar" "rofi" "kitty" # Grundsetup
    "ttf-font-awesome" "ttf-hack" "xf86-input-libinput" # Schriftarten und Touchpad
    "pulseaudio" "pulseaudio-alsa" "networkmanager" # Sound und Netzwerk
    "broadcom-wl" "pacman-contrib" # WLAN für MacBook und paccache
)

# Benutzerdefinierte Pacman-Pakete
packages_pacman_user=(
    "neovim" "timeshift" "fastfetch" "gamemode" "htop" "xorg-xhost" "telegram" "firefox"
)

# Kombinierte Pacman-Liste
packages_pacman=("${packages_pacman_base[@]}" "${packages_pacman_user[@]}")

# AUR-Pakete
packages_aur=(
    "arch-update" "broadcom-wl-dkms" # Fallback für Broadcom WLAN
)

# GPU-Erkennung
echo -e "${YELLOW}Erkenne GPU-Typ...${NC}"
GPU_INFO=$(lspci | grep -i "vga\|3d")
if echo "$GPU_INFO" | grep -iq "amd"; then
    info "AMD-GPU erkannt. Füge vulkan-radeon zur Paketliste hinzu..."
    packages_pacman+=("vulkan-radeon" "lib32-vulkan-radeon")
elif echo "$GPU_INFO" | grep -iq "nvidia"; then
    info "NVIDIA-GPU erkannt. Füge nouveau und nvidia-dkms zur Paketliste hinzu..."
    packages_pacman+=("xf86-video-nouveau" "nvidia-open-dkms" "lib32-nvidia-utils")
elif echo "$GPU_INFO" | grep -iq "intel"; then
    info "Intel-GPU erkannt. Füge intel-media-driver und vulkan-intel zur Paketliste hinzu..."
    packages_pacman+=("vulkan-intel" "lib32-vulkan-intel" "intel-media-driver")
else
    info "Keine kompatible dedizierte GPU erkannt oder GPU-Typ nicht bestimmbar. Überspringe GPU-Treiberinstallation."
fi

# Funktion zum Installieren eines Pakets, falls nicht vorhanden
install_package() {
    local package="$1"
    if ! pacman -Q "$package" &> /dev/null; then
        info "Installiere $package..."
        if sudo pacman -S --noconfirm --needed "$package"; then
            success "$package wurde erfolgreich installiert."
        else
            error_exit "Fehler beim Installieren von $package."
        fi
    else
        success "$package ist bereits installiert."
    fi
}

# Funktion zum Installieren eines AUR-Pakets mit yay
install_aur_package() {
    local package="$1"
    if ! pacman -Q "$package" &> /dev/null; then
        info "Installiere $package aus dem AUR..."
        if yay -S --noconfirm --needed "$package"; then
            success "$package wurde erfolgreich aus dem AUR installiert."
        else
            error_exit "Fehler beim Installieren von $package aus dem AUR."
        fi
    else
        success "$package ist bereits installiert."
    fi
}

echo -e "${RED}########################################################################${NC}"
echo -e "${RED}########################################################################${NC}"
echo -e "${GRAY}                   Starte Paketinstallation                          ${NC}"
echo -e "${GRAY}           Beginne mit der Einrichtung des i3-X11-Setups...          ${NC}"
echo -e "${GRAY}                       Inklusive Basistools                          ${NC}"
echo -e "${RED}########################################################################${NC}"
echo -e "${RED}########################################################################${NC}"

# System aktualisieren
info "Aktualisiere System..."
sudo pacman -Syu --noconfirm || error_exit "Fehler bei der Aktualisierung"

# Basis-Tools installieren
info "Installiere Basistools (git, yay)..."
sudo pacman -S --noconfirm git base-devel || error_exit "Fehler bei Basistools"

# Yay (AUR-Helper) installieren, falls nicht vorhanden
if ! command -v yay &> /dev/null; then
    info "Installiere yay..."
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
fi

# Pacman-Pakete installieren
for pkg in "${packages_pacman[@]}"; do
    install_package "$pkg"
done

# AUR-Pakete installieren
for pkg in "${packages_aur[@]}"; do
    install_aur_package "$pkg"
done

# SDDM aktivieren
info "Aktiviere SDDM..."
sudo systemctl enable sddm || error_exit "Fehler bei SDDM"

# Polybar-Themes und Dotfiles installieren
info "Installiere Polybar-Themes und Dotfiles..."
git clone https://github.com/adi1090x/polybar-themes.git
cd polybar-themes
chmod +x setup.sh
./setup.sh # Hier musst du interaktiv ein Theme auswählen (z. B. "forest")
cd ..
rm -rf polybar-themes

# .xinitrc für manuellen Start erstellen
info "Erstelle .xinitrc..."
echo "exec i3" > ~/.xinitrc

# Broadcom-WLAN-Modul laden
info "Lade Broadcom-WLAN-Modul..."
sudo modprobe wl || echo -e "${RED}WLAN-Modul konnte nicht geladen werden, prüfe broadcom-wl${NC}"

# Netzwerk starten
info "Starte Netzwerk..."
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# Benutzer zur gamemode-Gruppe hinzufügen
info "Füge Benutzer zur gamemode-Gruppe hinzu..."
if getent group gamemode > /dev/null 2>&1; then
    sudo usermod -aG gamemode "$(whoami)"
    success "Benutzer wurde erfolgreich zur gamemode-Gruppe hinzugefügt."
else
    info "Die Gruppe 'gamemode' existiert nicht. Überspringe Hinzufügung."
fi

# Flatpak-Installation abfragen
echo -e "${YELLOW}Möchtest du Flatpak für zusätzliche Softwareunterstützung installieren? (j/n)${NC}"
read -r install_flatpak
if [[ "$install_flatpak" == "j" || "$install_flatpak" == "J" ]]; then
    info "Installiere Flatpak..."
    install_package "flatpak"
    echo -e "${YELLOW}Möchtest du empfohlene Flatpak-Anwendungen (Bottles und EasyFlatpak) installieren? (j/n)${NC}"
    read -r install_recommended_flatpaks
    if [[ "$install_recommended_flatpaks" == "j" || "$install_recommended_flatpaks" == "J" ]]; then
        flatpak install -y flathub com.usebottles.bottles || error_exit "Fehler beim Installieren von Bottles"
        flatpak install -y flathub org.dupot.easyflatpak || error_exit "Fehler beim Installieren von EasyFlatpak"
        success "Empfohlene Flatpak-Anwendungen erfolgreich installiert."
    else
        info "Überspringe Installation empfohlener Flatpak-Anwendungen."
    fi
else
    info "Überspringe Flatpak-Installation."
fi

# System bereinigen
clean_system() {
    info "Bereinige System-Cache..."
    echo -e "${YELLOW}Möchtest du den System-Cache wirklich bereinigen? Dies entfernt alle zwischengespeicherten Pakete. (j/n)${NC}"
    read -r confirm_clean
    if [[ "$confirm_clean" == "j" || "$confirm_clean" == "J" ]]; then
        if sudo paccache -r; then
            success "System-Cache erfolgreich bereinigt."
        else
            error_exit "Fehler beim Bereinigen des System-Caches."
        fi
    else
        info "Bereinigung des System-Caches wurde übersprungen."
    fi
}

# Fertigstellung
echo -e "${RED}########################################################################${NC}"
echo -e "${RED}########################################################################${NC}"
echo -e "${GRAY}                    Paketinstallation abgeschlossen                  ${NC}"
echo -e "${GRAY}              i3-X11 | AUR | Git | yay | broadcom-wl                 ${NC}"
echo -e "${GRAY}             polybar | xinitrc | SDDM | htop | firefox               ${NC}"
echo -e "${GRAY}        neovim | timeshift | fastfetch | gamemode | ttf-hack         ${NC}"
echo -e "${GRAY}  xorg | xorg-xinit | i3-gaps | rofi | kitty | xorg-xhost | telegram ${NC}"
echo -e "${GRAY} ttf-font-awesome | xf86-input-libinput | pulseaudio | pulseaudio-alsa ${NC}"
echo -e "${GRAY}                    networkmanager | Flatpak                         ${NC}"
echo -e "${RED}########################################################################${NC}"
echo -e "${RED}########################################################################${NC}"

echo -e "${RED}########################################################################${NC}"
echo -e "${LIGHT_PURPLE}
             ____  _     _____ ____  _          _     ____    _____  ____  ____  _     ____
            /   _\/ \   /  __//  _ \/ \  /|    / \ /\/  __\  /__ __\/  _ \/  _ \/ \   / ___\
            |  /  | |   |  \  | / \|| |\ ||    | | |||  \/|    / \  | / \|| / \|| |   |    \
            |  \__| |_/\|  /_ | |-||| | \||    | \_/||  __/    | |  | \_/|| \_/|| |_/\\___ |
            \____/\____/\____\\_/ \|\_/  \|    \____/\_/       \_/  \____/\____/\____/\____/
                                                                                       ${NC}"
echo -e "${RED}########################################################################${NC}"

clean_system

echo -e "${RED}########################################################################${NC}"
echo -e "${GREEN}
   ____      U_____ u     ____       U  ___ u    U  ___ u   _____
U |  _\"\ u \| ___\"|/ U | __\")u     /"_ \/     \/"_ \/  |_ \" _|
 \| |_) |/   |  _| \"   \|  _ \/     | | | |     | | | |    | |
  |  _ <     | |___      | |_) | .-,_| |_| | .-,_| |_| |   /| |\
  |_| \_\    |_____|     |____/   \_)-\___/   \_)-\___/   u |_| U
  //   \\_   <<   >>    _|| \\_        \\          \\     _// \\_
 (__)  (__) (__) (__) (__) (__)      (__)        (__)   (__) (__) ${NC}"
echo -e "${RED}########################################################################${NC}"
echo -e "${GREEN}Setup abgeschlossen! Starte neu mit 'reboot', um SDDM und i3 zu nutzen.${NC}"
