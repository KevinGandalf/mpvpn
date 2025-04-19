#!/bin/bash
exec > >(tee -a /var/log/startmp.log) 2>&1
set -x

source /opt/mpvpn/globals.sh

STATUSFILE="/opt/mpvpn/helperscripts/startup/log.txt"

# Debugging: Kernel Parameter Initialisierung
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

# Debugging: Schnittstellenoptimierung
optimize_interfaces() {
    local iface="$1"
    echo "Optimizing interface $iface..." | tee -a "$STATUSFILE"
    
    ip link set dev "$iface" multipath on 2>/dev/null
    tc qdisc replace dev "$iface" root fq_codel 2>/dev/null

    ethtool -K "$iface" rx-udp-gro-forwarding on 2>/dev/null
    ethtool -K "$iface" gro on 2>/dev/null
    ethtool -K "$iface" gso on 2>/dev/null

    ip link set dev "$iface" mtu 1420 2>/dev/null

    echo "Interface $iface optimized" >> "$STATUSFILE"
}

# Debugging: Multipath-Route setzen
set_multipath_route() {
    echo "Creating nexthop routes for multipathing..." | tee -a "$STATUSFILE"
    echo "==== $(date '+%Y-%m-%d %H:%M:%S') ====" >> "$STATUSFILE"

    init_kernel_params
    
    declare -a nexthops
    declare -a working_nexthops
    declare -A used_ifaces

    # Füllen von active_wg_interfaces mit den Inhalten von WGVPN_LIST
    active_wg_interfaces=("${WGVPN_LIST[@]}")

    if [[ ${#active_wg_interfaces[@]} -gt 0 ]]; then
        for wg_iface in "${active_wg_interfaces[@]}"; do
            if [[ -n "$wg_iface" && -e "/sys/class/net/$wg_iface" ]]; then
                echo "WG: $wg_iface → nexthop dev $wg_iface" | tee -a "$STATUSFILE"
                nexthops+=("nexthop dev $wg_iface weight 1")
                used_ifaces["$wg_iface"]=1
                optimize_interfaces "$wg_iface"
            fi
        done
    else
        echo "No active WireGuard interfaces found!" | tee -a "$STATUSFILE"
    fi

    # OpenVPN Fallback von globals.sh
    if [[ "$ENABLE_OVPN" == true ]]; then
        for vpn in "${OVPN_LIST[@]}"; do
            pid=$(pgrep -f "openvpn --config.*$vpn\.conf" | head -n1)
            if [[ -n "$pid" ]]; then
                tun_dev=$(ls -l /proc/$pid/fd 2>/dev/null | grep /dev/net/tun | awk -F'/' '{print $NF}' | head -n1)
                [[ -z "$tun_dev" ]] && tun_dev=$(ip -o link show | awk -F': ' '/tun[0-9]+/ {print $2}' | grep -v lo | head -n1)
                gw_ip=$(ip route | grep "$tun_dev" | grep -oP 'via \K[0-9.]+' | head -n1)

                if [[ -n "$tun_dev" && -n "$gw_ip" ]]; then
                    echo "OVPN: $vpn → via $gw_ip dev $tun_dev" | tee -a "$STATUSFILE"
                    nexthops+=("nexthop via $gw_ip dev $tun_dev weight 1")
                    used_ifaces["$tun_dev"]=1
                    optimize_interfaces "$tun_dev"
                else
                    echo "OVPN: $vpn → No valid gateway/device" | tee -a "$STATUSFILE"
                fi
            else
                echo "OVPN: $vpn → No running process" | tee -a "$STATUSFILE"
            fi
        done
    fi

    # Multipath-Route setzen
    if [[ ${#nexthops[@]} -gt 0 ]]; then
        echo "Setting initial multipath route with ${#nexthops[@]} interfaces" | tee -a "$STATUSFILE"
        ip route replace default scope global $(printf "%s " "${nexthops[@]}") || {
            echo "Failed to set initial multipath route" | tee -a "$STATUSFILE"
            return 1
        }

        echo "Verifying interface connectivity..." | tee -a "$STATUSFILE"
        for nh in "${nexthops[@]}"; do
            iface=$(echo "$nh" | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}')
            echo "Testing $iface..." | tee -a "$STATUSFILE"
            
            if curl --interface "$iface" --max-time 4 --silent https://1.1.1.1 >/dev/null; then
                echo "$iface is working" | tee -a "$STATUSFILE"
                working_nexthops+=("$nh")
            else
                echo "$iface failed connectivity test" | tee -a "$STATUSFILE"
            fi
        done

        if [[ ${#working_nexthops[@]} -gt 0 ]]; then
            echo "Updating route with ${#working_nexthops[@]} working interfaces" | tee -a "$STATUSFILE"
            ip route change default scope global $(printf "%s " "${working_nexthops[@]}") || {
                echo "Failed to update multipath route" | tee -a "$STATUSFILE"
                return 1
            }
        else
            echo "No working VPN interfaces found!" | tee -a "$STATUSFILE"
            return 1
        fi
    else
        echo "No VPN interfaces configured!" | tee -a "$STATUSFILE"
        return 1
    fi
}

# Hauptausführung
set_multipath_route

# Endgültiger Statusbericht
echo -e "\nFinal Network Status:" | tee -a "$STATUSFILE"
echo "=====================" | tee -a "$STATUSFILE"
ip route show default | tee -a "$STATUSFILE"

echo -e "\nOptimized Interfaces:" | tee -a "$STATUSFILE"
for iface in "${!used_ifaces[@]}"; do
    ip link show dev "$iface" 2>/dev/null | head -1 | tee -a "$STATUSFILE"
    tc qdisc show dev "$iface" 2>/dev/null | tee -a "$STATUSFILE"
done
