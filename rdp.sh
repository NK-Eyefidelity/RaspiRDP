#!/bin/bash
# === Konfiguration ===
RDP_IP="192.168.0.7"
RDP_DOMAIN="Reiners-immobilien.local"
WINDOW_ICON="./eye.png"
ADMIN_PASS="geheim123" # <--- HIER DEIN ADMIN-PASSWORT EINTRAGEN

# Pfade für die LXDE/Openbox-Konfiguration
OPENBOX_DIR="$HOME/.config/openbox"
OPENBOX_CONF="$OPENBOX_DIR/lxde-pi-rc.xml"
# =====================

# Datei zum Speichern des letzten Benutzernamens
USER_FILE="$HOME/.last_rdp_user"

if [ -f "$USER_FILE" ]; then
    LAST_USER=$(cat "$USER_FILE")
else
    LAST_USER=""
fi

# =====================
# Tastenkürzel und Signale deaktivieren
# =====================
# Blockiert Strg+C (SIGINT), Strg+\ (SIGQUIT) und Strg+Z (SIGTSTP)
trap '' SIGINT SIGQUIT SIGTSTP

# Verhindert X-Server Tastenkürzel (wie Strg+Alt+Backspace)
setxkbmap -option srvrkeys:none

# NEU: LXDE/Openbox Shortcuts temporär deaktivieren
# 1. Lokale Config anlegen, falls sie noch nicht existiert
if [ ! -f "$OPENBOX_CONF" ]; then
    mkdir -p "$OPENBOX_DIR"
    if [ -f /etc/xdg/openbox/lxde-pi-rc.xml ]; then
        cp /etc/xdg/openbox/lxde-pi-rc.xml "$OPENBOX_CONF"
    elif [ -f /etc/xdg/openbox/lxde-rc.xml ]; then
        cp /etc/xdg/openbox/lxde-rc.xml "$OPENBOX_CONF"
    fi
fi

# 2. Befehle für Terminal, Startmenü und Taskmanager durch ungültige Namen ersetzen
if [ -f "$OPENBOX_CONF" ]; then
    sed -i 's/<command>lxterminal<\/command>/<command>DISABLED_lxterminal<\/command>/g' "$OPENBOX_CONF"
    sed -i 's/<command>x-terminal-emulator<\/command>/<command>DISABLED_x-terminal-emulator<\/command>/g' "$OPENBOX_CONF"
    sed -i 's/<command>lxpanelctl menu<\/command>/<command>DISABLED_lxpanelctl menu<\/command>/g' "$OPENBOX_CONF"
    sed -i 's/<command>lxpanelctl run<\/command>/<command>DISABLED_lxpanelctl run<\/command>/g' "$OPENBOX_CONF"
    sed -i 's/<command>lxtask<\/command>/<command>DISABLED_lxtask<\/command>/g' "$OPENBOX_CONF"
    
    # Änderungen live anwenden, ohne Neustart
    openbox --reconfigure
fi
# =====================

# === Funktion für den Admin-Login ===
admin_unlock() {
    ADMIN_INPUT=$(yad --entry \
        --title="Administration" \
        --width=350 \
        --borders=20 \
        --image="dialog-password" \
        --text="\n Bitte Administrator-Passwort eingeben:\n" \
        --hide-text \
        --window-icon="$WINDOW_ICON" \
        --buttons-layout=center \
        --button="Zurück:1" \
        --button="Kiosk beenden:0")

    # Wenn OK gedrückt wurde ($? -eq 0) UND das Passwort stimmt
    if [ $? -eq 0 ] && [ "$ADMIN_INPUT" = "$ADMIN_PASS" ]; then
        yad --info --title="Erfolg" --text="\n Kiosk-Modus wird beendet...\n" --timeout=2 --no-buttons
        
        # Signale (Strg+C etc.) wieder aktivieren
        trap - SIGINT SIGQUIT SIGTSTP
        
        # X-Server Tastenkürzel wieder auf Standard setzen
        setxkbmap -option
        
        # NEU: LXDE/Openbox Shortcuts wieder in den Ursprungszustand versetzen
        if [ -f "$OPENBOX_CONF" ]; then
            sed -i 's/<command>DISABLED_lxterminal<\/command>/<command>lxterminal<\/command>/g' "$OPENBOX_CONF"
            sed -i 's/<command>DISABLED_x-terminal-emulator<\/command>/<command>x-terminal-emulator<\/command>/g' "$OPENBOX_CONF"
            sed -i 's/<command>DISABLED_lxpanelctl menu<\/command>/<command>lxpanelctl menu<\/command>/g' "$OPENBOX_CONF"
            sed -i 's/<command>DISABLED_lxpanelctl run<\/command>/<command>lxpanelctl run<\/command>/g' "$OPENBOX_CONF"
            sed -i 's/<command>DISABLED_lxtask<\/command>/<command>lxtask<\/command>/g' "$OPENBOX_CONF"
            
            # Änderungen live anwenden
            openbox --reconfigure
        fi
		
		# Desktop-Elemente wiederherstellen (Für Raspberry Pi OS Bookworm)
        # wf-panel-pi &
        # pcmanfm --desktop &
        
        # Hinweis: Falls du das ältere Bullseye nutzt, ersetze die zwei Zeilen hierdrüber durch:
        lxpanel --profile LXDE-pi &
        pcmanfm --desktop --profile LXDE-pi &
        
        exit 0
    else
        # Bei falschem Passwort oder Abbruch
        yad --error --title="Fehler" --text="\n Falsches Passwort oder abgebrochen!\n" --timeout=2 --no-buttons
        return 1
    fi
}
# =========================================

