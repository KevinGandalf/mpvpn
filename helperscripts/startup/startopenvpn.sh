#!/bin/sh

source /opt/mpvpn/globals.sh

start_all_ovpns() {
    # Überprüfen, ob OpenVPN aktiviert ist
    if [ "$ENABLE_OVPN" = true ]; then
        for vpn in "${OVPN_LIST[@]}"; do
            config_path="/etc/openvpn/${vpn}.conf"

            if [[ -f "$config_path" ]]; then
                echo "Starte $vpn..."
                openvpn --config "$config_path" --daemon

                # Warte 3 Sekunden für den Aufbau
                sleep 3

                # Suche nach dem TUN-Device des VPNs
                tun_dev=$(ip -o link show | awk -F': ' '/tun[0-9]+/ {print $2}' | head -n 1)

                if [[ -n "$tun_dev" ]]; then
                    echo "🔍 Prüfe Routing auf $tun_dev für $vpn..."

                    # Entferne Split-Default-Routen, wenn vorhanden
                    ip route | grep -q "0.0.0.0/1 via .* dev $tun_dev" && sudo ip route del 0.0.0.0/1 dev "$tun_dev"
                    ip route | grep -q "128.0.0.0/1 via .* dev $tun_dev" && sudo ip route del 128.0.0.0/1 dev "$tun_dev"

                    echo "✔️  Routen auf $tun_dev bereinigt (falls vorhanden)."
                else
                    echo "⚠️  Kein TUN-Device gefunden nach Start von $vpn – eventuell gescheitert?"
                fi
            else
                echo "⚠️  Konfiguration für $vpn nicht gefunden: $config_path – überspringe."
            fi
        done
    else
        echo "OpenVPN ist deaktiviert. Keine VPN-Instanzen werden gestartet."
    fi
}
