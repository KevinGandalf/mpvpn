#!/bin/bash

# Lade die globals.sh, damit die Variablen verfügbar sind
source $BASE_PATH/globals.conf

echo "Setze Routing-Tabellen für Ausnahmen und spezifische Tabellen..."

MARK=""
for entry in "${EXTRA_RT_TABLES[@]}"; do
    rt_id=$(echo "$entry" | awk '{print $1}')
    rt_name=$(echo "$entry" | awk '{print $2}')
    if [[ "$rt_name" == "mirror" ]]; then
        echo "Routing für 'mirror' geht direkt über den Router..."
        ip rule show | grep -q "fwmark $rt_id.*table $rt_id" || ip rule add fwmark $rt_id table $rt_id
        MARK=$rt_id
        break
    fi
done

if [[ -z "$MARK" ]]; then
    echo "Tabelle 'mirror' nicht gefunden!"
    exit 1
fi

# Prüfung auf essentielle Variablen
if [[ -z "$DEFAULT_SUBNET" || -z "$DEFAULT_LANIF" || -z "$DEFAULT_LANIP" || -z "$DEFAULT_WANGW" ]]; then
    echo "Fehlende Netzwerkvariablen! Überprüfe globals.sh"
    exit 1
fi

# Routingregeln
ip route add default via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" table "$MARK" 2>/dev/null
ip route add "$DEFAULT_SUBNET" dev "$DEFAULT_LANIF" src "$DEFAULT_LANIP" table "$MARK" 2>/dev/null
ip route add 1.1.1.1/32 via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" table "$MARK" 2>/dev/null
ip route add 8.8.8.8/32 via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" table "$MARK" 2>/dev/null

# Regeln hinzufügen
ip rule add from "$DEFAULT_LANIP/32" table "$MARK" pref 100 2>/dev/null
ip rule add to 1.1.1.1/32 table "$MARK" pref 150 2>/dev/null
ip rule add to 8.8.8.8/32 table "$MARK" pref 150 2>/dev/null

echo "Routing erfolgreich eingerichtet für Tabelle $MARK (mirror)"
echo "✅ Routing-Tabellen und Regeln wurden gesetzt."
