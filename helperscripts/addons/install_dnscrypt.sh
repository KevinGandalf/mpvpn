#!/bin/bash

# Überprüfe, ob das Skript als Root ausgeführt wird
if [[ $EUID -ne 0 ]]; then
    echo "Dieses Skript muss als Root ausgeführt werden." 
    exit 1
fi

# Lade globale Variablen
source /opt/mpvpn/globals.sh

# Überprüfe, ob DNSCrypt aktiviert werden soll
if [[ "$ENABLE_DNSCRYPT" != "true" ]]; then
    echo "DNSCrypt ist nicht aktiviert. Abbruch."
    exit 0
fi

# Überprüfe, ob DNSCrypt automatisch starten soll
if [[ "$DNSCRYPT_AUTOSTART" != "true" ]]; then
    echo "DNSCrypt wird nicht automatisch gestartet. Abbruch."
    # An dieser Stelle nicht abbrechen, sondern nur keine Systemstart-Aktion durchführen
fi

# Installiere DNSCrypt (abhängig von der Distribution)
if [ -f /etc/almalinux-release ]; then
    # AlmaLinux
    echo "Installiere DNSCrypt auf AlmaLinux..."
    dnf install -y epel-release
    dnf install -y dnscrypt-proxy
elif [ -f /etc/rocky-release ]; then
    # Rocky Linux
    echo "Installiere DNSCrypt auf Rocky Linux..."
    dnf install -y epel-release
    dnf install -y dnscrypt-proxy
elif [ -f /etc/centos-release ]; then
    # CentOS
    echo "Installiere DNSCrypt auf CentOS..."
    dnf install -y epel-release
    dnf install -y dnscrypt-proxy
elif [ -f /etc/redhat-release ]; then
    # RHEL
    echo "Installiere DNSCrypt auf RHEL..."
    dnf install -y epel-release
    dnf install -y dnscrypt-proxy
elif [ -f /etc/debian_version ] || [ -f /etc/raspbian-release ]; then
    # Debian/Ubuntu/Raspbian
    if [ -f /etc/raspbian-release ]; then
        echo "Raspbian erkannt. Installiere DNSCrypt..."
    else
        echo "Debian oder Ubuntu erkannt. Installiere DNSCrypt..."
    fi
    apt update
    apt install -y dnscrypt-proxy
else
    echo "Unbekannte Distribution. Abbruch."
    exit 1
fi

# DNSCrypt-Konfiguration
echo "Konfiguriere DNSCrypt..."

# Erstelle die DNSCrypt-Konfigurationsdatei
dnscrypt_config="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"

# Hole die Variablen aus der globals.sh
server_names="${DNSCRYPT_SERVER_NAMES[@]}"
require_dnssec="$DNSCRYPT_REQUIRE_DNSSEC"
require_nolog="$DNSCRYPT_REQUIRE_NOLOG"
require_nofilter="$DNSCRYPT_REQUIRE_NOFILTER"

# Schreibe die Konfiguration in die Datei
echo "server_names = [\"$server_names\"]" > "$dnscrypt_config"
echo "require_dnssec = $require_dnssec" >> "$dnscrypt_config"
echo "require_nolog = $require_nolog" >> "$dnscrypt_config"
echo "require_nofilter = $require_nofilter" >> "$dnscrypt_config"

# Weitere DNS-Server-Konfigurationen (kann nach Bedarf angepasst werden)
echo "forwarding_rules = [\"1.1.1.1\", \"8.8.8.8\", \"100.64.0.7\", \"10.0.254.24\"]" >> "$dnscrypt_config"

# Überprüfe, ob die Konfigurationsdatei erfolgreich erstellt wurde
if [ -f "$dnscrypt_config" ]; then
    echo "DNSCrypt-Konfiguration erfolgreich gespeichert: $dnscrypt_config"
else
    echo "Fehler: Konfigurationsdatei konnte nicht erstellt werden."
    exit 1
fi

# Überprüfe, ob DNSCrypt automatisch gestartet werden soll
if [[ "$DNSCRYPT_AUTOSTART" == "true" ]]; then
    echo "Starte DNSCrypt..."
    systemctl enable dnscrypt-proxy
    systemctl start dnscrypt-proxy

    # Überprüfe, ob der Dienst läuft
    if systemctl is-active --quiet dnscrypt-proxy; then
        echo "DNSCrypt wurde erfolgreich installiert und läuft."
    else
        echo "Fehler: DNSCrypt konnte nicht gestartet werden."
        exit 1
    fi
else
    echo "DNSCrypt wird nicht automatisch gestartet, da DNSCRYPT_AUTOSTART=false gesetzt ist."
fi

# Fertigstellung
echo "Installation und Konfiguration von DNSCrypt abgeschlossen."
