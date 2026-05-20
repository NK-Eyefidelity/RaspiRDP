#!/bin/bash

# === Konfiguration ===
RDP_IP="127.0.0.1"
RDP_DOMAIN="DESKTOP.local"
WINDOW_ICON="./icon.png"
ADMIN_PASS="xxxxx" # <--- HIER DEIN ADMIN-PASSWORT EINTRAGEN

# Pfade für die LXDE/Openbox-Konfiguration
OPENBOX_DIR="$HOME/.config/openbox"
OPENBOX_CONF="$OPENBOX_DIR/lxde-pi-rc.xml"
OPENBOX_RC="$HOME/.config/openbox/rc.xml"
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

# Lokale Openbox-Config anlegen, falls sie noch nicht existiert
if [ ! -f "$OPENBOX_CONF" ]; then
    mkdir -p "$OPENBOX_DIR"
    if [ -f /etc/xdg/openbox/lxde-pi-rc.xml ]; then
        cp /etc/xdg/openbox/lxde-pi-rc.xml "$OPENBOX_CONF"
    elif [ -f /etc/xdg/openbox/lxde-rc.xml ]; then
        cp /etc/xdg/openbox/lxde-rc.xml "$OPENBOX_CONF"
    fi
fi

# Shortcuts deaktivieren
if [ -f "$OPENBOX_CONF" ]; then
    sed -i 's/lxterminal<\/command>/DISABLED_lxterminal<\/command>/g' "$OPENBOX_CONF"
    sed -i 's/x-terminal-emulator<\/command>/DISABLED_x-terminal-emulator<\/command>/g' "$OPENBOX_CONF"
    sed -i 's/lxpanelctl menu<\/command>/DISABLED_lxpanelctl menu<\/command>/g' "$OPENBOX_CONF"
    sed -i 's/lxpanelctl run<\/command>/DISABLED_lxpanelctl run<\/command>/g' "$OPENBOX_CONF"
    sed -i 's/lxtask<\/command>/DISABLED_lxtask<\/command>/g' "$OPENBOX_CONF"

    # Änderungen live anwenden, ohne Neustart
    openbox --reconfigure
fi

# Laufzeit-Fallback: Desktop-Anzahl per X11 erzwingen
xprop -root -f _NET_NUMBER_OF_DESKTOPS 32c -set _NET_NUMBER_OF_DESKTOPS 1
xprop -root -f _NET_CURRENT_DESKTOP 32c -set _NET_CURRENT_DESKTOP 0

# =====================
# Ping-Status für Loginfenster
# =====================

update_ping_status() {
    if ping -c 1 -W 1 "$RDP_IP" >/dev/null 2>&1; then
        STATUS_DOT="<span foreground='green' size='x-large'>⬤</span>"
    else
        STATUS_DOT="<span foreground='red' size='x-large'>⬤</span>"
    fi
}

# =====================
# Funktion für den Admin-Login
# =====================

admin_unlock() {
    local ICON="$1"

    ADMIN_INPUT=$(yad --entry \
        --title="Administration" \
        --width=350 \
        --borders=20 \
        --image="dialog-password" \
        --text="\n Bitte Administrator-Passwort eingeben:\n" \
        --hide-text \
        --window-icon="$ICON" \
        --buttons-layout=center \
        --button="Zurück:1" \
        --button="Kiosk beenden:0" \
        --undecorated)

    if [ $? -eq 0 ] && [ "$ADMIN_INPUT" = "$ADMIN_PASS" ]; then
        yad --info \
            --title="Erfolg" \
            --text="\n Kiosk-Modus wird beendet...\n" \
            --timeout=2 \
            --no-buttons \
            --undecorated

        # Signale (Strg+C etc.) wieder aktivieren
        trap - SIGINT SIGQUIT SIGTSTP

        # X-Server Tastenkürzel wieder auf Standard setzen
        setxkbmap -option

        # Openbox-Shortcuts wiederherstellen
        if [ -f "$OPENBOX_CONF" ]; then
            sed -i 's/DISABLED_lxterminal<\/command>/lxterminal<\/command>/g' "$OPENBOX_CONF"
            sed -i 's/DISABLED_x-terminal-emulator<\/command>/x-terminal-emulator<\/command>/g' "$OPENBOX_CONF"
            sed -i 's/DISABLED_lxpanelctl menu<\/command>/lxpanelctl menu<\/command>/g' "$OPENBOX_CONF"
            sed -i 's/DISABLED_lxpanelctl run<\/command>/lxpanelctl run<\/command>/g' "$OPENBOX_CONF"
            sed -i 's/DISABLED_lxtask<\/command>/lxtask<\/command>/g' "$OPENBOX_CONF"
            openbox --reconfigure
        fi

        exit 0
    else
        yad --error \
            --title="Fehler" \
            --window-icon="$ICON" \
            --text="\n Falsches Passwort oder abgebrochen!\n" \
            --timeout=2 \
            --no-buttons \
            --undecorated
        return 1
    fi
}

# =========================================
# Hauptschleife
# =========================================

