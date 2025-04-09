#!/bin/sh

source /opt/mpvpn/globals.sh

#ROUTING TABLES
echo "📝 Schreibe Routing Tables..."

# Füge VPN-Listen zu rt_tables hinzu
counter=1
for vpn in "${WGVPN_LIST[@]}"; do
    # Nutze die fortlaufende Nummerierung für die Tabellen-ID
    table_id=$counter
    if ! grep -q "^$table_id $vpn$" /etc/iproute2/rt_tables; then
        echo "➕ Füge $table_id $vpn zu rt_tables hinzu..."
        echo "$table_id $vpn" | sudo tee -a /etc/iproute2/rt_tables
    else
        echo "⚠️  Eintrag $table_id $vpn existiert bereits in rt_tables"
    fi
    ((counter++))
done

# Wenn OpenVPN aktiviert ist, füge auch OpenVPN-Listen hinzu
if [ "$ENABLE_OVPN" = true ]; then
    for vpn in "${OVPN_LIST[@]}"; do
        # Nutze die fortlaufende Nummerierung für die Tabellen-ID
        table_id=$counter
        if ! grep -q "^$table_id $vpn$" /etc/iproute2/rt_tables; then
            echo "➕ Füge $table_id $vpn zu rt_tables hinzu..."
            echo "$table_id $vpn" | sudo tee -a /etc/iproute2/rt_tables
        else
            echo "⚠️  Eintrag $table_id $vpn existiert bereits in rt_tables"
        fi
        ((counter++))
    done
else
    echo "🔒 OpenVPN ist deaktiviert – überspringe das Hinzufügen der OpenVPN-Tabellen."
fi

# Füge zusätzliche Einträge aus EXTRA_RT_TABLES hinzu
echo "📝 Füge zusätzliche Einträge zu rt_tables hinzu..."

for entry in "${EXTRA_RT_TABLES[@]}"; do
    if ! grep -q "^$entry$" /etc/iproute2/rt_tables; then
        echo "➕ Füge $entry zu rt_tables hinzu..."
        echo "$entry" | sudo tee -a /etc/iproute2/rt_tables
    else
        echo "⚠️  Eintrag $entry existiert bereits in rt_tables"
    fi
done

echo "✅ Einträge wurden hinzugefügt."
