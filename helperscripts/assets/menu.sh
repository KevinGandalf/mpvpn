#!/bin/bash

# Funktion, um alle verfügbaren Optionen anzuzeigen
show_help() {
    echo "Verfügbare Optionen für mpvpn:"
    echo "  --startmpvpn  : Startet MPVPN"
    echo "  --install     : Installiert die Abhängigkeiten"
    echo "  --addwg       : Neue WireGuard-Verbindung hinzufügen."
    echo "  --addovpn     : Neue OpenVPN-Verbindung hinzufügen."
    echo "  --addsssocks5 : Neue SSH Socks5 Verbindung hinzufügen."
    echo "  --status      : Anzeigen der aktiven Rules, iptables etc. " 
    echo "  --list        : Alle Verbindungen anzeigen."
    echo "  --backup      : Erstellt ein Backup, wenn aktiviert"
    echo "  --restore     : Stellt ein Backup wieder her"
    echo "  --update      : Aktualisiert MPVPN"
    echo "  --help        : Zeigt diese Hilfe an."
    echo "  --version     : Gibt die Version des Skripts aus."
}

# Funktion, um aktive Verbindungen anzuzeigen
list_active_connections() {
    echo "🔍 Zeige aktive Verbindungen an:"

    # Für WireGuard-Verbindungen
    echo "💻 Aktive WireGuard-Verbindungen:"
    wg show

    # Für OpenVPN-Verbindungen
    echo "💻 Aktive OpenVPN-Verbindungen:"
    ps aux | grep 'openvpn' | grep -v grep
}

# Prüfen, welche Parameter übergeben wurden
if [[ $# -eq 0 ]]; then
    # Keine Parameter übergeben, also Hilfe anzeigen
    show_help
# Funktion, um das mpvpn-Skript zu starten
elif [[ "$1" == "--startmpvpn" ]]; then
    echo "🚀 Starte mpvpn-Skript..."
    /opt/mpvpn/mpvpn.sh
# Funktion, um das Installations-Skript auszuführen
elif [[ "$1" == "--install" ]]; then
    echo "🚀 Installiere Anforderungen..."
    /opt/mpvpn/requirements.sh
elif [[ "$1" == "--addwg" ]]; then
    # Befehl für WireGuard-Verbindung hinzufügen
    $BASE_PATH/helperscripts/assets/addwgconnection.sh
elif [[ "$1" == "--addopenvpn" ]]; then
    # Befehl für OpenVPN-Verbindung hinzufügen
    $BASE_PATH/helperscripts/assets/addopenvpnconnection.sh
elif [[ "$1" == "--addsssocks5" ]]; then
    # Befehl zum Hinzufügen eines SSH SOCKS5-Tunnels
    $BASE_PATH/helperscripts/assets/addsshsocks5.sh
elif [[ "$1" == "--status" ]]; then
    # Befehl um den Status der Routing Regeln etc. zu prüfen
    $BASE_PATH/helperscripts/misc/check_status.sh
elif [[ "$1" == "--list" ]]; then
    # Befehl für das Anzeigen der aktiven Verbindungen
    list_active_connections
elif [[ "$1" == "--backup" ]]; then
    # Befehl für das Erstellen von Backups
    $BASE_PATH/helperscripts/assets/addbackup.sh
elif [[ "$1" == "--restore" ]]; then
    # Befehl für das Wiederherstellen von Backups
    $BASE_PATH/helperscripts/assets/restorebackup.sh
elif [[ "$1" == "--update" ]]; then
    # Befehl für das Update von MPVPN
    $BASE_PATH/helperscripts/assets/update.sh
elif [[ "$1" == "--help" ]]; then
    # Hilfe anzeigen
    show_help
elif [[ "$1" == "--version" ]]; then
    # Versionsinfo anzeigen
    echo "mpvpn Version 1.0"
else
    # Ungültiger Parameter
    echo "❌ Ungültiger Parameter. Benutze '--help' für Hilfe."
fi
