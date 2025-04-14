#!/bin/bash

OVPN_CONFIG_DIR="/etc/openvpn"

# IPv6-Adressen aus Zeilen entfernen (nur relevante für OpenVPN-Konfigs)
remove_ipv6_lines() {
    echo "$1" | grep -vE '([[:xdigit:]]+:){1,}'
}

# IPv6-Erkennung
contains_ipv6() {
    echo "$1" | grep -E '([[:xdigit:]]+:){1,}' >/dev/null
}

# Verbindung anlegen
create_connection() {
    local name="$1"
    local content="$2"
    local file="$OVPN_CONFIG_DIR/$name.ovpn"

    # IPv6-Prüfung
    if contains_ipv6 "$content"; then
        echo "⚠️  IPv6-Adressen erkannt."
        read -p "Möchtest du IPv6-Adressen entfernen? (y/n): " remove
        if [[ "$remove" == "y" ]]; then
            content=$(remove_ipv6_lines "$content")
            echo "✅ IPv6-Adressen entfernt."
        else
            echo "ℹ️  IPv6-Adressen bleiben enthalten."
        fi
    fi

    # Datei prüfen
    if [ -e "$file" ]; then
        echo "⚠️ Die Datei '$file' existiert bereits."
        read -p "Möchtest du die bestehende Datei überschreiben? (y/n): " overwrite
        if [[ "$overwrite" != "y" ]]; then
            echo "❌ Vorgang abgebrochen. Keine Änderungen vorgenommen."
            return
        fi
    fi

    # Datei schreiben
    echo "$content" > "$file"

    if [ -s "$file" ]; then
        chmod 600 "$file"
        echo "✅ Verbindung '$name' wurde erfolgreich erstellt unter $file"
    else
        echo "❌ Fehler beim Schreiben der Konfiguration!"
    fi
}

# Verbindung hinzufügen
add_connection() {
    while true; do
        read -p "Gib einen Namen für die Verbindung ein: " name
        local file="$OVPN_CONFIG_DIR/$name.ovpn"
        if [ -e "$file" ]; then
            echo "⚠️ Die Konfiguration '$name.ovpn' existiert bereits!"
            read -p "Möchtest du sie überschreiben? (y/n): " overwrite
            if [[ "$overwrite" != "y" ]]; then
                echo "↩️  Bitte wähle einen anderen Namen."
                continue
            fi
        fi
        break
    done

    echo "🔽 Füge den Inhalt der OpenVPN-Konfigurationsdatei ein. Beende mit Ctrl+D:"
    config=$(</dev/stdin)
    create_connection "$name" "$config"
}

# Menü
while true; do
    echo "============================"
    echo " OpenVPN Konfiguration"
    echo "============================"
    echo "1. Neue Verbindung hinzufügen"
    echo "2. Beenden"
    read -p "Auswahl: " option
    case "$option" in
        1) add_connection ;;
        2) echo "🚪 Beende."; exit 0 ;;
        *) echo "❌ Ungültige Eingabe." ;;
    esac
done
