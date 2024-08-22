#!/bin/sh

echo "Welcome to the \033[1;34mArch Linux\033[0m Configuration Script (ALCS)!"
echo "This script is for after you install the base system (Using Pacstrap) and after making /etc/fstab (Using genfstab)."
echo "You should be running this in your chroot environment. If not, copy this script to the new Arch Linux Installation, and use 'arch-chroot' to enter the environment."
pacman -Syu --noconfirm

# Set Hostname
read -p "What will your hostname be? " HOSTNAME
echo $HOSTNAME > /etc/hostname

# Configure Locale
read -p "Enter the locale you want to use (e.g., en_US.UTF-8): " locale
if grep -q "^$locale UTF-8" /etc/locale.gen; then
    echo "The locale $locale is already enabled in /etc/locale.gen."
else
    sed -i "s/^#$locale UTF-8/$locale UTF-8/" /etc/locale.gen
    if grep -q "^$locale UTF-8" /etc/locale.gen; then
        echo "The locale $locale has been enabled in /etc/locale.gen."
        locale-gen
        echo "Locale generation complete."
    else
        echo "Failed to enable the locale $locale in /etc/locale.gen."
    fi
fi

# Set Keyboard Layout
read -p "Enter the keyboard layout you want to use (e.g., us, de, fr): " keyboard_layout
if grep -q "^KEYMAP=" /etc/vconsole.conf; then
    sed -i "s/^KEYMAP=.*/KEYMAP=$keyboard_layout/" /etc/vconsole.conf
else
    echo "KEYMAP=$keyboard_layout" >> /etc/vconsole.conf
fi

if grep -q "^KEYMAP=$keyboard_layout" /etc/vconsole.conf; then
    echo "The keyboard layout has been set to $keyboard_layout in /etc/vconsole.conf."
else
    echo "Failed to set the keyboard layout in /etc/vconsole.conf."
fi

# Install Desktop Environment
install_de() {
    case $1 in
        1)
            echo "Installing Deepin Desktop Environment..."
            pacman -Syu --noconfirm deepin deepin-extra gdm
            systemctl enable gdm
            ;;
        2)
            echo "Installing GNOME Desktop Environment..."
            pacman -Syu --noconfirm gnome gnome-extra gdm
            systemctl enable gdm
            ;;
        3)
            echo "Installing KDE Plasma Desktop Environment with selected packages..."
            pacman -Syu --noconfirm plasma plasma-meta kde-applications kde-system konsole firefox
            systemctl enable sddm
            ;;
        4)
            echo "Installing Cinnamon Desktop Environment..."
            pacman -Syu --noconfirm cinnamon cinnamon-translations gnome-terminal gdm
            systemctl enable gdm
            ;;
        *)
            echo "Invalid option, the script will exit."
            exit 1
            ;;
    esac
}

# Bootloader Installation
boot() {
    if [ -d /sys/firmware/efi/efivars ]; then
        echo "Detected UEFI system."
        pacman -S --noconfirm grub efibootmgr
        read -p "Is the EFI system partition already mounted? (yes/no): " is_mounted
        if [ "$is_mounted" = "no" ]; then
            read -p "Enter the EFI system partition (e.g., /dev/sda1): " efi_partition
            read -p "Enter the mount point (e.g., /boot/efi): " mount_point
            mount "$efi_partition" "$mount_point"
        else
            read -p "Enter the existing mount point (e.g., /boot/efi): " mount_point
        fi
        grub-install --target=x86_64-efi --efi-directory="$mount_point" --bootloader-id=GRUB
    else
        echo "Detected BIOS system."
        pacman -S --noconfirm grub
        read -p "Enter the disk where GRUB should be installed (e.g., /dev/sda): " disk
        grub-install --target=i386-pc "$disk"
    fi
    grub-mkconfig -o /boot/grub/grub.cfg
    echo "GRUB installation completed successfully."
}

# User Setup
setup_user() {
    read -p "Enter the username for the new user: " username
    read -sp "Enter the password for the new user: " password
    echo
    read -p "Should this user be a sudoer (wheel group)? (yes/no): " is_sudoer
    read -p "Add the user to additional groups (comma separated, e.g., audio,video): " additional_groups

    # Create the user and set the password
    useradd -m -G wheel "$username"
    echo "$username:$password" | chpasswd

    if [ "$is_sudoer" = "yes" ]; then
        # Ensure the wheel group has sudo privileges
        if ! grep -q "%wheel ALL=(ALL) ALL" /etc/sudoers; then
            echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
        fi
    fi

    # Add user to additional groups
    IFS=, read -r -a groups <<< "$additional_groups"
    for group in "${groups[@]}"; do
        usermod -aG "$group" "$username"
    done

    echo "User $username has been created and configured."
}

# Display Desktop Environment Installation Menu
echo "Select a Desktop Environment to install:"
echo "1) Deepin"
echo "2) GNOME"
echo "3) KDE Plasma"
echo "4) Cinnamon"
echo "5) None"

read -p "Enter your choice [1-5]: " choice

if [ "$choice" -ge 1 ] && [ "$choice" -le 4 ]; then
    install_de $choice
elif [ "$choice" == 5 ]; then
    echo "Skipping Desktop Environment installation."
else
    echo "Invalid choice. Exiting."
    exit 1
fi

boot

# Setup User
setup_user

# Additional Packages
read -p "Add any other packages you might want to install here: " packages_user
pacman -Syu --noconfirm $packages_user
