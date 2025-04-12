#!/bin/bash
exec > >(tee -a /var/log/startmp.log) 2>&1
set -x

source /opt/mpvpn/globals.sh

STATUSFILE="/opt/mpvpn/helperscripts/startup/log.txt"

init_kernel_params() {
    echo "⚙️ Initializing kernel parameters..." | tee -a "$STATUSFILE"
    
    # ECMP and routing settings
    sudo sysctl -w net.ipv4.fib_multipath_hash_policy=1 >/dev/null 2>&1
    sudo sysctl -w net.ipv4.fib_multipath_use_neigh=1 >/dev/null 2>&1
    
    # Connection tracking
    sudo sysctl -w net.netfilter.nf_conntrack_max=262144 >/dev/null 2>&1
    sudo sysctl -w net.netfilter.nf_conntrack_tcp_timeout_established=3600 >/dev/null 2>&1
    
    # TCP stack optimizations
    sudo sysctl -w net.ipv4.tcp_ecn=1 >/dev/null 2>&1
    sudo sysctl -w net.ipv4.tcp_reordering=10 >/dev/null 2>&1
    
    echo "Kernel parameters initialized" >> "$STATUSFILE"
}

optimize_interfaces() {
    local iface=$1
    echo "🔧 Optimizing interface $iface..." | tee -a "$STATUSFILE"
    
    # Enable multipath support
    sudo ip link set dev "$iface" multipath on 2>/dev/null
    
    # Configure fq_codel queue discipline
    sudo tc qdisc replace dev "$iface" root fq_codel 2>/dev/null
    
    # Enable GRO/GSO for better performance
    sudo ethtool -K "$iface" rx-udp-gro-forwarding on 2>/dev/null
    sudo ethtool -K "$iface" gro on 2>/dev/null
    sudo ethtool -K "$iface" gso on 2>/dev/null
    
    # Set conservative MTU
    sudo ip link set dev "$iface" mtu 1420 2>/dev/null
    
    echo "Interface $iface optimized" >> "$STATUSFILE"
}

set_multipath_route() {
    echo "🔁 Creating nexthop routes for multipathing..." | tee -a "$STATUSFILE"
    echo "==== $(date '+%Y-%m-%d %H:%M:%S') ====" >> "$STATUSFILE"

    init_kernel_params
    
    declare -A original_nexthops
    nexthops=()

    # WireGuard interfaces
    for vpn in "${WGVPN_LIST[@]}"; do
        echo "➕ WG: $vpn → nexthop dev $vpn" | tee -a "$STATUSFILE"
        nexthops+=("nexthop dev $vpn weight 1")
        original_nexthops["dev $vpn"]=1
        optimize_interfaces "$vpn"
    done

    # OpenVPN interfaces
    if [[ "$ENABLE_OVPN" == true ]]; then
        for vpn in "${OVPN_LIST[@]}"; do
            pid=$(pgrep -f "openvpn --config.*$vpn\.conf" | head -n1)
            if [[ -n "$pid" ]]; then
                tun_dev=$(ls -l /proc/$pid/fd 2>/dev/null | grep /dev/net/tun | awk -F'/' '{print $NF}' | head -n1)
                [[ -z "$tun_dev" ]] && tun_dev=$(ip -o link show | awk -F': ' '/tun[0-9]+/ {print $2}' | grep -v lo | head -n1)
                gw_ip=$(ip route | grep "$tun_dev" | grep -oP 'via \K[0-9.]+' | head -n1)

                if [[ -n "$tun_dev" && -n "$gw_ip" ]]; then
                    echo "➕ OVPN: $vpn → via $gw_ip dev $tun_dev" | tee -a "$STATUSFILE"
                    nexthops+=("nexthop via $gw_ip dev $tun_dev weight 1")
                    original_nexthops["dev $tun_dev"]=1
                    optimize_interfaces "$tun_dev"
                else
                    echo "⚠️ OVPN: $vpn → No valid gateway/device" | tee -a "$STATUSFILE"
                fi
            else
                echo "⚠️ OVPN: $vpn → No running process" | tee -a "$STATUSFILE"
            fi
        done
    fi

    # Set initial multipath route
    if [[ ${#nexthops[@]} -gt 0 ]]; then
        echo "🌐 Setting initial multipath route with ${#nexthops[@]} interfaces" | tee -a "$STATUSFILE"
        sudo ip route replace default scope global $(printf "%s " "${nexthops[@]}") || {
            echo "❌ Failed to set initial multipath route" | tee -a "$STATUSFILE"
            return 1
        }

        # Verify connectivity through each interface
        echo "🔍 Verifying interface connectivity..." | tee -a "$STATUSFILE"
        working_nexthops=()
        for nexthop in "${nexthops[@]}"; do
            iface=$(echo "$nexthop" | awk '{print $NF}')
            echo "Testing $iface..." | tee -a "$STATUSFILE"
            
            if curl --interface "$iface" --max-time 3 --silent https://1.1.1.1 >/dev/null; then
                echo "✅ $iface is working" | tee -a "$STATUSFILE"
                working_nexthops+=("$nexthop")
            else
                echo "⚠️ $iface failed connectivity test" | tee -a "$STATUSFILE"
            fi
        done

        # Update route with only working interfaces
        if [[ ${#working_nexthops[@]} -gt 0 ]]; then
            echo "🔄 Updating route with ${#working_nexthops[@]} working interfaces" | tee -a "$STATUSFILE"
            sudo ip route change default scope global $(printf "%s " "${working_nexthops[@]}") || {
                echo "❌ Failed to update multipath route" | tee -a "$STATUSFILE"
                return 1
            }
        else
            echo "🚫 No working VPN interfaces found!" | tee -a "$STATUSFILE"
            return 1
        fi
    else
        echo "🚫 No VPN interfaces configured!" | tee -a "$STATUSFILE"
        return 1
    fi
}

# Main execution
set_multipath_route

# Final status
echo -e "\nFinal Network Status:" | tee -a "$STATUSFILE"
echo "=====================" | tee -a "$STATUSFILE"
ip route show default | tee -a "$STATUSFILE"
echo -e "\nOptimized Interfaces:" | tee -a "$STATUSFILE"
for iface in "${WGVPN_LIST[@]}" "${OVPN_LIST[@]}"; do
    ip link show dev "$iface" 2>/dev/null | head -1 | tee -a "$STATUSFILE"
    tc qdisc show dev "$iface" 2>/dev/null | tee -a "$STATUSFILE"
done
