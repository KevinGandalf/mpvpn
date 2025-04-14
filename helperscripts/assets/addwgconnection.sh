#!/bin/bash

WG_CONFIG_DIR="/etc/wireguard"

# IPv6-Adressen aus Zeilen entfernen
remove_ipv6_lines() {
    echo "$1" | awk '
    BEGIN {
        FS = OFS = "="
    }
    /^Address[ \t]*=/ || /^AllowedIPs[ \t]*=/ {
        split($2, parts, ",")
        newval = ""
        for (i in parts) {
            gsub(/^ +| +$/, "", parts[i])
            if (parts[i] !~ /:/) {
                if (newval != "") newval = newval ","
                newval = newval parts[i]
            }
        }
        $2 = " " newval
        print
        next
    }
    { print }
    '
}

# IPv6-Erkennung
contains_ipv6() {
    echo "$1" | grep -E '([[:xdigit:]]+:){1,}' >/dev/null
}

# Verbindung anlegen
create_connection() {
    local name="$1"
    local content="$2"

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

    # Datei schreiben
    local file="$WG_CONFIG_DIR/$name.conf"
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
        local file="$WG_CONFIG_DIR/$name.conf"
        if [[ -e "$file" ]]; then
            echo "⚠️  Eine Konfiguration mit dem Namen '$name' existiert bereits unter $file."
            read -p "Möchtest du sie überschreiben? (y/n): " overwrite
            if [[ "$overwrite" != "y" ]]; then
                echo "↩️  Bitte wähle einen anderen Namen."
                continue
            fi
        fi
        break
    done

    echo "ℹ️  Füge den Inhalt der WireGuard-Konfigurationsdatei hier ein."
    echo "Bitte beende die Eingabe mit Ctrl+D:"
    config=$(</dev/stdin)
    create_connection "$name" "$config"
}

# Menü
while true; do
    echo "============================"
    echo " WireGuard Konfiguration"
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
