install_fedora() {
    echo "🛠️  Fedora: Update und Upgrade durchführen..."
    dnf update -y
    dnf upgrade -y
    echo "🛠️  Fedora: Installiere curl, wget, git, iptables, net-tools..."
    dnf install -y curl wget git iptables iptables-services net-tools

    # Installiere WireGuard, wenn benötigt
    if ! rpm -q wireguard-tools; then
        echo "🛠️  Fedora: Installiere WireGuard..."
        dnf install -y wireguard-tools
    else
        echo "ℹ️  WireGuard ist bereits installiert."
    fi

    # Abfrage, ob OpenVPN installiert werden soll
    read -p "Möchtest du OpenVPN installieren? (y/n): " install_ovpn
    if [[ "$install_ovpn" == "y" ]]; then
        echo "🛠️  Fedora: Installiere OpenVPN..."
        dnf install -y openvpn
    else
        echo "ℹ️  OpenVPN wird nicht installiert."
    fi

    check_and_disable_firewalld
    echo "✅ Fedora: Installation abgeschlossen."
}

install_rocky() {
    echo "🛠️  Rocky Linux: Update und Upgrade durchführen..."
    dnf update -y
    dnf upgrade -y
    echo "🛠️  Rocky Linux: Installiere curl, wget, git, iptables, net-tools..."
    dnf install -y curl wget git iptables iptables-services net-tools

    # Installiere WireGuard, wenn benötigt
    if ! rpm -q wireguard-tools; then
        echo "🛠️  Rocky Linux: Installiere WireGuard..."
        dnf install -y wireguard-tools
    else
        echo "ℹ️  WireGuard ist bereits installiert."
    fi

    # Abfrage, ob OpenVPN installiert werden soll
    read -p "Möchtest du OpenVPN installieren? (y/n): " install_ovpn
    if [[ "$install_ovpn" == "y" ]]; then
        echo "🛠️  Rocky Linux: Installiere OpenVPN..."
        dnf install -y openvpn
    else
        echo "ℹ️  OpenVPN wird nicht installiert."
    fi

    check_and_disable_firewalld
    echo "✅ Rocky Linux: Installation abgeschlossen."
}

install_arch() {
    echo "🛠️  Arch Linux: Update und Upgrade durchführen..."
    pacman -Syu --noconfirm
    echo "🛠️  Arch Linux: Installiere curl, wget, git, iptables, net-tools..."
    pacman -S --noconfirm curl wget git iptables net-tools

    # Installiere WireGuard, wenn benötigt
    if ! pacman -Qs wireguard-tools; then
        echo "🛠️  Arch Linux: Installiere WireGuard..."
        pacman -S --noconfirm wireguard-tools
    else
        echo "ℹ️  WireGuard ist bereits installiert."
    fi

    # Abfrage, ob OpenVPN installiert werden soll
    read -p "Möchtest du OpenVPN installieren? (y/n): " install_ovpn
    if [[ "$install_ovpn" == "y" ]]; then
        echo "🛠️  Arch Linux: Installiere OpenVPN..."
        pacman -S --noconfirm openvpn
    else
        echo "ℹ️  OpenVPN wird nicht installiert."
    fi

    check_and_disable_firewalld
    echo "✅ Arch Linux: Installation abgeschlossen."
}

install_opensuse() {
    echo "🛠️  openSUSE: Update und Upgrade durchführen..."
    zypper update -y
    echo "🛠️  openSUSE: Installiere curl, wget, git, iptables, net-tools..."
    zypper install -y curl wget git iptables iptables-services net-tools

    # Installiere WireGuard, wenn benötigt
    if ! zypper search --installed-only wireguard; then
        echo "🛠️  openSUSE: Installiere WireGuard..."
        zypper install -y wireguard-tools
    else
        echo "ℹ️  WireGuard ist bereits installiert."
    fi

    # Abfrage, ob OpenVPN installiert werden soll
    read -p "Möchtest du OpenVPN installieren? (y/n): " install_ovpn
    if [[ "$install_ovpn" == "y" ]]; then
        echo "🛠️  openSUSE: Installiere OpenVPN..."
        zypper install -y openvpn
    else
        echo "ℹ️  OpenVPN wird nicht installiert."
    fi

    check_and_disable_firewalld
    echo "✅ openSUSE: Installation abgeschlossen."
}

# Überprüfen der Distribution und die passende Funktion aufrufen
if [ -f /etc/debian_version ]; then
    install_debian_ubuntu
elif [ -f /etc/almalinux-release ]; then
    install_alma
elif [ -f /etc/centos-release ]; then
    install_rocky
elif [ -f /etc/fedora-release ]; then
    install_fedora
elif [ -f /etc/gentoo-release ]; then
    install_gentoo
elif [ -f /etc/arch-release ]; then
    install_arch
elif [ -f /etc/alpine-release ]; then
    install_alpine
elif [ -f /etc/os-release ] && grep -q "openSUSE" /etc/os-release; then
    install_opensuse
else
    echo "❌ Unbekannte Distribution. Dieses Skript unterstützt derzeit nur Debian, Ubuntu, AlmaLinux, Rocky Linux, Fedora, Gentoo, Arch, Alpine und openSUSE."
    exit 1
fi