# Äußere Schleife: Neustart bei Verbindungs-/Passwortfehlern
while true; do

    # Endlosschleife für die Menüführung
    while true; do

        # Fall 1: Wir haben einen bekannten letzten Nutzer
        if [ -n "$LAST_USER" ]; then

            PASSWORD=$(yad --entry \
                --title="RDP Login" \
                --width=450 \
                --borders=20 \
                --image="$WINDOW_ICON" \
                --text=" Willkommen zurück\n\n Anmeldung für: $RDP_IP\n Benutzer: $LAST_USER\n\n Bitte Passwort eingeben:" \
                --text-align=left \
                --hide-text \
                --window-icon="$WINDOW_ICON" \
                --buttons-layout=center \
                --button="Abbrechen:1" \
                --button="Benutzer ändern:2" \
                --button="Verbinden:0")

            EXIT_CODE=$?

            if [ $EXIT_CODE -eq 2 ]; then
                LAST_USER=""
                continue
            fi

            # Wenn Abbrechen gedrückt wurde oder Passwort leer ist -> Admin-Check
            if [ $EXIT_CODE -ne 0 ] || [ -z "$PASSWORD" ]; then
                admin_unlock
                continue # Geht zurück zum Start der Schleife
            fi

            USERNAME="$LAST_USER"
            break

        # Fall 2: Kein letzter Nutzer bekannt ODER "Benutzer ändern" wurde geklickt
        else
            FORM_OUTPUT=$(yad --form \
                --title="RDP Login" \
                --width=450 \
                --borders=20 \
                --image="$WINDOW_ICON" \
                --separator="::::" \
                --text=" Neue Anmeldung\n\n Bitte Anmeldedaten für $RDP_IP eingeben:\n" \
                --text-align=left \
                --align=left \
                --window-icon="$WINDOW_ICON" \
                --buttons-layout=center \
                --field=" Benutzername" "" \
                --field=" Passwort:H" "" \
                --button="Abbrechen:1" \
                --button="Verbinden:0")

            EXIT_CODE=$?

            # Wenn Abbrechen gedrückt wurde oder Formular leer ist -> Admin-Check
            if [ $EXIT_CODE -ne 0 ] || [ -z "$FORM_OUTPUT" ]; then
                admin_unlock
                continue # Geht zurück zum Start der Schleife
            fi

            USERNAME=$(echo "$FORM_OUTPUT" | awk -F'::::' '{print $1}')
            PASSWORD=$(echo "$FORM_OUTPUT" | awk -F'::::' '{print $2}')

            if [ -n "$USERNAME" ]; then
                break
            else
                yad --error --title="Fehler" \
                    --width=400 --borders=20 \
                    --text="\nDer Benutzername darf nicht leer sein!\n" \
                    --text-align=center \
                    --buttons-layout=center \
                    --button="OK:0"
            fi
        fi

    done

    # Neuen/Bestätigten Benutzernamen für das nächste Mal speichern
    echo "$USERNAME" > "$USER_FILE"

    # xfreerdp starten
    xfreerdp /v:"$RDP_IP" /d:"$RDP_DOMAIN" /u:"$USERNAME" /p:"$PASSWORD" /multitransport -bitmap-cache -glyph-cache /gdi:hw -fonts +gfx-thin-client /gfx:rfx /network:auto /cert-ignore /f

    RDP_EXIT=$?

    if [ $RDP_EXIT -eq 0 ]; then
        continue
    else
        yad --error --title="Verbindungsfehler" \
            --width=450 \
            --borders=20 \
            --image="dialog-error" \
            --text=" Verbindung fehlgeschlagen!\n\n Bitte prüfen Sie Ihr Passwort, Benutzername\n oder die Netzwerkverbindung." \
            --text-align=left \
            --buttons-layout=center \
            --button="Erneut versuchen:0"

        LAST_USER="$USERNAME"
    fi

done
