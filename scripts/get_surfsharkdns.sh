#!/bin/bash

# Liste der DNS-Server
DNS_SERVERS=("8.8.8.8" "1.1.1.1" "9.9.9.9" "208.67.222.222")

# Ziel-Domain
DOMAIN="de-ber.prod.surfshark.com"

# Gateway und Interface für die Route
GATEWAY="192.168.10.1"
INTERFACE="enp1s0"

# Array für bekannte IPs
declare -A KNOWN_IPS

echo "Starte DNS-Abfragen für $DOMAIN..."

# DNS-Abfragen über verschiedene Server
for DNS in "${DNS_SERVERS[@]}"; do
    echo "Frage DNS-Server: $DNS"

    # IPv4-Adressen abrufen
    for IP in $(dig +short A @$DNS $DOMAIN); do
        KNOWN_IPS["$IP"]=1
    done

    # IPv6-Adressen abrufen (optional)
    for IP in $(dig +short AAAA @$DNS $DOMAIN); do
        KNOWN_IPS["$IP"]=1
    done

    # Eine Sekunde warten, um Rate-Limiting zu vermeiden
    sleep 1
done

# Neue Routen setzen
for IP in "${!KNOWN_IPS[@]}"; do
    echo "Setze Route für: $IP"
    sudo ip route add "$IP" via "$GATEWAY" dev "$INTERFACE"
done

echo "Fertig!"
