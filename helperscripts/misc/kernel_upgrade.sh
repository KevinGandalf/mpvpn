#!/bin/bash

update_to_kernel6() {
    echo "🔍 Erkenne Distribution..."

    # Lade OS-Info
    source /etc/os-release
    DISTRO_ID=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
    DISTRO_NAME=$NAME

    echo "➡️ Erkannt: $DISTRO_NAME"

    case "$DISTRO_ID" in
        debian|ubuntu)
            echo "🛠️  Debian/Ubuntu basiert – Kernel Upgrade über Backports oder Mainline"

            apt update
            apt install -y wget gnupg software-properties-common

            if [[ "$DISTRO_ID" == "ubuntu" ]]; then
                echo "📦 Ubuntu: Installiere mainline Kernel Installer..."
                add-apt-repository -y ppa:cappelikan/ppa
                apt update
                apt install -y mainline
                echo "✅ Starte das Tool mit 'mainline' und wähle Kernel 6.x aus."
            elif [[ -f /boot/firmware/config.txt || "$DISTRO_NAME" == *"Raspbian"* ]]; then
                echo "🍓 Raspbian/Raspberry Pi erkannt."
                echo "⚠️  Das Kernel-Upgrade erfolgt über das Raspberry Pi OS Tool 'rpi-update'."
                echo "👉 Installiere mit:"
                echo "    sudo apt install rpi-update"
                echo "    sudo rpi-update"
                echo "    sudo reboot"
                echo "🔴 Achtung: 'rpi-update' installiert *experimentelle* Kernel-Versionen!"
            else
                echo "📄 Debian: Manuelles Upgrade empfohlen – siehe:"
                echo "🔗 https://wiki.debian.org/DebianKernel"
            fi
            ;;

        fedora)
            echo "🛠️ Fedora: Kernel-Paket wird aktualisiert"
            dnf install -y kernel-core kernel-devel kernel-headers
            dnf upgrade --refresh -y
            echo "✅ Kernel 6.x wurde installiert oder aktualisiert."
            ;;

        rocky|almalinux)
            echo "🛠️ Rocky/AlmaLinux: ELRepo wird genutzt"
            yum install -y https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm
            yum install -y --enablerepo=elrepo-kernel kernel-ml kernel-ml-devel
            grub2-set-default 0
            echo "✅ Kernel 6.x wurde installiert und als Standard gesetzt."
            ;;

        arch)
            echo "🛠️ Arch Linux: Update auf neuesten Kernel"
            pacman -Syu --noconfirm
            echo "✅ Arch Linux wurde aktualisiert (Kernel 6.x ist Standard)."
            ;;

        opensuse*)
            echo "🛠️ openSUSE: Kernel:stable Repository wird verwendet"
            zypper ar -f https://download.opensuse.org/repositories/Kernel:/stable/standard/ kernel-stable
            zypper refresh
            zypper install --allow-vendor-change -y kernel-default
            grub2-set-default 0
            echo "✅ Kernel 6.x aus Kernel:stable installiert und gesetzt."
            ;;

        *)
            echo "❌ Distribution '$DISTRO_ID' wird nicht automatisch unterstützt."
            exit 1
            ;;
    esac

    echo ""
    read -p "🔁 Möchtest du jetzt neu starten, um den neuen Kernel zu aktivieren? (y/n): " do_reboot
    if [[ "$do_reboot" =~ ^[Yy]$ ]]; then
        echo "♻️ Starte System neu..."
        reboot
    else
        echo "ℹ️ Bitte starte dein System später neu, um den neuen Kernel zu verwenden."
    fi
}

# Aufruf
update_to_kernel6
