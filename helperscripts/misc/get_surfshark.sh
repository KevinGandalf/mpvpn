#!/bin/bash

source $BASE_PATH/globals.conf

# Liste der DNS-Server
DNS_SERVERS=("8.8.8.8" "1.1.1.1" "9.9.9.9" "208.67.222.222")

# Ziel-Domain
DOMAINS=(
    "de-ber.prod.surfshark.com"
    "de-fra.prod.surfshark.com"
    "nl-ams.prod.surfshark.com"
    "uk-lon.prod.surfshark.com"
    "us-nyc.prod.surfshark.com"
    "us-sfo.prod.surfshark.com"
    "us-lax.prod.surfshark.com"
    "us-mia.prod.surfshark.com"
    "us-chi.prod.surfshark.com"
    "ca-tor.prod.surfshark.com"
    "fr-par.prod.surfshark.com"
    "it-mil.prod.surfshark.com"
    "es-mad.prod.surfshark.com"
    "ch-zur.prod.surfshark.com"
    "at-vie.prod.surfshark.com"
    "se-sto.prod.surfshark.com"
    "no-osl.prod.surfshark.com"
    "dk-cph.prod.surfshark.com"
    "fi-hel.prod.surfshark.com"
    "pl-waw.prod.surfshark.com"
    "cz-prg.prod.surfshark.com"
    "ro-buh.prod.surfshark.com"
    "ru-mow.prod.surfshark.com"
    "ua-iev.prod.surfshark.com"
    "au-syd.prod.surfshark.com"
    "nz-akl.prod.surfshark.com"
    "sg-sin.prod.surfshark.com"
    "hk-hkg.prod.surfshark.com"
    "jp-tok.prod.surfshark.com"
    "kr-seo.prod.surfshark.com"
    "in-del.prod.surfshark.com"
    "za-jnb.prod.surfshark.com"
    "br-sao.prod.surfshark.com"
    "ar-bue.prod.surfshark.com"
    "mx-mex.prod.surfshark.com"
    "tr-ist.prod.surfshark.com"
    "ae-dub.prod.surfshark.com"
    "is-rkv.prod.surfshark.com"
    "pt-lis.prod.surfshark.com"
    "gr-ath.prod.surfshark.com"
    "ie-dub.prod.surfshark.com"
    "bg-sof.prod.surfshark.com"
)

# Array für bekannte IPs
declare -A KNOWN_IPS

echo "Starte DNS-Abfragen für $DOMAIN..."

# DNS-Abfragen über verschiedene Server
for DNS in "${DNS_SERVERS[@]}"; do
    echo "Frage DNS-Server: $DNS"

    # IPv4-Adressen abrufen
    for IP in $(dig +short A @$DNS $DOMAINS); do
        KNOWN_IPS["$IP"]=1
    done

    # IPv6-Adressen abrufen (optional)
    for IP in $(dig +short AAAA @$DNS $DOMAINS); do
        KNOWN_IPS["$IP"]=1
    done

    # Eine Sekunde warten, um Rate-Limiting zu vermeiden
    sleep 1
done

# Neue Routen setzen
for IP in "${!KNOWN_IPS[@]}"; do
    echo "Setze Route für: $IP"
    sudo ip route add "$IP" via "$DEFAULT_WANGW" dev "$DEFAULT_LANIF"
done

echo "Fertig!"
