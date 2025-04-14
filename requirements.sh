#!/bin/bash

check_and_disable_ufw() {
    if command -v ufw >/dev/null 2>&1; then
        echo "🛠️  Deaktiviere ufw (Uncomplicated Firewall)..."
        systemctl stop ufw
        systemctl disable ufw
        ufw disable
    else
        echo "ℹ️  ufw ist nicht installiert oder nicht aktiv."
    fi
}

check_and_disable_firewalld() {
    if systemctl is-active --quiet firewalld; then
        echo "🛠️  Deaktiviere firewalld..."
        systemctl stop firewalld
        systemctl disable firewalld
    else
        echo "ℹ️  firewalld ist nicht aktiv oder nicht installiert."
    fi
}

install_iptables_alternative_debian() {
    if ! dpkg -s iptables-persistent >/dev/null 2>&1; then
        echo "⚠️  iptables-persistent ist nicht installiert."
        read -p "Möchtest du iptables-persistent installieren (empfohlen)? (y/n): " install_ip_pers
        if [[ "$install_ip_pers" == "y" ]]; then
            apt install -y iptables-persistent
        else
            echo "ℹ️  iptables-Persistenz wird übersprungen. Regeln müssen manuell gesichert werden."
        fi
    fi
}

install_iptables_alternative_rpm() {
    if ! rpm -q iptables-services >/dev/null 2>&1; then
        echo "⚠️  iptables-services ist nicht installiert."
        read -p "Möchtest du iptables-services installieren (empfohlen)? (y/n): " install_ip_serv
        if [[ "$install_ip_serv" == "y" ]]; then
            dnf install -y iptables-services || zypper install -y iptables-services
        else
            echo "ℹ️  iptables-Services wird übersprungen. Regeln müssen manuell gesichert werden."
        fi
    fi
}

install_debian_ubuntu() {
    echo "🛠️  Debian/Ubuntu: Update und Upgrade durchführen..."
    apt update && apt upgrade -y
    echo "🛠️  Installiere curl, wget, git, iptables, net-tools..."
    apt install -y curl wget git iptables net-tools

    install_iptables_alternative_debian

    if ! dpkg -s wireguard-tools >/dev/null 2>&1; then
        echo "🛠️  Installiere WireGuard..."
        apt install -y wireguard-tools
    else
        echo "ℹ️  WireGuard ist bereits installiert."
    fi

    read -p "Möchtest du OpenVPN installieren? (y/n): " install_ovpn
    if [[ "$install_ovpn" == "y" ]]; then
        apt install -y openvpn
    fi

    check_and_disable_ufw
    echo "✅ Debian/Ubuntu: Installation abgeschlossen."
}

install_fedora() {
    echo "🛠️  Fedora: Update und Upgrade durchführen..."
    dnf update -y && dnf upgrade -y
    echo "🛠️  Installiere curl, wget, git, iptables, net-tools..."
    dnf install -y curl wget git iptables net-tools

    install_iptables_alternative_rpm

    if ! rpm -q wireguard-tools; then
        dnf install -y wireguard-tools
    fi

    read -p "Möchtest du OpenVPN installieren? (y/n): " install_ovpn
    if [[ "$install_ovpn" == "y" ]]; then
        dnf install -y openvpn
    fi

    check_and_disable_firewalld
    echo "✅ Fedora: Installation abgeschlossen."
}

install_rocky() {
    echo "🛠️  Rocky Linux: Update und Upgrade durchführen..."
    dnf update -y && dnf upgrade -y
    echo "🛠️  Installiere curl, wget, git, iptables, net-tools..."
    dnf install -y curl wget git iptables net-tools

    install_iptables_alternative_rpm

    if ! rpm -q wireguard-tools; then
        dnf install -y wireguard-tools
    fi

    read -p "Möchtest du OpenVPN installieren? (y/n): " install_ovpn
    if [[ "$install_ovpn" == "y" ]]; then
        dnf install -y openvpn
    fi

    check_and_disable_firewalld
    echo "✅ Rocky Linux: Installation abgeschlossen."
}

install_arch() {
    echo "🛠️  Arch Linux: Update und Upgrade durchführen..."
    pacman -Syu --noconfirm
    echo "🛠️  Installiere curl, wget, git, iptables, net-tools..."
    pacman -S --noconfirm curl wget git iptables net-tools

    if ! pacman -Qs wireguard-tools > /dev/null; then
        pacman -S --noconfirm wireguard-tools
    fi

    read -p "Möchtest du OpenVPN installieren? (y/n): " install_ovpn
    if [[ "$install_ovpn" == "y" ]]; then
        pacman -S --noconfirm openvpn
    fi

    check_and_disable_firewalld
    echo "✅ Arch Linux: Installation abgeschlossen."
}

install_opensuse() {
    echo "🛠️  openSUSE: Update und Upgrade durchführen..."
    zypper update -y
    echo "🛠️  Installiere curl, wget, git, iptables, net-tools..."
    zypper install -y curl wget git iptables net-tools

    install_iptables_alternative_rpm

    if ! zypper search --installed-only wireguard-tools | grep -q wireguard; then
        zypper install -y wireguard-tools
    fi

    read -p "Möchtest du OpenVPN installieren? (y/n): " install_ovpn
    if [[ "$install_ovpn" == "y" ]]; then
        zypper install -y openvpn
    fi

    check_and_disable_firewalld
    echo "✅ openSUSE: Installation abgeschlossen."
}


