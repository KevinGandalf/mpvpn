#!/bin/bash
set -e

# Configuration
TEST_IP="1.1.1.1"
PING_TIMEOUT=1
CHECK_INTERVAL=10
BOOT_GRACE_PERIOD=180  # in Sekunden (z. B. 180 = 3 Minuten)

# Load interfaces from globals.sh
source /opt/mpvpn/globals.sh
VPN_INTERFACES=("${WGVPN_LIST[@]}" "${OVPN_LIST[@]}")

# Calculate system uptime in seconds
get_uptime_seconds() {
    awk '{print int($1)}' /proc/uptime
}

# Check interface connectivity
check_interface() {
    local iface=$1
    if ip link show "$iface" up >/dev/null 2>&1; then
        if ping -I "$iface" -c 1 -W $PING_TIMEOUT $TEST_IP >/dev/null 2>&1; then
            echo "Interface $iface: UP and working"
            return 0
        else
            echo "Interface $iface: UP but no connectivity"
            return 1
        fi
    else
        echo "Interface $iface: DOWN"
        return 2
    fi
}

# Iptables killswitch functions
activate_iptables_killswitch() {
    echo "[!] Activating Killswitch (no VPNs up)"
    iptables -F
    iptables -P OUTPUT DROP
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
    iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT
    iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
    iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
}

deactivate_iptables_killswitch() {
    echo "[+] Deactivating Killswitch"
    iptables -P OUTPUT ACCEPT
    iptables -F
}

# Update routing
update_routing() {
    local active_interfaces=()
    local all_down=true

    for iface in "${VPN_INTERFACES[@]}"; do
        if check_interface "$iface"; then
            active_interfaces+=("$iface")
            all_down=false
        fi
    done

    local uptime=$(get_uptime_seconds)

    if [ "$all_down" = true ]; then
        if [ "$uptime" -lt "$BOOT_GRACE_PERIOD" ]; then
            echo "[boot grace] $uptime sec since boot – waiting for VPNs before activating killswitch."
        else
            activate_iptables_killswitch
        fi
    else
        echo "Active VPNs: ${active_interfaces[*]}"
        deactivate_iptables_killswitch

        local cmd="ip route replace default scope global"
        for iface in "${active_interfaces[@]}"; do
            cmd+=" nexthop dev $iface weight 1"
        done
        eval "$cmd"
        echo "Updated routing:"
        ip route show default
    fi
}

# Main loop
while true; do
    update_routing
    sleep $CHECK_INTERVAL
done
