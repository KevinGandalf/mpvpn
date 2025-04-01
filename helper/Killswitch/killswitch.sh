#!/bin/bash

# Liste der VPN-Interfaces
VPN_INTERFACES=("mullvad1" "mullvad2" "azirevpn1" "azirevpn2" "nordvpn" "suefahark" "ivpn" "pia" "tun0" "tun1")

# IP-Adresse für den Connectivity-Test (Google DNS oder dein VPN-Anbieter)
TEST_IP="8.8.8.8"

# Sicherstellen, dass die KILLSWITCH-Kette existiert
initialize_iptables() {
    iptables -N KILLSWITCH 2>/dev/null || iptables -F KILLSWITCH
    iptables -D OUTPUT -j KILLSWITCH 2>/dev/null
    iptables -A OUTPUT -j KILLSWITCH
}

# Funktion zur Überprüfung der VPN-Konnektivität
check_vpns() {
    for vpn in "${VPN_INTERFACES[@]}"; do
        if ip link show "$vpn" up &>/dev/null; then
            # Prüfen, ob das Interface tatsächlich Traffic leiten kann (max. 1 Sekunde Timeout)
            if ping -I "$vpn" -c 1 -W 1 "$TEST_IP" &>/dev/null; then
                echo "VPN $vpn ist aktiv und leitet Traffic."
                return 0  # Mindestens ein VPN ist aktiv und funktionstüchtig
            else
                echo "VPN $vpn ist UP, aber kein Traffic möglich."
            fi
        fi
    done
    return 1  # Kein funktionierendes VPN vorhanden
}

# Kill-Switch Regel setzen
apply_killswitch() {
    initialize_iptables  # Sicherstellen, dass die Kette existiert

    if check_vpns; then
        # Mindestens ein VPN funktioniert → Kill-Switch deaktivieren
        echo "Mindestens ein VPN aktiv – Kill-Switch deaktiviert."
        iptables -F KILLSWITCH
        iptables -A KILLSWITCH -o lo -j RETURN
        iptables -A KILLSWITCH -p tcp --dport 22 -j RETURN  # SSH erlauben
        iptables -A KILLSWITCH -d 192.168.0.0/16 -j RETURN  # Lokales Netzwerk erlauben
        iptables -A KILLSWITCH -d 10.0.0.0/8 -j RETURN  # Private Netzwerke erlauben
        iptables -A KILLSWITCH -d 172.16.0.0/12 -j RETURN  # Private Netzwerke erlauben

        for vpn in "${VPN_INTERFACES[@]}"; do
            iptables -A KILLSWITCH -o "$vpn" -j RETURN
        done
    else
        # Kein VPN aktiv oder funktionsfähig → ALLES blockieren (außer SSH & LAN)
        echo "Alle VPNs sind DOWN – Kill-Switch AKTIV!"
        iptables -F KILLSWITCH
        iptables -A KILLSWITCH -o lo -j RETURN
        iptables -A KILLSWITCH -p tcp --dport 22 -j RETURN  # SSH erlauben
        iptables -A KILLSWITCH -d 192.168.0.0/16 -j RETURN  # Lokales Netzwerk erlauben
        iptables -A KILLSWITCH -d 10.0.0.0/8 -j RETURN  # Private Netzwerke erlauben
        iptables -A KILLSWITCH -d 172.16.0.0/12 -j RETURN  # Private Netzwerke erlauben
        iptables -A KILLSWITCH -j DROP  # ALLES andere blockieren
    fi
}

# Endlosschleife mit Überprüfung alle 10 Sekunden
while true; do
    apply_killswitch
    sleep 10
done
