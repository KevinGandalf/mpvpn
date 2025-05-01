#!/bin/bash
set -e

# BASE_PATH ist systemweit gesetzt
source "$BASE_PATH/globals.conf"

MPVPN_DIR="$BASE_PATH"
BACKUP_DIR="${BASE_PATH}_backups/mpvpn_backup_$(date +%Y%m%d_%H%M%S)"
GIT_REPO="https://github.com/KevinGandalf/mpvpn.git"  # ggf. anpassen
TEMP_DIR="/tmp/mpvpn_update_tmp"

echo "===> Starte MPVPN Update..."

# === Backup der aktuellen Konfiguration ===
echo "===> Backup der aktuellen Konfiguration nach $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -a "$MPVPN_DIR/globals.conf" "$BACKUP_DIR/" 2>/dev/null || true
cp -a "$MPVPN_DIR/" "$BACKUP_DIR/" 2>/dev/null || true

# Erstelle einen Tarball des Backups
echo "===> Erstelle Tarball des Backups"
tar -czf "$BACKUP_DIR/mpvpn_backup_$(date +%Y%m%d_%H%M%S).tar.gz" -C "$BASE_PATH" .

# === Temporäres Update-Verzeichnis vorbereiten ===
rm -rf "$TEMP_DIR"
git clone "$GIT_REPO" "$TEMP_DIR"

# === Aktuelle Default-Route sichern ===
DEFAULT_ROUTE=$(ip route | grep "^default" | head -n1)
echo "Sichere aktuelle Default-Route:"
echo "$DEFAULT_ROUTE"

# === WireGuard-Verbindungen stoppen ===
for VPN in "${WGVPN_LIST[@]}"; do
    echo "Stoppe WireGuard-Verbindung: $VPN"
    wg-quick down "$VPN" || echo "Warnung: wg-quick down $VPN fehlgeschlagen"
done

# === OpenVPN-Verbindungen stoppen (wenn aktiviert) ===
if [[ "$ENABLE_OVPN" == "true" ]]; then
    for VPN in "${OVPN_LIST[@]}"; do
        echo "Stoppe OpenVPN-Verbindung: $VPN"
        pkill -f "openvpn.*$VPN" || echo "Hinweis: Kein laufender OpenVPN-Prozess für $VPN"
    done
fi

# Kurze Pause, damit Routing aktualisiert ist
sleep 2

# Default-Route prüfen
if ! ip route | grep -q "^default"; then
    echo "Keine Default-Route gefunden – stelle alte Route wieder her:"
    echo "$DEFAULT_ROUTE"
    ip route add $DEFAULT_ROUTE
else
    echo "Default-Route vorhanden – keine Wiederherstellung nötig."
fi

echo "===> Alle VPN-Verbindungen wurden gestoppt."

# === Systemupdates optional durchführen ===
get_os_type() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

run_system_update() {
    OS=$(get_os_type)

    echo ""
    read -rp "Möchtest du jetzt Systemupdates durchführen (inkl. Autoremove)? (y/N): " update_choice
    if [[ "$update_choice" =~ ^[Yy]$ ]]; then
        echo "===> Führe Systemupdate durch für: $OS"
        case "$OS" in
            debian|ubuntu|raspbian)
                apt update && apt upgrade -y && apt autoremove -y
                ;;
            alpine)
                apk update && apk upgrade
                ;;
            rhel|rocky|almalinux)
                dnf update -y && dnf autoremove -y
                ;;
            *)
                echo "Update für dieses OS nicht automatisiert unterstützt: $OS"
                ;;
        esac
        echo "===> Systemupdate abgeschlossen."
    else
        echo "===> Systemupdate übersprungen."
    fi
}

run_system_update

# === Dateien aktualisieren (ohne globals.conf) ===
echo "===> Kopiere neue Dateien nach $MPVPN_DIR"
rsync -av --exclude 'globals.conf' "$TEMP_DIR/" "$MPVPN_DIR/"

# === Alte globals.conf wiederherstellen ===
echo "===> Stelle vorherige globals.conf wieder her"
cp -a "$BACKUP_DIR/globals.conf" "$MPVPN_DIR/"

# === Cleanup ===
rm -rf "$TEMP_DIR"

# === Dienste optional neustarten ===
read -rp "MPVPN nach dem Update neu starten? [y/N]: " RESTART_MPVPN
if [[ "$RESTART_MPVPN" =~ ^[Yy]$ ]]; then
    echo "===> Starte MPVPN neu..."
    "$BASE_PATH/mpvpn.sh"
fi

echo "===> Update abgeschlossen."
