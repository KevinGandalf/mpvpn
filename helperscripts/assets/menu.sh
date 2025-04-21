#!/bin/bash

# Funktion, um alle verfügbaren Optionen anzuzeigen
show_help() {
    echo "Verfügbare Optionen für mpvpn:"
    echo "  --startmpvpn : Startet MPVPN"
    echo "  --install    : Installiert die Abhängigkeiten"
    echo "  --addwg      : Neue WireGuard-Verbindung hinzufügen."
    echo "  --addovpn    : Neue OpenVPN-Verbindung hinzufügen."
    echo "  --list       : Alle Verbindungen anzeigen."
    echo "  --help       : Zeigt diese Hilfe an."
    echo "  --version    : Gibt die Version des Skripts aus."
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
    /opt/mpvpn/helperscripts/assets/addwgconnection.sh
elif [[ "$1" == "--addopenvpn" ]]; then
    # Befehl für OpenVPN-Verbindung hinzufügen
    /opt/mpvpn/helperscripts/assets/addopenvpnconnection.sh
elif [[ "$1" == "--addsssocks5" ]]; then
    # Befehl zum Hinzufügen eines SSH SOCKS5-Tunnels
    /opt/mpvpn/helperscripts/assets/addsshsocks5.sh
elif [[ "$1" == "--list" ]]; then
    # Befehl für das Anzeigen der aktiven Verbindungen
    list_active_connections
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
