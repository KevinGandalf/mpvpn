#!/bin/bash

source /opt/mpvpn/globals.sh

echo "📝 Füge fwmark-Regeln mit lookup main hinzu..."

# Zähler für fwmark
counter=1

# Füge VPN-Listen zu ip rule hinzu und setze fwmark mit lookup main
for vpn in "${WGVPN_LIST[@]}"; do
    # Setze fwmark entsprechend des counters, lookup wird auf main gesetzt
    echo "➕ Füge ip rule für $vpn mit fwmark $counter und lookup main hinzu..."
    sudo ip rule add fwmark $counter lookup main
    ((counter++))
done

# Wenn OpenVPN aktiviert ist, füge auch OpenVPN-Listen hinzu
if [ "$ENABLE_OVPN" = true ]; then
    for vpn in "${OVPN_LIST[@]}"; do
        # Setze fwmark entsprechend des counters, lookup wird auf main gesetzt
        echo "➕ Füge ip rule für $vpn mit fwmark $counter und lookup main hinzu..."
        sudo ip rule add fwmark $counter lookup main
        ((counter++))
    done
else
    echo "🔒 OpenVPN ist deaktiviert – überspringe das Hinzufügen der OpenVPN fwmark-Regeln."
fi

# Zusätzliche Regeln für extra Einträge (z.B. clear, smtp)
for entry in "${EXTRA_RT_TABLES[@]}"; do
    # Extrahiere die Nummer und den Namen
    table_number=$(echo $entry | awk '{print $1}')
    table_name=$(echo $entry | awk '{print $2}')
    
    echo "➕ Füge ip rule für $table_name mit fwmark $counter und lookup main hinzu..."
    sudo ip rule add fwmark $counter lookup main
    ((counter++))
done

echo "✅ fwmark-Regeln mit lookup main wurden hinzugefügt."
