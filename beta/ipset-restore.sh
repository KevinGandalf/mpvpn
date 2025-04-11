#!/bin/bash

source /opt/mpvpn-routing/config/globals.sh

if [ -f "$IPSET_FILE_STREAMING" ]; then
    ipset restore < "$IPSET_FILE_STREAMING"
    echo "[+] Streaming ipset geladen."
fi

if [ -f "$IPSET_FILE_GAMING" ]; then
    ipset restore < "$IPSET_FILE_GAMING"
    echo "[+] Gaming ipset geladen."
fi
