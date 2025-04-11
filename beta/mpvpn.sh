#!/bin/bash

# Globale Variablen einlesen
source /opt/mpvpn-routing/config/globals.sh

# Funktion zum Laden der ipset-Daten
load_ipsets() {
    if [ -f "$IPSET_FILE_STREAMING" ]; then
        ipset restore < "$IPSET_FILE_STREAMING"
        echo "[+] Streaming IPs aus $IPSET_FILE_STREAMING geladen."
    fi

    if [ -f "$IPSET_FILE_GAMING" ]; then
        ipset restore < "$IPSET_FILE_GAMING"
        echo "[+] Gaming IPs aus $IPSET_FILE_GAMING geladen."
    fi
}

# Funktion zum Speichern der ipset-Daten
save_ipsets() {
    ipset save "$IPSET_NAME" > "$IPSET_FILE_STREAMING"
    echo "[+] Streaming IPs in $IPSET_FILE_STREAMING gespeichert."

    ipset save "$IPSET_NAME" > "$IPSET_FILE_GAMING"
    echo "[+] Gaming IPs in $IPSET_FILE_GAMING gespeichert."
}

# Funktion zum Aktivieren/Deaktivieren des Stealth-Modus für Streaming
toggle_stealth_streaming() {
    if [ "$stealth_streaming_mode" == "true" ]; then
        echo "[+] Stealth Streaming aktiviert, keine IPs werden hinzugefügt."
        return 1  # Deaktiviert das Hinzufügen von IPs und Routing
    else
        echo "[+] Stealth Streaming deaktiviert, IPs werden hinzugefügt."
        return 0  # Aktiviert das Hinzufügen von IPs und Routing
    fi
}

# Funktion zum Aktivieren/Deaktivieren des Stealth-Modus für Gaming
toggle_stealth_gaming() {
    if [ "$stealth_gaming_mode" == "true" ]; then
        echo "[+] Stealth Gaming aktiviert, keine IPs werden hinzugefügt."
        return 1  # Deaktiviert das Hinzufügen von IPs und Routing
    else
        echo "[+] Stealth Gaming deaktiviert, IPs werden hinzugefügt."
        return 0  # Aktiviert das Hinzufügen von IPs und Routing
    fi
}

# Funktion zur Verarbeitung von Streaming-Diensten
process_streaming() {
    toggle_stealth_streaming
    if [ $? -eq 0 ]; then
        # Hier Code zum Abrufen und Hinzufügen von IPs aus Streaming-Diensten
        echo "[+] Verarbeite Streaming-Dienste..."
        # Code zum Hinzufügen von Streaming-IPs zu ipset
    fi
}

# Funktion zur Verarbeitung von Gaming-Diensten
process_gaming() {
    toggle_stealth_gaming
    if [ $? -eq 0 ]; then
        # Hier Code zum Abrufen und Hinzufügen von IPs aus Gaming-Diensten
        echo "[+] Verarbeite Gaming-Dienste..."
        # Code zum Hinzufügen von Gaming-IPs zu ipset
    fi
}

# Beim Start die ipsets laden
load_ipsets

# Beispiel für die Verarbeitung von Streaming und Gaming
process_streaming
process_gaming

# Am Ende des Skripts die ipsets speichern
trap save_ipsets EXIT

# Dein Restcode für das VPN oder andere Operationen...
