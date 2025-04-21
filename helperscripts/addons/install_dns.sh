#!/bin/bash

# Sicherstellen, dass das Skript als root läuft
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Bitte das Skript als root oder mit sudo ausführen."
    exit 1
fi

# globals.sh laden
source /opt/mpvpn/globals.sh

echo "🚦 Starte Installation des DNS-Stacks..."

# UNBOUND installieren, wenn aktiviert
if [[ "$ENABLE_UNBOUND" == "true" ]]; then
    echo "📦 Installiere Unbound..."
    bash /opt/mpvpn/helperscripts/addons/install_unbound.sh
else
    echo "🔕 Unbound ist deaktiviert (ENABLE_UNBOUND=false)"
fi

# DNSCRYPT installieren, wenn aktiviert
if [[ "$ENABLE_DNSCRYPT" == "true" ]]; then
    echo "📦 Installiere DNSCrypt..."
    bash /opt/mpvpn/helperscripts/addons/install_dnscrypt.sh
else
    echo "🔕 DNSCrypt ist deaktiviert (ENABLE_DNSCRYPT=false)"
fi

# Wenn BEIDE aktiviert sind, DNS-Kette konfigurieren
if [[ "$ENABLE_UNBOUND" == "true" && "$ENABLE_DNSCRYPT" == "true" ]]; then
    echo "🔗 Konfiguriere DNS-Verkettung (Unbound → DNSCrypt)..."
    bash /opt/mpvpn/helperscripts/addons/configure_dns_chain.sh
else
    echo "ℹ️  DNS-Kette wird nicht konfiguriert – mindestens ein Dienst ist deaktiviert."
fi

echo "✅ DNS-Stack-Installation abgeschlossen."
