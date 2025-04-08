#!/bin/bash

# Lade globale Variablen aus der globals.sh
source /path/to/globals.sh

# Hole die Routing-Tabelle für SMTP aus der EXTRA_RT_TABLES
for table in "${EXTRA_RT_TABLES[@]}"; do
    # Extrahiere Table-ID und Name (z.B. 200 smtp)
    table_id=$(echo "$table" | awk '{print $1}')
    table_name=$(echo "$table" | awk '{print $2}')
    
    if [[ "$table_name" == "smtp" ]]; then
        echo "Setze Ausnahmen für SMTP auf Table $table_id..."
        
        # Füge eine Default-Route über das angegebene LAN-Interface hinzu (lesen aus DEFAULT_LANIF)
        ip route add default via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" table "$table_id"
        
        # Füge fwmark Regel für diese Tabelle hinzu
        ip rule add fwmark "$table_id" table "$table_id"
        
        # Füge Regel für alle IP-Adressen hinzu, um den main lookup beizubehalten
        ip rule add from all lookup main
    fi
done
