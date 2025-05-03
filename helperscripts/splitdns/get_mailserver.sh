#!/bin/bash
set -Eeuo pipefail

trap 'echo "❌ [$(date +%T)] Fehler in Zeile $LINENO: Befehl \"$BASH_COMMAND\" fehlgeschlagen." >&2' ERR

source $BASE_PATH/globals.conf

# === KONFIGURATION ===
CONFIG_FILE="/opt/mpvpn/globals.conf"
IPSET_NAME="smtp_dst_ip"
ROUTE_TABLE="smtp"
TABLE_ID="200"
MAX_RETRIES=3
SLEEP_DELAY=1
RT_TABLES_FILE="/etc/iproute2/rt_tables"
REQUIRED_PKGS=("ipset" "iptables" "dig")

# === FUNKTIONEN ===
log() { echo "ℹ️  [$(date '+%T')] $1"; }
die() { echo "❌ [$(date '+%T')] $1" >&2; exit 1; }

check_dependencies() {
    for pkg in "${REQUIRED_PKGS[@]}"; do
        command -v "$pkg" >/dev/null || die "Erforderliches Paket '$pkg' nicht gefunden"
    done
}

validate_ip() {
    [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

ensure_route_table() {
    if ! grep -qE "^$TABLE_ID[[:space:]]+$ROUTE_TABLE" "$RT_TABLES_FILE"; then
        log "Routing-Tabelle $ROUTE_TABLE ($TABLE_ID) nicht vorhanden – wird erstellt"
        cp -p "$RT_TABLES_FILE" "${RT_TABLES_FILE}.bak" || die "Backup fehlgeschlagen"
        echo -e "\n# Automatisch hinzugefügt\n$TABLE_ID $ROUTE_TABLE" >> "$RT_TABLES_FILE"
    fi
    MARK="$TABLE_ID"
}

nuclear_cleanup() {
    log "Starte vollständige Bereinigung..."

    local rules_file
    rules_file=$(mktemp)

	for table in mangle nat filter; do
    		iptables -t "$table" -S > "$rules_file"
    		grep -E "(MARK --set-xmark 0x$TABLE_ID|match-set $IPSET_NAME)" "$rules_file" || true | while IFS= read -r rule; do
        	local clean_rule="${rule#*-A }"
            if iptables -t "$table" -C ${clean_rule} &>/dev/null; then
                iptables -t "$table" -D ${clean_rule} && log "Gelöscht: $table ${clean_rule}"
            fi
        done
    done

    rm -f "$rules_file"
    ipset flush "$IPSET_NAME" 2>/dev/null || true
    ipset destroy "$IPSET_NAME" 2>/dev/null || true
    ip route flush table "$ROUTE_TABLE" 2>/dev/null || true
    ip rule del fwmark "$MARK" 2>/dev/null || true
    log "Bereinigung abgeschlossen"
}

safe_ipset_create() {
    for ((i=1; i<=MAX_RETRIES; i++)); do
        if ipset create "$IPSET_NAME" hash:net 2>/dev/null; then
            log "ipset $IPSET_NAME erfolgreich erstellt"
            return 0
        fi
        log "ipset-Erstellung fehlgeschlagen (Versuch $i), erneuter Versuch nach Cleanup"
        nuclear_cleanup
        sleep "$SLEEP_DELAY"
    done
    die "ipset $IPSET_NAME konnte nicht erstellt werden"
}

add_iptables_rule() {
    local table="$1" chain="$2" rule="$3" desc="$4"
    if ! iptables -t "$table" -C "$chain" $rule 2>/dev/null; then
        iptables -t "$table" -A "$chain" $rule
        log "Hinzugefügt: $desc"
    else
        log "Existiert bereits: $desc"
    fi
}

# === HAUPT ===

log "Lade Konfiguration..."
source "$CONFIG_FILE"

# Erwartete Variablen prüfen
: "${DEFAULT_LANIF:?Fehlende Variable: DEFAULT_LANIF}"
: "${DEFAULT_WANGW:?Fehlende Variable: DEFAULT_WANGW}"
: "${MAIL_SERVERS:?Fehlende Variable: MAIL_SERVERS}"

check_dependencies
ensure_route_table

# VPN-Interfaces laden
VPN_INTERFACES=()
if [[ -n "${WGVPN_LIST:-}" ]]; then
    IFS=',' read -ra VPN_INTERFACES <<< "$WGVPN_LIST"
fi
if [[ "${ENABLE_OVPN:-false}" == "true" && -n "${OVPN_LIST:-}" ]]; then
    IFS=',' read -ra OVPN_IFACES <<< "$OVPN_LIST"
    VPN_INTERFACES+=("${OVPN_IFACES[@]}")
fi

log "Aktive Konfiguration:"
log " - Tabelle: $ROUTE_TABLE (ID: $MARK)"
log " - Interface: $DEFAULT_LANIF"
log " - Gateway: $DEFAULT_WANGW"
log " - VPN Interfaces: ${VPN_INTERFACES[*]:-Keine}"

nuclear_cleanup
safe_ipset_create

log "Verarbeite Mailserver..."
declare -A processed_ips=()
FAILED_IPS=0

for server in "${MAIL_SERVERS[@]}"; do
    log "Bearbeite Server: $server"

    # Versuche IPs aufzulösen, Fehler ignorieren
    mapfile -t ips < <(dig +short +time=2 +tries=2 A "$server" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' || true)

    if [[ ${#ips[@]} -eq 0 ]]; then
        log " ⚠️ Keine IP-Adressen für $server gefunden"
        ((FAILED_IPS+=1))
        continue
    fi

    for ip in "${ips[@]}"; do
        [[ -z "$ip" ]] && continue
        [[ -n "${processed_ips[$ip]:-}" ]] && continue

        processed_ips["$ip"]=1

        if validate_ip "$ip"; then
            if ipset add "$IPSET_NAME" "$ip" 2>/dev/null; then
                log " + IP hinzugefügt: $ip"
                ip route add "$ip" via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" table "$ROUTE_TABLE" 2>/dev/null \
                    && log "   🛣️ Route gesetzt" || log "   ⚠️ Konnte Route nicht setzen"

                for vpn_if in "${VPN_INTERFACES[@]}"; do
                    ip route del "$ip" dev "$vpn_if" 2>/dev/null && log "   ➖ VPN-Route entfernt ($vpn_if)"
                done
            else
                log " ⚠️ Konnte IP nicht zum ipset hinzufügen: $ip"
                ((FAILED_IPS+=1))
            fi
        else
            log " ⚠️ Ungültige IP: $ip"
            ((FAILED_IPS+=1))
        fi
    done
done


log "Richte Routing ein..."
ip rule show | grep -q "fwmark $MARK" || {
    ip rule add fwmark "$MARK" table "$ROUTE_TABLE"
    log "✔ Routing-Regel hinzugefügt"
}

ip route show table "$ROUTE_TABLE" | grep -q "default via" || {
    ip route add default via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF" table "$ROUTE_TABLE"
    log "✔ Standardroute für $ROUTE_TABLE gesetzt"
}

log "Füge iptables-Regeln hinzu..."
add_iptables_rule mangle PREROUTING \
    "-m set --match-set $IPSET_NAME dst -j MARK --set-xmark 0x$MARK/0xffffffff" \
    "PREROUTING (ipset)"

add_iptables_rule mangle OUTPUT \
    "-m set --match-set $IPSET_NAME dst -j MARK --set-xmark 0x$MARK/0xffffffff" \
    "OUTPUT (ipset)"

log "Setze Reverse Path Filter (rp_filter)..."
echo 0 > "/proc/sys/net/ipv4/conf/all/rp_filter" 2>/dev/null || true
echo 0 > "/proc/sys/net/ipv4/conf/$DEFAULT_LANIF/rp_filter" 2>/dev/null || true

# === FERTIG ===
log "✅ Konfiguration abgeschlossen"
log "Statistik:"
log " - Server verarbeitet: ${#MAIL_SERVERS[@]}"
log " - Eindeutige IPs: ${#processed_ips[@]}"
log " - Fehlerhafte IPs: $FAILED_IPS"
