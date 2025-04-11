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

# Beim Start die ipsets laden
load_ipsets

# Füge hier deinen Code für die VPN- und Netzwerk-Konfiguration hinzu...
# Zum Beispiel: VPN-Start, iptables-Setups usw.

# Am Ende des Skripts die ipsets speichern
trap save_ipsets EXIT

# Dein Restcode für das VPN oder andere Operationen...
