#!/bin/bash

# Sicherstellen, dass das Skript als root läuft
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Bitte als root oder mit sudo ausführen."
    exit 1
fi

# Globale Variablen laden
source $BASE_PATH/globals.conf

echo "🛠️  Konfiguriere iptables DNS-Chain..."

# Alte DNS-Kette entfernen (falls vorhanden)
iptables -t mangle -D OUTPUT -p udp --dport 53 -j MANGLE_DNS 2>/dev/null
iptables -t mangle -D OUTPUT -p tcp --dport 53 -j MANGLE_DNS 2>/dev/null
iptables -t mangle -F MANGLE_DNS 2>/dev/null
iptables -t mangle -X MANGLE_DNS 2>/dev/null

# Neue Kette erstellen
iptables -t mangle -N MANGLE_DNS

# Lokale DNS-Server (Unbound/DNSCrypt)
if [[ -n "$LOCAL_DNS_IP" ]]; then
    iptables -t mangle -A MANGLE_DNS -d "$LOCAL_DNS_IP" -j RETURN
    echo "➡️  DNS-Anfragen an lokalen Resolver ($LOCAL_DNS_IP) werden erlaubt."
fi

# DNS-Anfragen markieren, um sie über VPN zu routen
iptables -t mangle -A MANGLE_DNS -p udp --dport 53 -j MARK --set-mark "$DNS_ROUTE_MARK"
iptables -t mangle -A MANGLE_DNS -p tcp --dport 53 -j MARK --set-mark "$DNS_ROUTE_MARK"
echo "✳️  Markiere DNS-Traffic mit fwmark $DNS_ROUTE_MARK"

# Chain aktivieren
iptables -t mangle -A OUTPUT -p udp --dport 53 -j MANGLE_DNS
iptables -t mangle -A OUTPUT -p tcp --dport 53 -j MANGLE_DNS
echo "✅ DNS-Chain aktiviert."

# ip rule setzen
ip rule add fwmark "$DNS_ROUTE_MARK" table "$DNS_ROUTE_TABLE" priority 11000 2>/dev/null || true
echo "📘 ip rule für DNS-Mark ($DNS_ROUTE_MARK) → Tabelle $DNS_ROUTE_TABLE"

# Optional: Default-Route in DNS-Tabelle setzen (nur falls nicht vorhanden)
if ! ip route show table "$DNS_ROUTE_TABLE" | grep -q default; then
    ip route add default via "$VPN_GATEWAY_IP" dev "$VPN_INTERFACE" table "$DNS_ROUTE_TABLE"
    echo "➕ Default-Route zur DNS-Table ($DNS_ROUTE_TABLE) gesetzt über $VPN_GATEWAY_IP ($VPN_INTERFACE)"
fi

echo "✅ DNS-Chain-Konfiguration abgeschlossen."
