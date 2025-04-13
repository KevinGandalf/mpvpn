#!/bin/bash
LOG_FILE="/var/log/vpn_mtu_probe.log"
TARGETS=("8.8.8.8" "google.com")  # Test both IP and domain

source /opt/mpvpn/globals.sh

# Initialize log
echo -e "==== VPN MTU Probe Start ==== $(date)\n" | tee -a "$LOG_FILE"

for vpn in "${WGVPN_LIST[@]}"; do
    echo -e "\n🔍 Testing $vpn..." | tee -a "$LOG_FILE"
    
    # Skip if interface doesn't exist
    if ! ip link show dev "$vpn" >/dev/null 2>&1; then
        echo "⚠️ Interface $vpn not found - skipping" | tee -a "$LOG_FILE"
        continue
    fi

    # Test MTU range (1500 down to 1200)
    for mtu in {1500..1200..20}; do
        # Set temporary MTU
        sudo ip link set dev "$vpn" mtu $mtu 2>/dev/null
        payload=$((mtu - 28))  # MTU - IP+ICMP headers

        # Test both targets
        ALL_TARGETS_WORK=true
        for target in "${TARGETS[@]}"; do
            if ! ping -I "$vpn" -M do -s $payload -c 2 -W 1 "$target" >/dev/null 2>&1; then
                echo "❌ $vpn: MTU $mtu failed for $target" | tee -a "$LOG_FILE"
                ALL_TARGETS_WORK=false
                break
            fi
        done

        # If both targets work, set this as permanent MTU
        if $ALL_TARGETS_WORK; then
            echo "✅ $vpn: MTU $mtu ($payload payload) WORKS for all targets" | tee -a "$LOG_FILE"
            sudo ip link set dev "$vpn" mtu $mtu
            echo "➡️ Set $vpn MTU to $mtu (optimal)" | tee -a "$LOG_FILE"
            break
        fi

        # Fallback to minimum MTU
        if (( mtu <= 1200 )); then
            echo "🚨 $vpn: Reached minimum MTU (1200)" | tee -a "$LOG_FILE"
            sudo ip link set dev "$vpn" mtu 1200
            break
        fi
    done
done

# Final report
echo -e "\nFinal MTU Settings:" | tee -a "$LOG_FILE"
ip link | grep -E "$(IFS='|'; echo "${WGVPN_LIST[*]}")" | tee -a "$LOG_FILE"
echo -e "\n==== VPN MTU Probe Complete ==== $(date)" | tee -a "$LOG_FILE"

# TCP MSS Clamping (more aggressive)
#sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1260
#sudo iptables -t mangle -A OUTPUT -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1260

sudo sysctl -w net.ipv4.ip_no_pmtu_disc=1 >/dev/null 2>&1          # Disable PMTU discovery (problematic with VPNs)
sudo sysctl -w net.ipv4.tcp_mtu_probing = 0 >/dev/null 2>&1          # Disable automatic MTU probing
sudo sysctl -w net.ipv4.route.min_adv_mss = 1260 >/dev/null 2>&1     # Minimum advertised MSS
