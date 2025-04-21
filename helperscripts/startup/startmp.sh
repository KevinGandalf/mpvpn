#!/bin/bash
exec > >(tee -a /var/log/startmp.log) 2>&1
set -x

source /opt/mpvpn/globals.sh

STATUSFILE="/opt/mpvpn/helperscripts/startup/log.txt"

init_kernel_params() {
    echo "Initializing kernel parameters..." | tee -a "$STATUSFILE"
    
    sysctl -w net.ipv4.fib_multipath_hash_policy=1 >/dev/null 2>&1
    sysctl -w net.ipv4.fib_multipath_use_neigh=1 >/dev/null 2>&1
    
    sysctl -w net.netfilter.nf_conntrack_max=262144 >/dev/null 2>&1
    sysctl -w net.netfilter.nf_conntrack_tcp_timeout_established=3600 >/dev/null 2>&1
    
    sysctl -w net.ipv4.tcp_ecn=1 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_reordering=10 >/dev/null 2>&1
    
    echo "Kernel parameters initialized" >> "$STATUSFILE"
}


set_multipath_route() {
    echo "🔁 Erstelle Nexthop-Routen für Multipathing..."
    echo "==== $(date '+%Y-%m-%d %H:%M:%S') ====" > "$STATUSFILE"

    nexthops=()

    # WireGuard: nexthop dev <interface>
    for vpn in "${WGVPN_LIST[@]}"; do
        echo "➕ WG: $vpn → nexthop dev $vpn"
        nexthops+=("nexthop dev $vpn weight 1")
        echo "WG-Nexthop: dev $vpn weight 1" >> "$STATUSFILE"
    done

    # OpenVPN: nexthop via <gateway> dev <tunX> (nur wenn OpenVPN aktiviert ist)
    if [[ "$ENABLE_OVPN" == true ]]; then
        for vpn in "${OVPN_LIST[@]}"; do
            pid=$(pgrep -f "openvpn --config.*$vpn\.conf" | head -n1)

            if [[ -n "$pid" ]]; then
                tun_dev=$(ls -l /proc/$pid/fd 2>/dev/null | grep /dev/net/tun | awk -F'/' '{print $NF}' | head -n1)

                if [[ -z "$tun_dev" ]]; then
                    tun_dev=$(ip -o link show | awk -F': ' '/tun[0-9]+/ {print $2}' | grep -v lo | head -n1)
                fi

                gw_ip=$(ip route | grep "$tun_dev" | grep -oP 'via \K[0-9.]+' | head -n1)

                if [[ -n "$tun_dev" && -n "$gw_ip" ]]; then
                    echo "➕ OVPN: $vpn → via $gw_ip dev $tun_dev"
                    nexthops+=("nexthop via $gw_ip dev $tun_dev weight 1")
                    echo "OVPN-Nexthop: via $gw_ip dev $tun_dev weight 1" >> "$STATUSFILE"
                else
                    echo "⚠️  $vpn → Kein gültiges Gateway/Device – übersprungen."
                    echo "⚠️  $vpn → Kein gültiges Gateway/Device" >> "$STATUSFILE"
                fi
            else
                echo "⚠️  $vpn → Kein OpenVPN-Prozess aktiv – übersprungen."
                echo "⚠️  $vpn → Kein OpenVPN-Prozess aktiv" >> "$STATUSFILE"
            fi
        done
    else
        echo "🔒 OpenVPN ist deaktiviert – überspringe OpenVPN-Routen."
        echo "🔒 OpenVPN deaktiviert" >> "$STATUSFILE"
    fi

    # Alte Default-Route ggf. entfernen
    echo "🧹 Entferne alte Default-Route (falls vorhanden)..."
    sudo ip route del default 2>/dev/null
    echo "Alte Default-Route entfernt (falls vorhanden)" >> "$STATUSFILE"

    # Neue Route setzen
    if [[ ${#nexthops[@]} -gt 0 ]]; then
        # Befehl zusammenstellen
        ROUTE_CMD="sudo ip route add default"
        for nexthop in "${nexthops[@]}"; do
            ROUTE_CMD+=" $nexthop"
        done
        
        # Ausgabe des gesamten Befehls und Ausführung
        echo "✅ Setze neue default-Route mit ${#nexthops[@]} nexthops..."
        echo "Befehl zum Setzen der Route: $ROUTE_CMD" >> "$STATUSFILE"
        eval "$ROUTE_CMD"

        # Überprüfen, ob die Route erfolgreich gesetzt wurde
        if [[ $? -eq 0 ]]; then
            echo "✅ Neue Default-Route gesetzt" >> "$STATUSFILE"
        else
            echo "❌ Fehler beim Setzen der Default-Route" >> "$STATUSFILE"
        fi
    else
        echo "🚫 Keine gültigen nexthops gefunden – Route nicht gesetzt."
        echo "🚫 Keine gültigen nexthops gefunden" >> "$STATUSFILE"
    fi
}

# Starte die Funktion zum Setzen der Multipath-Route
init_kernel_params
set_multipath_route
