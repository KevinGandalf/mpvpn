# globals.sh

# Pfad für ipset-Dateien
IPSET_FILE_STREAMING="/opt/mpvpn-routing/ipsets/streaming_ips.set"
IPSET_FILE_GAMING="/opt/mpvpn-routing/ipsets/gaming_ips.set"

# Stealth-Optionen
stealth_streaming_rtable="500"         # Routing-Tabelle für Streaming
stealth_streaming_if="enp1s0"          # Interface für Streaming
stealth_streaming_mode=true            # Aktiviert oder deaktiviert Streaming-Stealth

stealth_gaming_rtable="600"            # Routing-Tabelle für Gaming
stealth_gaming_if="enp1s1"             # Interface für Gaming
stealth_gaming_mode=true               # Aktiviert oder deaktiviert Gaming-Stealth