while true; do

    while true; do

        # Fall 1: Letzter Benutzer vorhanden
        if [ -n "$LAST_USER" ]; then
            update_ping_status

            PASSWORD=$(yad --entry \
                --title="RDP Login" \
                --width=450 \
                --borders=20 \
                --image="$WINDOW_ICON" \
                --text=" Willkommen zurück\n\n Anmeldung für: $RDP_IP   $STATUS_DOT\n Benutzer: $LAST_USER\n\n Bitte Passwort eingeben:" \
                --text-align=left \
                --hide-text \
                --window-icon="$WINDOW_ICON" \
                --buttons-layout=center \
                --button="Abbrechen:1" \
                --button="Benutzer ändern:2" \
                --button="Verbinden:0" \
                --timeout=60 \
                --undecorated)

            EXIT_CODE=$?

            # Benutzer ändern
            if [ $EXIT_CODE -eq 2 ]; then
                LAST_USER=""
                continue
            fi

            # Timeout -> Fenster neu aufbauen, Ping neu prüfen
            if [ $EXIT_CODE -eq 70 ]; then
                continue
            fi

            # Abbrechen -> Admin-Check
            if [ $EXIT_CODE -ne 0 ]; then
                admin_unlock "$WINDOW_ICON"
                continue
            fi

            if [ -z "$PASSWORD" ]; then
                yad --error \
                    --title="Fehler" \
                    --width=400 \
                    --borders=20 \
                    --image="dialog-error" \
                    --text="\nDas Passwort darf nicht leer sein!\n" \
                    --text-align=center \
                    --window-icon="$WINDOW_ICON" \
                    --buttons-layout=center \
                    --button="OK:0" \
                    --undecorated
                continue
            fi

            USERNAME="$LAST_USER"
            break

        # Fall 2: Neuer Benutzer
        else
            update_ping_status

            FORM_OUTPUT=$(yad --form \
                --title="RDP Login" \
                --width=450 \
                --borders=20 \
                --image="$WINDOW_ICON" \
                --separator="::::" \
                --text=" Neue Anmeldung\n\n Anmeldung für: $RDP_IP   $STATUS_DOT\n" \
                --text-align=left \
                --align=left \
                --window-icon="$WINDOW_ICON" \
                --buttons-layout=center \
                --field=" Benutzername" "" \
                --field=" Passwort:H" "" \
                --button="Abbrechen:1" \
                --button="Verbinden:0" \
                --timeout=60 \
                --undecorated)

            EXIT_CODE=$?

            # Timeout -> Fenster neu aufbauen, Ping neu prüfen
            if [ $EXIT_CODE -eq 70 ]; then
                continue
            fi

            # Abbrechen -> Admin-Check
            if [ $EXIT_CODE -ne 0 ]; then
                admin_unlock "$WINDOW_ICON"
                continue
            fi

            USERNAME=$(echo "$FORM_OUTPUT" | awk -F'::::' '{print $1}')
            PASSWORD=$(echo "$FORM_OUTPUT" | awk -F'::::' '{print $2}')

            if [ -z "$USERNAME" ]; then
                yad --error \
                    --title="Fehler" \
                    --width=400 \
                    --borders=20 \
                    --text="\nDer Benutzername darf nicht leer sein!\n" \
                    --text-align=center \
                    --window-icon="$WINDOW_ICON" \
                    --buttons-layout=center \
                    --button="OK:0" \
                    --undecorated
                continue
            fi

            if [ -z "$PASSWORD" ]; then
                yad --error \
                    --title="Fehler" \
                    --width=400 \
                    --borders=20 \
                    --image="dialog-error" \
                    --text="\nDas Passwort darf nicht leer sein!\n" \
                    --text-align=center \
                    --window-icon="$WINDOW_ICON" \
                    --buttons-layout=center \
                    --button="OK:0" \
                    --undecorated
                continue
            fi

            break
        fi
    done

    # Neuen/Bestätigten Benutzernamen für das nächste Mal speichern
    echo "$USERNAME" > "$USER_FILE"

    RDP_LOG=$(mktemp)

    # xfreerdp starten
    xfreerdp3 /v:"$RDP_IP" /d:"$RDP_DOMAIN" /u:"$USERNAME" /p:"$PASSWORD" \
        /multimon \
        /drive:USB,/media/administrator \
        /multitransport \
        /cache:bitmap:off,glyph:off \
        /sec:nla \
        /gdi:hw \
        -fonts \
        /gfx:thin-client,rfx \
        /network:auto \
        /cert:ignore \
        /usb:auto \
        /sound:sys:pulse,rate:44100 \
        /microphone:sys:pulse,rate:44100 \
        /f \
        > "$RDP_LOG" 2>&1

    RDP_EXIT=$?

    if grep -q "ERRINFO_LOGOFF_BY_USER" "$RDP_LOG"; then
        rm -f "$RDP_LOG"
        LAST_USER="$USERNAME"
        continue
    fi

    case "$RDP_EXIT" in
        0|11|12|15|255)
            rm -f "$RDP_LOG"
            LAST_USER="$USERNAME"
            continue
            ;;
        *)
            rm -f "$RDP_LOG"
            yad --error \
                --title="Verbindungsfehler" \
                --width=450 \
                --borders=20 \
                --image="dialog-error" \
                --text=" Verbindung fehlgeschlagen!\n\n Bitte prüfen Sie Ihr Passwort, Benutzername\n oder die Netzwerkverbindung." \
                --text-align=left \
                --window-icon="$WINDOW_ICON" \
                --buttons-layout=center \
                --button="Erneut versuchen:0" \
                --undecorated

            LAST_USER="$USERNAME"
            ;;
    esac

done
