#!/bin/bash

echo "🔥 Lösche alte Conntrack-Einträge..."

# Entferne alle TCP-Verbindungen mit geschlossenen oder inaktiven Status
conntrack -D -p tcp --state TIME_WAIT
conntrack -D -p tcp --state CLOSE_WAIT
conntrack -D -p tcp --state FIN_WAIT

# Optional: Entferne alte UDP-Verbindungen
conntrack -D -p udp

echo "🔥 Bereinige alte iptables PREROUTING-Regeln..."

# Lösche alle PREROUTING-Regeln in der mangle-Tabelle, falls iptables genutzt wird
if command -v iptables &> /dev/null; then
    iptables -t mangle -F PREROUTING
fi
