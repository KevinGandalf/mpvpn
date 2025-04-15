#!/bin/bash
source /opt/mpvpn/globals.sh

# Durchlaufe alle VPN-Interfaces in der Liste
for vpn in "${WGVPN_LIST[@]}"; do
    wg_config_file="/etc/wireguard/$vpn.conf"  # Der Pfad zur WireGuard-Konfigurationsdatei für das VPN

    # Hole die lokale IP-Adresse aus der WireGuard-Konfiguration
    local_ip=$(grep -oP 'Address = \K[^\s]+' "$wg_config_file" | cut -d'/' -f1)

    # Überprüfe, ob eine lokale IP gefunden wurde
    if [[ -n "$local_ip" ]]; then
        echo "➕ WG: $vpn → default via $local_ip dev $vpn"
        
        # Erstelle die spezifische Route für das WireGuard-Interface
        echo "➕ Setze Route für $vpn zur Tabelle ${vpn}..."
        ip route add default via "$local_ip" dev "$vpn" table "$vpn"
        
        # Logge den Erfolg
        echo "Route für $vpn zur Tabelle $vpn gesetzt"
    else
        # Fehlerbehandlung, falls keine IP gefunden wurde
        echo "⚠️  $vpn → Keine lokale IP in der Konfiguration gefunden"
    fi
done
