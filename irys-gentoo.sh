#!/bin/bash

# Basic validation to make sure we are running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

# Check if internet connection is available
echo "Checking internet connection..."
ping -c 1 google.com &>/dev/null
if [ $? -ne 0 ]; then
    echo "No internet connection. Please check your network settings."
    exit 1
fi

# Asking for the disk to install Gentoo
echo "Please enter the disk to install Gentoo (e.g., /dev/sda):"
read DISK

# Confirming disk choice
echo "You chose disk: $DISK. Are you sure you want to proceed? (y/n)"
read CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Aborting installation."
    exit 1
fi

# Partitioning the disk
echo "Partitioning disk $DISK..."
# Warning: This will delete all data on the disk.
parted $DISK mklabel gpt
parted $DISK mkpart primary ext4 1MiB 50%
parted $DISK mkpart primary linux-swap 50% 100%

# Format the partitions
echo "Formatting partitions..."
mkfs.ext4 ${DISK}1
mkswap ${DISK}2

# Mount the root partition
echo "Mounting root partition..."
mount ${DISK}1 /mnt/gentoo
swapon ${DISK}2

# Install the stage3 tarball
echo "Downloading and extracting the stage3 tarball..."
cd /mnt/gentoo
links https://bouncer.gentoo.org/fetch/root/all/releases/amd64/autobuilds/latest-stage3-amd64.tar.xz
tar xpvf stage3-*.tar.xz --xattrs --numeric-owner

# Mount necessary filesystems
echo "Mounting necessary filesystems..."
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev

# Chroot into the new system
echo "Chrooting into the new system..."
chroot /mnt/gentoo /bin/bash << 'EOF'
source /etc/profile
export PS1="(chroot) ${PS1}"

# Update the Portage tree
echo "Updating Portage tree..."
emerge --sync

# Set timezone
echo "Setting the timezone..."
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Set locale
echo "Setting locale..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Configure the network
echo "Configuring the network..."
echo "hostname=gentoosystem" > /etc/hostname
# Add other networking setup as needed (for example, DHCP configuration)

# Enable NetworkManager for automatic network management
echo "Enabling NetworkManager service..."
systemctl enable NetworkManager

# Set the root password
echo "Setting the root password..."
passwd

# Install bootloader
echo "Installing bootloader..."
emerge sys-boot/grub
grub-install $DISK
grub-mkconfig -o /boot/grub/grub.cfg

# Install X11
echo "Installing X11..."
emerge x11-base/xorg-server

# Install NVIDIA proprietary drivers
echo "Installing NVIDIA proprietary drivers..."
emerge x11-drivers/nvidia-drivers

# Install Cinnamon Desktop Environment
echo "Installing Cinnamon Desktop Environment..."
emerge xfce-base/cinnamon

# Install a display manager (e.g., LightDM)
echo "Installing LightDM display manager..."
emerge x11-display-manager/lightdm
emerge x11-misc/lightdm-gtk-greeter

# Enable LightDM to start on boot
echo "Enabling LightDM to start on boot..."
systemctl enable lightdm

# Install additional utilities and applications
echo "Installing additional utilities..."
emerge app-editors/vim
emerge net-misc/networkmanager
emerge app-arch/unzip
emerge media-video/vlc
emerge x11-terms/gnome-terminal
emerge app-editors/nano
emerge app-eselect/eselect-opengl

# Install web browser (e.g., Firefox)
echo "Installing Firefox web browser..."
emerge www-client/firefox

# Install genkernel (for automatic kernel configuration)
echo "Installing genkernel for kernel configuration..."
emerge sys-kernel/genkernel

# Configure the kernel
echo "Configuring the kernel..."
genkernel all

# Set up a basic user
echo "Setting up a basic user..."
useradd -m -G users,wheel -s /bin/bash yourusername
echo "yourusername:yourpassword" | chpasswd

# Install sudo for user privileges
echo "Installing sudo..."
emerge app-admin/sudo
echo "yourusername ALL=(ALL) ALL" >> /etc/sudoers

# Set up basic system services
echo "Enabling necessary system services..."
systemctl enable syslog-ng
systemctl enable cronie

# Clean up and finalize
echo "Finalizing system setup..."

# Allow the system to boot into the new environment
EOF

# Exit chroot and unmount filesystems
echo "Exiting chroot and unmounting filesystems..."
exit
umount -R /mnt/gentoo

# Finishing up
echo "Gentoo installation is complete! You can now reboot into your system."
echo "Your system has been configured with NetworkManager, the NVIDIA drivers, Cinnamon desktop, and genkernel for automatic kernel management."
echo "Ensure to reboot and log in as 'yourusername' to start using your Gentoo system."
