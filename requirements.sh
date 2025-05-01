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

check_iproute2() {
    if ! command -v ip >/dev/null 2>&1; then
        echo "⚠️  iproute2 ist nicht installiert. Versuche Installation..."
        case "$DISTRO" in
            debian|ubuntu|raspbian) apt install -y iproute2 ;;
            fedora|rocky|centos|almalinux) dnf install -y iproute ;;
            arch) pacman -S --noconfirm iproute2 ;;
            opensuse) zypper install -y iproute2 ;;
            *) echo "❌ iproute2 konnte nicht automatisch installiert werden. Bitte manuell installieren." ;;
        esac
    else
        echo "✅ iproute2 ist bereits installiert."
    fi
}

install_iptables_alternative_debian() {
    if ! dpkg -s iptables-persistent >/dev/null 2>&1; then
        echo "⚠️  iptables-persistent ist nicht installiert."
        read -p "Möchtest du iptables-persistent installieren (empfohlen)? (y/n): " install_ip_pers
        [[ "$install_ip_pers" == "y" ]] && apt install -y iptables-persistent
    fi
}

install_iptables_alternative_rpm() {
    if ! rpm -q iptables-services >/dev/null 2>&1; then
        echo "⚠️  iptables-services ist nicht installiert."
        read -p "Möchtest du iptables-services installieren (empfohlen)? (y/n): " install_ip_serv
        [[ "$install_ip_serv" == "y" ]] && dnf install -y iptables-services
    fi
}

install_epel_if_needed() {
    if [[ "$DISTRO" =~ ^(rocky|centos|almalinux)$ ]]; then
        if ! rpm -q epel-release >/dev/null 2>&1; then
            echo "🛠️  Installiere EPEL-Repository..."
            dnf install -y epel-release
        else
            echo "✅ EPEL bereits installiert."
        fi
    fi
}

install_debian_ubuntu() {
    echo "🛠️  Debian/Ubuntu: Update und Upgrade..."
    apt update && apt upgrade -y
    apt install -y curl wget git iptables net-tools nano rsyslog ipset
    check_iproute2
    install_iptables_alternative_debian

    if ! dpkg -s wireguard-tools >/dev/null 2>&1; then
        apt install -y wireguard-tools wireguard
    fi

    read -p "Möchtest du OpenVPN installieren? (y/n): " install_ovpn
    [[ "$install_ovpn" == "y" ]] && apt install -y openvpn

    check_and_disable_ufw
    echo "✅ Debian/Ubuntu: Installation abgeschlossen."
}

install_fedora() {
    echo "🛠️  Fedora: Update und Upgrade..."
    dnf update -y && dnf upgrade -y
    dnf install -y curl wget git iptables net-tools nano rsyslog ipset
    check_iproute2
    install_iptables_alternative_rpm

    rpm -q wireguard-tools || dnf install -y wireguard-tools

    read -p "Möchtest du OpenVPN installieren? (y/n): " install_ovpn
    [[ "$install_ovpn" == "y" ]] && dnf install -y openvpn

    check_and_disable_firewalld
    echo "✅ Fedora: Installation abgeschlossen."
}

install_rocky_alma() {
    echo "🛠️  Rocky/CentOS/AlmaLinux: Update und Upgrade..."
    dnf update -y && dnf upgrade -y
    install_epel_if_needed
    dnf install -y curl wget git iptables net-tools nano rsyslog ipset
    check_iproute2
    install_iptables_alternative_rpm

    rpm -q wireguard-tools || dnf install -y wireguard-tools

    read -p "Möchtest du OpenVPN installieren? (y/n): " install_ovpn
    [[ "$install_ovpn" == "y" ]] && dnf install -y openvpn

    check_and_disable_firewalld
    echo "✅ Rocky/CentOS/AlmaLinux: Installation abgeschlossen."
}

install_arch() {
    echo "🛠️  Arch Linux: Update und Upgrade..."
    pacman -Syu --noconfirm
    pacman -S --noconfirm curl wget git iptables net-tools nano syslog-ng iproute2 ipset

    pacman -Qs wireguard-tools > /dev/null || pacman -S --noconfirm wireguard-tools

    read -p "Möchtest du OpenVPN installieren? (y/n): " install_ovpn
    [[ "$install_ovpn" == "y" ]] && pacman -S --noconfirm openvpn

    check_and_disable_firewalld
    echo "✅ Arch Linux: Installation abgeschlossen."
}

install_opensuse() {
    echo "🛠️  openSUSE: Update und Upgrade..."
    zypper update -y
    zypper install -y curl wget git iptables net-tools nano syslog-ng iproute2 ipset

    install_iptables_alternative_rpm

    if ! zypper search --installed-only wireguard-tools | grep -q wireguard; then
        zypper install -y wireguard-tools
    fi

    read -p "Möchtest du OpenVPN installieren? (y/n): " install_ovpn
    [[ "$install_ovpn" == "y" ]] && zypper install -y openvpn

    check_and_disable_firewalld
    echo "✅ openSUSE: Installation abgeschlossen."
}

detect_distro() {
    source /etc/os-release
    DISTRO=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
}

main() {
    detect_distro
    case "$DISTRO" in
        debian|ubuntu|raspbian) install_debian_ubuntu ;;
        fedora) install_fedora ;;
        rocky|centos|almalinux) install_rocky_alma ;;
        arch) install_arch ;;
        opensuse*) install_opensuse ;;
        *)
            echo "❌ Distribution '$DISTRO' wird nicht unterstützt."
            exit 1
            ;;
    esac

    echo ""
    read -p "Möchtest du das Kernel-Upgrade auf 6.x ausführen? (empfohlen) (y/n): " do_upgrade
    if [[ "$do_upgrade" == "y" ]]; then
        echo "🚀 Starte Kernel-Upgrade..."
        bash /opt/mpvpn/helperscripts/misc/kernel_upgrade.sh
        echo "✅ Kernel-Upgrade abgeschlossen."
        read -p "❗ System muss eventuell neu gestartet werden. Jetzt rebooten? (y/n): " reboot_now
        [[ "$reboot_now" == "y" ]] && reboot
    fi
}

main
