#!/bin/bash

# globals.sh einbinden
source /opt/mpvpn/globals.sh

# Prüfung auf essentielle Variablen
if [[ -z "$DEFAULT_SUBNET" || -z "$DEFAULT_LANIF" || -z "$DEFAULT_LANIP" || -z "$DEFAULT_WANGW" ]]; then
    echo "Fehlende Netzwerkvariablen! Überprüfe globals.sh"
    exit 1
fi

# Start-Präferenzen
fwmark_pref=100
srcip_pref=200
catchall_pref=300
main_pref=400
default_pref=500

# Regeln für alle Tabellen
for entry in "${EXTRA_RT_TABLES[@]}"; do
    table_id=$(echo "$entry" | awk '{print $1}')
    table_name=$(echo "$entry" | awk '{print $2}')

    if [ -n "$table_name" ]; then
        # Füge Regel für FW-Mark hinzu (ohne 0x)
        echo "ip rule add fwmark $table_id lookup $table_name pref $fwmark_pref"
        
        # Wenn die Tabelle "mirror" ist, DNS-Routen hinzufügen
        if [[ "$table_name" == "mirror" ]]; then
            echo "Füge DNS-Server Routen für Tabelle 'mirror' hinzu..."

            # Routen für DNS-Server (nur für 'mirror' oder andere Tabellen nach Bedarf)
            ip route add 1.1.1.1/32 via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" table "$table_id" 2>/dev/null
            ip route add 8.8.8.8/32 via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" table "$table_id" 2>/dev/null

            # Füge IP-Regeln für die DNS-Server hinzu (nur für 'mirror')
            ip rule add to 1.1.1.1/32 table "$table_id" pref 150 2>/dev/null
            ip rule add to 8.8.8.8/32 table "$table_id" pref 150 2>/dev/null
        fi

        # Routingregeln: Standardroute und Subnetzroute für jede Tabelle
        ip route add default via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" table "$table_id" 2>/dev/null
        ip route add "$DEFAULT_SUBNET" dev "$DEFAULT_LANIF" src "$DEFAULT_LANIP" table "$table_id" 2>/dev/null

        # Präferenz für die nächste Regel erhöhen
        fwmark_pref=$((fwmark_pref + 10))
    fi
done

# Feste IPs, z.B. Streaming Clients:
for ip in "${NON_VPN_CLIENTS[@]}"; do
    echo "ip rule add from $ip lookup clear pref $srcip_pref"
    ((srcip_pref++))  # Präferenz für jede neue IP erhöhen
done

# Catch-All: ALLE anderen ins VPN
echo "ip rule add from $DEFAULT_SUBNET lookup vpn pref $catchall_pref"

# Main und Default Tabellen zuletzt
echo "ip rule add lookup main pref $main_pref"
echo "ip rule add lookup default pref $default_pref"

# Ausgabe der Regeln beendet
echo "[OK] Alle Regeln wurden erfolgreich generiert."
