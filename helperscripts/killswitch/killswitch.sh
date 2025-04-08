#!/bin/bash

# Lade die globale Konfiguration
source /opt/mpvpn/globals.sh

# Sicherstellen, dass die KILLSWITCH-Kette existiert
initialize_iptables() {
    iptables -N KILLSWITCH 2>/dev/null || iptables -F KILLSWITCH
    iptables -D OUTPUT -j KILLSWITCH 2>/dev/null
    iptables -A OUTPUT -j KILLSWITCH
}

# Funktion zum Auslesen der Endpunkte aus WireGuard und OpenVPN Konfigurationsdateien
get_vpn_endpoints() {
    local endpoints=()
    local wg_interfaces=()

    # Durchlaufe alle WireGuard-Konfigurationsdateien und extrahiere Endpunkte und Interfaces
    for conf_file in "$WG_CONF_DIR"/*.conf; do
        while read -r line; do
            if [[ $line =~ Endpoint\ =\ ([^:]+) ]]; then
                endpoints+=("${BASH_REMATCH[1]}")
            elif [[ $line =~ Interface\ =\ ([^ ]+) ]]; then
                wg_interfaces+=("${BASH_REMATCH[1]}")
            fi
        done < "$conf_file"
    done

    # Wenn OpenVPN aktiviert ist, füge auch OpenVPN-Remote-IPs hinzu
    if [ "$ENABLE_OVPN" = true ]; then
        for conf_file in "$OVPN_CONF_DIR"/*.conf; do
            while read -r line; do
                if [[ $line =~ remote\ ([^ ]+) ]]; then
                    endpoints+=("${BASH_REMATCH[1]}")
                fi
            done < "$conf_file"
        done
    fi

    # Wenn keine Endpunkte gefunden wurden, Fehlermeldung ausgeben
    if [ ${#endpoints[@]} -eq 0 ]; then
        echo "WARNUNG: Keine VPN-Endpunkte gefunden!"
    fi

    echo "${endpoints[@]}"
    echo "${wg_interfaces[@]}"
}

# Funktion zur Überprüfung der VPN-Konnektivität
check_vpns() {
    local endpoints
    local wg_interfaces
    endpoints=$(get_vpn_endpoints)
    wg_interfaces=$(echo "$endpoints" | tail -n +2) # Der erste Teil sind Endpunkte, der Rest sind Interfaces

    local valid_vpn=0

    # Prüfen der WireGuard-Endpunkte
    for interface in $wg_interfaces; do
        if ip link show "$interface" up &>/dev/null; then
            echo "Überprüfe WireGuard Interface: $interface"
            for ip in $endpoints; do
                echo "Pinge über $interface zu Endpunkt $ip"
                if ping -I "$interface" -c 1 -W 1 "$ip" &>/dev/null; then
                    echo "VPN-Endpunkt $ip ist erreichbar über $interface."
                    valid_vpn=1
                    break 2  # Wenn ein VPN-Endpunkt erfolgreich erreichbar ist, breche ab
                else
                    echo "VPN-Endpunkt $ip NICHT erreichbar über $interface."
                fi
            done
        fi
    done

    # Wenn OpenVPN aktiviert ist, prüfe auch OpenVPN-Remote-IPs
    if [ "$ENABLE_OVPN" = true ]; then
        for ip in $endpoints; do
            echo "Pinge zu OpenVPN-Remote-Server $ip"
            if ping -I "$interface" -c 1 -W 1 "$ip" &>/dev/null; then
                echo "OpenVPN-Server $ip ist erreichbar."
                valid_vpn=1
                break  # Bei erfolgreichem Ping, breche ab
            else
                echo "OpenVPN-Server $ip NICHT erreichbar."
            fi
        done
    fi

    return $valid_vpn
}

# Kill-Switch Regel setzen
apply_killswitch() {
    initialize_iptables  # Sicherstellen, dass die Kette existiert

    # Holen der Endpunkte aus den Konfigurationsdateien
    local endpoints
    endpoints=$(get_vpn_endpoints)

    # Wenn kein VPN aktiv ist, den Kill-Switch sofort aktivieren
    if ! check_vpns; then
        # Kein VPN aktiv oder funktionsfähig → ALLES blockieren (außer SSH & LAN)
        echo "Alle VPNs sind DOWN – Kill-Switch AKTIV!"
        iptables -F KILLSWITCH
        iptables -A KILLSWITCH -o lo -j RETURN
        iptables -A KILLSWITCH -p tcp --dport 22 -j RETURN  # SSH erlauben
        iptables -A KILLSWITCH -d 192.168.0.0/16 -j RETURN  # Lokales Netzwerk erlauben
        iptables -A KILLSWITCH -d 10.0.0.0/8 -j RETURN  # Private Netzwerke erlauben
        iptables -A KILLSWITCH -d 172.16.0.0/12 -j RETURN  # Private Netzwerke erlauben

        # Alle ausgehenden Verbindungen blockieren
        iptables -A KILLSWITCH -j DROP

        # Erlaube Verbindungen zu den Endpunkten
        for ip in $endpoints; do
            iptables -A OUTPUT -d "$ip" -j RETURN
            iptables -A OUTPUT -s "$ip" -j RETURN
        done
    else
        # Mindestens ein VPN-Endpunkt funktioniert → Kill-Switch deaktivieren
        echo "Mindestens ein VPN-Endpunkt aktiv – Kill-Switch deaktiviert."
        iptables -F KILLSWITCH
        iptables -A KILLSWITCH -o lo -j RETURN
        iptables -A KILLSWITCH -p tcp --dport 22 -j RETURN  # SSH erlauben
        iptables -A KILLSWITCH -d 192.168.0.0/16 -j RETURN  # Lokales Netzwerk erlauben
        iptables -A KILLSWITCH -d 10.0.0.0/8 -j RETURN  # Private Netzwerke erlauben
        iptables -A KILLSWITCH -d 172.16.0.0/12 -j RETURN  # Private Netzwerke erlauben

        # Durchlaufe alle extrahierten Endpunkte und erlaube Verbindungen
        for ip in $endpoints; do
            iptables -A KILLSWITCH -d "$ip" -j RETURN
            iptables -A KILLSWITCH -s "$ip" -j RETURN
        done

        # Alle anderen Verbindungen blockieren
        iptables -A KILLSWITCH -j DROP
    fi
}

# Endlosschleife mit Überprüfung alle 10 Sekunden
while true; do
    apply_killswitch
    sleep 10
done
