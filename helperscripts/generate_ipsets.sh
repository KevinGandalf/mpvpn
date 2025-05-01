#!/bin/bash

source /opt/mpvpn/globals.sh

# Funktion zum Überprüfen des Betriebssystems
get_os_type() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Funktion zum Installieren von ipset je nach Betriebssystem
install_ipset() {
    OS=$(get_os_type)

    case "$OS" in
        debian|ubuntu|raspbian)
            if ! command -v ipset &>/dev/null; then
                echo "===> ipset nicht gefunden. Installiere auf $OS..."
                apt update && apt install -y ipset
            else
                echo "===> ipset ist bereits installiert."
            fi
            ;;
        alma|rocky|rhel)
            if ! command -v ipset &>/dev/null; then
                echo "===> ipset nicht gefunden. Installiere auf $OS..."
                dnf install -y ipset
            else
                echo "===> ipset ist bereits installiert."
            fi
            ;;
        alpine)
            if ! command -v ipset &>/dev/null; then
                echo "===> ipset nicht gefunden. Installiere auf Alpine..."
                apk add ipset
            else
                echo "===> ipset ist bereits installiert."
            fi
            ;;
        *)
            echo "===> Betriebssystem $OS nicht erkannt. Bitte manuell installieren."
            ;;
    esac
}

# Installiere ipset
install_ipset

RESET=false
APPLY_RULES=false

# Argumente verarbeiten
while [[ $# -gt 0 ]]; do
    case $1 in
        --reset)
            RESET=true
            ;;
        --apply)
            APPLY_RULES=true
            ;;
        *)
            echo "Unbekannter Parameter: $1"
            exit 1
            ;;
    esac
    shift
done

# Nur unsere ipsets: to_table_*
function clean_ipsets_and_iptables() {
    echo "[*] Entferne bestehende iptables-Mangle-Regeln für to_table_*"
    iptables -t mangle -S | grep "to_table_" | while read -r rule; do
        iptables -t mangle -D ${rule/-A/-D}
    done

    echo "[*] Lösche alle to_table_* ipsets"
    for set in $(ipset list -n | grep '^to_table_'); do
        echo "[-] ipset destroy $set"
        ipset destroy "$set"
    done
}

if $RESET; then
    clean_ipsets_and_iptables
    echo "[OK] Reset abgeschlossen."
    exit 0
fi

# Erst alte iptables Regeln entfernen (z. B. doppelte vermeiden)
clean_ipsets_and_iptables

# Loop über alle Routingtabellen
for entry in "${EXTRA_RT_TABLES[@]}"; do
    TABLE_ID=$(echo "$entry" | awk '{print $1}')
    TABLE_NAME=$(echo "$entry" | awk '{print $2}')
    IPSET_NAME="to_table_${TABLE_ID}"

    echo "[INFO] Verarbeite Routingtable $TABLE_ID ($TABLE_NAME) → ipset: $IPSET_NAME"

    # ipset erstellen oder flushen
    if ! ipset list -n | grep -q "^${IPSET_NAME}$"; then
        echo "[+] Erstelle ipset $IPSET_NAME"
        ipset create "$IPSET_NAME" hash:net
    else
        echo "[~] ipset $IPSET_NAME existiert – leere es"
        ipset flush "$IPSET_NAME"
    fi

    # IPs aus Routingtabelle extrahieren
    for ip in $(ip route show table "$TABLE_ID" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}(/\d{1,2})?'); do
        ipset add "$IPSET_NAME" "$ip" 2>/dev/null || true
    done

    # iptables MARK-Regel setzen – PREROUTING für weitergeleiteten Traffic
    iptables -t mangle -A PREROUTING -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark "$TABLE_ID"
    echo "[+] iptables PREROUTING-Regel: $IPSET_NAME → MARK $TABLE_ID"

    # iptables MARK-Regel setzen – OUTPUT für lokal generierten Traffic
    iptables -t mangle -A OUTPUT -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark "$TABLE_ID"
    echo "[+] iptables OUTPUT-Regel: $IPSET_NAME → MARK $TABLE_ID"

    # Optional: ip rule setzen
    if $APPLY_RULES; then
        ip rule add fwmark $TABLE_ID table $TABLE_ID priority $TABLE_ID 2>/dev/null || true
        echo "[✓] ip rule für fwmark $TABLE_ID → table $TABLE_ID"
    fi
done
