#!/bin/bash

source $BASE_PATH/globals.conf

# Bereinige Routing Tables (mit Switch für OpenVPN)
echo "🧹 Räume /etc/iproute2/rt_tables auf..."

# Wenn OpenVPN aktiviert ist, dann OVPN_LIST in das All-VPN-Array einfügen
if [ "$ENABLE_OVPN" = true ]; then
    ALL_VPN_ENTRIES=("${WGVPN_LIST[@]}" "${OVPN_LIST[@]}" "clear" "smtp")
else
    # OpenVPN deaktiviert, also ohne OVPN_LIST
    ALL_VPN_ENTRIES=("${WGVPN_LIST[@]}" "clear" "smtp")
fi

# Entferne Einträge aus rt_tables
for entry in "${ALL_VPN_ENTRIES[@]}"; do
    sed -i "/^[0-9]\+\s\+$entry$/d" /etc/iproute2/rt_tables
done

echo "✅ Einträge wurden entfernt."
