#!/bin/bash
set -euo pipefail

source $BASE_PATH/globals.conf

# === Configuration ===
IP_FILE="/opt/vpn_bypass_ips.txt"
IP_FILE_PREVIOUS="/opt/vpn_bypass_ips_previous.txt"
LOG_FILE="/var/log/vpn_routing.log"
TARGET_TABLE_NAME="streaming"
DEBUG=true  # Set to false for less output

# === Helper Functions ===
progress_bar() {
    local current=$1
    local total=$2
    local elapsed=$(( $(date +%s) - START_TIME ))
    local avg=$(( current > 0 ? elapsed / current : 0 ))
    local remaining=$(( total - current ))
    local eta=$(( avg * remaining ))

    local width=50
    local filled=$(( (current * width) / total ))
    local empty=$(( width - filled ))

    printf "\r["
    printf '%0.s#' $(seq 1 $filled)
    printf '%0.s-' $(seq 1 $empty)
    printf "] %d%% | ETA: %ds" $(( (current * 100) / total )) "$eta"
}

validate_ip() {
    local ip=$1
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && return 0 || return 1
}

# === Get Routing Table ID (MARK) ===
MARK=""
for entry in "${EXTRA_RT_TABLES[@]}"; do
    rt_id="${entry%% *}"
    rt_name="${entry#* }"
    [[ "$DEBUG" == true ]] && echo "DEBUG: Checking '$entry' → Name='$rt_name' ID=$rt_id"
    if [[ "$rt_name" == "$TARGET_TABLE_NAME" ]]; then
        MARK="$rt_id"
        break
    fi
done

if [[ -z "$MARK" ]]; then
    echo "❌ Routing table '$TARGET_TABLE_NAME' not found!" >&2
    exit 1
fi
[[ "$DEBUG" == true ]] && echo "✅ Using routing table $MARK ($TARGET_TABLE_NAME)"

# === Check DEFAULT_WANGW and DEFAULT_LANIF ===
if [[ -z "${DEFAULT_WANGW:-}" || -z "${DEFAULT_LANIF:-}" ]]; then
    echo "❌ DEFAULT_WANGW or DEFAULT_LANIF is not set!" >&2
    exit 1
fi

# === Load IP file ===
echo "$(date) - Loading IP addresses from GitHub..."
if ! curl --interface "$DEFAULT_LANIF" -s https://lou.h0rst.us/vpn_bypass.txt -o "$IP_FILE"; then
    echo "❌ Failed to download IP list!" >&2
    exit 1
fi

# Duplikate entfernen
sort -u "$IP_FILE" -o "$IP_FILE"
echo "✅ Duplikate entfernt aus $IP_FILE"

# === Load IPs into array ===
mapfile -t ip_list < <(grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$' "$IP_FILE")
TOTAL_IPS=${#ip_list[@]}
START_TIME=$(date +%s)

# === Track processed IPs to avoid duplicates ===
declare -A processed_ips

# === Set routes ===
for i in "${!ip_list[@]}"; do
    ip_cidr="${ip_list[$i]}"
    ip_only="${ip_cidr%%/*}"

    # Validate IP
    if ! validate_ip "$ip_only"; then
        [[ "$DEBUG" == true ]] && echo "⚠️ Invalid IP skipped: $ip_cidr" >&2
        continue
    fi

    # Skip if already processed
    if [[ -n "${processed_ips[$ip_only]:-}" ]]; then
        [[ "$DEBUG" == true ]] && echo "⚠️ Duplicate IP skipped: $ip_only" >&2
        continue
    fi
    processed_ips["$ip_only"]=1

    # Check if route already exists
    if ip route show table "$MARK" | grep -q "$ip_only"; then
        echo "$(date) - ⚠️ Route for $ip_only already exists in table $MARK. Skipping..." >> "$LOG_FILE"
        progress_bar "$((i+1))" "$TOTAL_IPS"
        continue
    fi

    # Add the route
    if ! sudo ip route add "$ip_cidr" via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" table "$MARK" 2>/dev/null; then
        echo "$(date) - ❌ Failed to add route for $ip_cidr" >> "$LOG_FILE"
    else
        echo "$(date) - ➕ Route: $ip_cidr via $DEFAULT_WANGW ($DEFAULT_LANIF) in table $MARK" >> "$LOG_FILE"
    fi

    progress_bar "$((i+1))" "$TOTAL_IPS"
done

# === Archive list ===
echo -e "\n$(date) - 💾 Saving current IP list as reference for next time..."
cp "$IP_FILE" "$IP_FILE_PREVIOUS"

echo "$(date) - ✅ Split routing update completed."
