#!/bin/bash

disk=""
hostname=""
timezone=""
username=""

# Update the system clock
timedatectl set-ntp true

# Partition the disk
fdisk ${disk} << EOF
o
n
p
1

+8192M
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
mkfs.ext4 ${disk}2
mkswap ${disk}1

# Mount the file systems
mount ${disk}2 /mnt
swapon ${disk}1

# Install base and essential packages
pacstrap /mnt base linux linux-firmware base-devel amd-ucode xf86-video-amdgpu networkmanager grub os-prober ntfs-3g xdg-user-dirs nano xorg xorg-xinit

# Fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot
arch-chroot /mnt

# Time Zone
ln -sf /usr/share/zoneinfo/${timezone} /etc/localtime
hwclock --systohc

# Localization
sed -i '/#en_US.UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf

# Network Configuration
echo ${hostname} > /etc/hostname
echo -e "127.0.0.1\tlocalhost" >> /etc/hosts
echo -e "::1\t\tlocalhost" >> /etc/hosts
echo -e "127.0.1.1\t${hostname}.localdomain\t${hostname}" >> /etc/hosts
systemctl enable NetworkManager

# Initramfs
sed -i '/MODULES=()/s/)$/amdgpu)/g' /etc/mkinitcpio.conf
mkinitcpio -p linux

# Root Password
passwd

# Boot Loader
grub-install --target=i386-pc ${disk}
sed -i '/GRUB_DEFAULT=0/s/0$/2/g' /etc/default/grub
sed -i '/GRUB_TIMEOUT=5/s/5$/20/g' /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX=""/s/"$/"\nGRUB_DISABLE_OS_PROBER=false/g' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# User Permissions

# Create User Account
useradd ${username} -m -g users -G wheel,lp,audio,storage,video,network,power -s /bin/bash
passwd ${username}


# Reboot
exit
umount -R /mnt
reboot
