#!/bin/bash

set -e

TMP_CONF="/tmp/xray_server_setup.tmp"
XRAY_BASE_DIR="/etc/xray"
NGINX_CONF_DIR="/etc/nginx/conf.d"
XRAY_SERVICE_DIR="/etc/systemd/system"

# OS-Erkennung + Paketinstallation
install_dependencies() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
    else
        echo "Unbekanntes Betriebssystem"
        exit 1
    fi

    case "$OS_ID" in
        debian|ubuntu|raspbian)
            apt update
            apt install -y nginx curl socat unzip cron certbot xray
            ;;
        alpine)
            apk update
            apk add nginx curl socat unzip xray certbot
            rc-update add nginx default
            ;;
        rhel|rocky|almalinux)
            dnf install -y nginx curl socat unzip cronie epel-release certbot xray
            systemctl enable crond
            ;;
        *)
            echo "Nicht unterstütztes OS: $OS_ID"
            exit 1
            ;;
    esac
}

# Daten aus tmp laden
load_tmp_conf() {
    source "$TMP_CONF"
    DOMAIN="$Domain"
    PORT="$Port"
    PATH="$Path"
    ALL_KEYS=$(grep "^XRAY_.*_PORT=" "$TMP_CONF" | cut -d= -f1 | sed 's/_PORT$//')
}

# Konfiguriere Nginx + Zertifikate
configure_nginx_and_ssl() {
    mkdir -p /var/www/html
    echo "<html><body>OK</body></html>" > /var/www/html/index.html

    systemctl enable nginx
    systemctl start nginx

    certbot certonly --webroot -w /var/www/html -d "$DOMAIN" --non-interactive --agree-tos -m admin@$DOMAIN || true

    echo "0 3 * * * root certbot renew --quiet && systemctl reload nginx" > /etc/cron.d/ssl_renew
    chmod 644 /etc/cron.d/ssl_renew

    cat > "$NGINX_CONF_DIR/xray.conf" <<EOF
server {
    listen $PORT ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_redirect off;
        proxy_pass http://127.0.0.1;
    }
}
EOF

    systemctl reload nginx
}

# Generiere Xray Konfigurationen je VPN
generate_xray_services() {
    mkdir -p "$XRAY_BASE_DIR"

    for VPN in $ALL_KEYS; do
        PORT_VAR="${VPN}_PORT"
        PASS_VAR="${VPN}_PASS"
        PORT=${!PORT_VAR}
        PASS=${!PASS_VAR}

        UUID=$(uuidgen)

        CONFIG_FILE="$XRAY_BASE_DIR/${VPN}.json"

        cat > "$CONFIG_FILE" <<EOF
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "shadowsocks",
    "settings": {
      "method": "chacha20-ietf-poly1305",
      "password": "$PASS",
      "network": "tcp,udp"
    },
    "streamSettings": {
      "security": "none"
    }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF

        SERVICE_FILE="$XRAY_SERVICE_DIR/xray-$VPN.service"

        cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Xray Shadowsocks for $VPN
After=network.target

[Service]
ExecStart=/usr/bin/xray run -config $CONFIG_FILE
Restart=on-failure
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reexec
        systemctl daemon-reload
        systemctl enable xray-$VPN
        systemctl start xray-$VPN
    done
}

# Hauptfunktion
main() {
    install_dependencies
    load_tmp_conf
    configure_nginx_and_ssl
    generate_xray_services
    echo "Xray-Bridge-Server wurde erfolgreich eingerichtet."
}

main
