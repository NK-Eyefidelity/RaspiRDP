#!/bin/bash

# Paketquellen aktualisieren und Software installieren
sudo apt-get update
sudo apt-get install -y freerdp2-x11 yad wget

# Grafikmodus von Wayland auf X11/Openbox (W1) umstellen
sudo raspi-config nonint do_wayland W1

# SH-Skript und PNG über Platzhalter-URLs herunterladen
wget -O "$HOME/rdp.sh" "https://github.com/NK-Eyefidelity/RaspiRDP/blob/0fcc80bd5032324ca8af66ca0c7c2638352e6a6d/rdp.sh"
wget -O "$HOME/icon.png" "https://github.com/NK-Eyefidelity/RaspiRDP/blob/0fcc80bd5032324ca8af66ca0c7c2638352e6a6d/eye.png"

# Das heruntergeladene Skript ausführbar machen
chmod +x "$HOME/rdp.sh"

# Autostart-Eintrag für LXDE/Openbox erstellen
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat <<EOF > "$AUTOSTART_DIR/kiosk_autostart.desktop"
[Desktop Entry]
Type=Application
Name=KioskAutostart
Exec=$HOME/rdp.sh
Terminal=false
EOF

echo "Setup beendet. Bitte mit 'sudo reboot' neu starten."
