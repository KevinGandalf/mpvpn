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
            
            # Calculate and set MSS for this interface (MTU - 40 = MSS)
            MSS=$((mtu - 40))  # 20 (IP) + 20 (TCP) overhead
            echo "🔧 Setting TCP MSS to $MSS for $vpn traffic" | tee -a "$LOG_FILE"
            
            # Remove old MSS rules if they exist
            sudo iptables -t mangle -D OUTPUT -o "$vpn" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "$MSS" 2>/dev/null
            sudo iptables -t mangle -D FORWARD -o "$vpn" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "$MSS" 2>/dev/null
            
            # Apply new MSS rules (local and forwarded traffic)
            sudo iptables -t mangle -A OUTPUT -o "$vpn" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "$MSS"
            sudo iptables -t mangle -A FORWARD -o "$vpn" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "$MSS"
            
            break
        fi

        # Fallback to minimum MTU
        if (( mtu <= 1200 )); then
            echo "🚨 $vpn: Reached minimum MTU (1200)" | tee -a "$LOG_FILE"
            sudo ip link set dev "$vpn" mtu 1200
            
            # Set conservative MSS for fallback
            MSS=1160  # 1200 - 40
            echo "🔧 Setting fallback TCP MSS to $MSS for $vpn" | tee -a "$LOG_FILE"
            sudo iptables -t mangle -A OUTPUT -o "$vpn" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "$MSS"
            sudo iptables -t mangle -A FORWARD -o "$vpn" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "$MSS"
            break
        fi
    done
done

# Final report
echo -e "\nFinal MTU Settings:" | tee -a "$LOG_FILE"
ip link | grep -E "$(IFS='|'; echo "${WGVPN_LIST[*]}")" | tee -a "$LOG_FILE"

echo -e "\nActive TCP MSS Rules:" | tee -a "$LOG_FILE"
sudo iptables -t mangle -L OUTPUT -v -n | grep TCPMSS | tee -a "$LOG_FILE"
sudo iptables -t mangle -L FORWARD -v -n | grep TCPMSS | tee -a "$LOG_FILE"

# Kernel settings (optimized for VPNs)
sudo sysctl -w net.ipv4.ip_no_pmtu_disc=1 >/dev/null 2>&1          # Disable PMTU discovery
sudo sysctl -w net.ipv4.tcp_mtu_probing=0 >/dev/null 2>&1          # Disable automatic MTU probing
sudo sysctl -w net.ipv4.route.min_adv_mss=1260 >/dev/null 2>&1     # Minimum advertised MSS

echo -e "\n==== VPN MTU Probe Complete ==== $(date)" | tee -a "$LOG_FILE"
