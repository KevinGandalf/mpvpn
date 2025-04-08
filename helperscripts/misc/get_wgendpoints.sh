#!/bin/bash
source /opt/mpvpn/globals.sh

# Verzeichnis mit den WireGuard-Konfigurationsdateien
WG_DIR="/etc/wireguard"

# Gateway und Interface für die Route

# Array für bereits verarbeitete IPs (zum Duplikate vermeiden)
declare -A KNOWN_IPS

echo "Scanne WireGuard-Konfigurationen in $WG_DIR..."

# Alle WireGuard-Konfigurationsdateien durchsuchen
for CONF in "$WG_DIR"/*.conf; do
    echo "Analysiere: $CONF"

    # Alle Endpoints aus der Konfigurationsdatei extrahieren
    while read -r LINE; do
        if [[ $LINE =~ Endpoint\ =\ ([^:]+) ]]; then
            HOST=${BASH_REMATCH[1]}

            # Prüfen, ob es sich um eine IP oder einen Hostnamen handelt
            if [[ $HOST =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                IP=$HOST  # Ist bereits eine IP
            else
                echo "Löse Hostname auf: $HOST"
                IP=$(dig +short A "$HOST" | head -n 1)

                # Falls keine IP gefunden wurde, überspringen
                if [[ -z "$IP" ]]; then
                    echo "Fehler: Konnte $HOST nicht auflösen!"
                    continue
                fi
                echo "Hostname $HOST -> $IP"
            fi

            # Prüfen, ob IP bereits verarbeitet wurde
            if [[ -z "${KNOWN_IPS[$IP]}" ]]; then
                KNOWN_IPS["$IP"]=1
                echo "Setze Route für: $IP"
                sudo ip route add "$IP" via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF"
            fi
        fi
    done < "$CONF"
done

echo "Fertig!"
