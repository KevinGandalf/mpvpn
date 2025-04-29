#!/bin/bash

# Lade die globals.sh, damit die Variablen verfügbar sind
source $BASE_PATH/globals.conf

echo "Setze Routing-Tabellen für Ausnahmen und spezifische Tabellen..."

# Beispiel: Setze Regeln für die Tabellen aus EXTRA_RT_TABLES
for entry in "${EXTRA_RT_TABLES[@]}"; do
    table_number=$(echo $entry | awk '{print $1}')
    table_name=$(echo $entry | awk '{print $2}')

    echo "Füge ip rule für $table_name (Tabelle $table_number) hinzu..."

    # Wenn die Tabelle "clear" ist, soll der Verkehr direkt über das Gateway gehen
    if [[ "$table_name" == "clear" ]]; then
        # Regel für den gesamten Verkehr der Tabelle 100, der direkt über den Router gehen soll
        echo "Routing für 'clear' geht direkt über den Router..."
        ip rule add fwmark $table_number table $table_number

    # Wenn die Tabelle "smtp" ist, z.B. für Mailverkehr, könnte man hier ein spezielles Routing hinzufügen
    elif [[ "$table_name" == "smtp" ]]; then
        # Beispiel: Setze Route für SMTP über ein spezifisches VPN oder Interface
        echo "Routing für 'smtp' geht über ein spezielles Interface oder VPN..."
        ip rule add fwmark $table_number table $table_number

    fi

    # Hier könnte man für jede Tabelle zusätzlich Routing-Regeln setzen, z.B.:
    ip route add default via $DEFAULT_WANGW dev $DEFAULT_LANIF table $table_number

done

# Füge Regeln für nicht-VPN-Clients hinzu (aus der NON_VPN_CLIENTS-Liste)
for ip in "${NON_VPN_CLIENTS[@]}"; do
    echo "Füge Regel für IP $ip hinzu..."
    ip rule add from $ip table $table_number
done

echo "✅ Routing-Tabellen und Regeln wurden gesetzt."
