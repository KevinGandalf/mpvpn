#!/bin/bash

# Definiere die Datei, in der die IP-Adressen gespeichert werden
IP_FILE="/opt/mpvpn/splitdns/vpn_bypass_ips.txt"
IP_FILE_PREVIOUS="/opt/mpvpn/splitdns/vpn_bypass_ips_previous.txt"

# Definiere das Gateway für enp1s0
GATEWAY="192.168.10.1"  # Passen Sie dies an Ihr tatsächliches Gateway an
INTERFACE="enp1s0"

# 1. Lade die IP-Adressen von GitHub herunter
echo "$(date) - Lade IP-Adressen von GitHub herunter..."
curl -s https://lou.h0rst.us/vpn_bypass.txt -o $IP_FILE

# 2. Vergleiche die neue Liste mit der vorherigen Liste
#if [ -f $IP_FILE_PREVIOUS ]; then
#    echo "$(date) - Vergleiche neue IP-Liste mit der alten..."

#    # Überprüfe, ob sich die Liste geändert hat, indem wir den Inhalt der Dateien vergleichen
#    if cmp -s "$IP_FILE" "$IP_FILE_PREVIOUS"; then
#        echo "$(date) - Keine Änderungen in der IP-Liste. Keine Routenänderungen erforderlich."
#        exit 0
#    else
#        echo "$(date) - IP-Liste hat sich geändert, füge Routen hinzu..."
#    fi
#else
#    echo "$(date) - Keine vorherige IP-Liste gefunden, füge alle Routen hinzu..."
#fi

# 3. Lade die IP-Adressen in ein Array
mapfile -t ip_list < $IP_FILE

# 4. Füge neue Routen hinzu oder aktualisiere sie
for ip in "${ip_list[@]}"; do
    ip_only=$(echo $ip | cut -d'/' -f1)

    # Überprüfen, ob die IP-Adresse bereits als Route existiert
    if ! ip route show | grep -q "$ip_only"; then
        echo "$(date) - Neue IP-Adresse $ip_only gefunden, füge Route hinzu"
        sudo ip route add $ip_only via $GATEWAY dev $INTERFACE
    else
        echo "$(date) - Route für $ip_only existiert bereits, überspringe"
    fi
done

# 5. Speichere die aktuelle Liste als die vorherige Liste für den nächsten Vergleich
echo "$(date) - Speichere die aktuelle IP-Liste für den nächsten Vergleich..."
cp $IP_FILE $IP_FILE_PREVIOUS

echo "$(date) - Abgleich abgeschlossen."
