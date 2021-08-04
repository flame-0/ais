#!/bin/bash

read -p "Disk: " DISK
read -p "Swap size: " SWAP_SIZE
read -p "Hostname: " HOSTNAME
read -p "Timezone: " TIMEZONE
read -p "Root password: " ROOT_PASSWORD
read -p "Username: " USERNAME
read -p "Password: " PASSWORD

# Update the system clock
timedatectl set-ntp true

# Partition the disk
fdisk ${DISK} << EOF
o
n
p
1

${SWAP_SIZE}
t
82
n
p
2


a
2
w
EOF

# Format the partition
mkfs.ext4 ${DISK}2
mkswap ${DISK}1

# Mount the file systems
mount ${DISK}2 /mnt
swapon ${DISK}1

# Install base and essential packages
pacstrap /mnt base linux linux-firmware base-devel amd-ucode xf86-video-amdgpu networkmanager grub os-prober ntfs-3g xdg-user-dirs nano xorg xorg-xinit

# Fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot
arch-chroot /mnt

# Time Zone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Localization
sed -i '/#en_US.UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf

# Network Configuration
echo ${HOSTNAME} > /etc/hostname
echo -e "127.0.0.1 localhost" >> /etc/hosts
echo -e "::1       localhost" >> /etc/hosts
echo -e "127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}" >> /etc/hosts
systemctl enable NetworkManager

# Initramfs
sed -i '/MODULES=()/s/)$/amdgpu)/g' /etc/mkinitcpio.conf
mkinitcpio -p linux

# Root Password
echo root:${ROOT_PASSWORD} | chpasswd

# Boot Loader
grub-install --target=i386-pc ${DISK}
sed -i '/GRUB_DEFAULT=0/s/0$/2/g' /etc/default/grub
sed -i '/GRUB_TIMEOUT=5/s/5$/20/g' /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX=""/s/"$/"\nGRUB_DISABLE_OS_PROBER=false/g' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# User Permissions

# Create User Account
useradd ${USERNAME} -m -g users -G wheel,lp,audio,storage,video,network,power -s /bin/bash
echo ${USERNAME}:${PASSWORD} | chpasswd

# Reboot
exit
umount -R /mnt
reboot
