#!/bin/bash

# Proxmox version to download and the ISO's sha256sum for verification.
proxmox_version="proxmox-ve_7.4-1"
proxmox_iso_sha256sum="55b672c4b0d2bdcbff9910eea43df3b269aaab3f23e7a1df18b82d92eb995916"

# Set the graphical installer's screen resolution.
installer_screen_resolution="800x600"

# Install some tools.
apt-get install -y curl ctorrent xorriso

# Download the ISO over BitTorrent
torrent_url=$(curl -Ls https://www.proxmox.com/en/downloads | grep "Download ${proxmox_version}.torrent" | egrep -o 'href="[^"]+"' | head -n1 | sed -re 's;href=";https://www.proxmox.com;' -e 's/&amp;/\&/g' -e 's;"$;;' -e 's;args\[0\];args[];')
curl -Ls "$torrent_url" -o /root/${proxmox_version}.torrent
cd /root && ctorrent -e 0 -p 2706 /root/${proxmox_version}.torrent </dev/null

# Check the sha256sum.
sha256sum /root/${proxmox_version}.iso 2>&1 | grep $proxmox_iso_sha256sum >/dev/null 2>&1
if [ $? -eq 0 ] ; then
  echo "SHA256SUM matches - OK"
else
  echo "SHA256SUM does not match - Aborting!"
  exit 1
fi

# Copy the ISO's /boot/initrd.img.
mkdir /mnt/proxmox && mount -o loop,ro /root/${proxmox_version}.iso /mnt/proxmox
mkdir /root/initrd && cp -a /mnt/proxmox/boot/initrd.img /root/initrd.img.original
umount /mnt/proxmox

# Decompress and extract the initrd.img.
zstd -d /root/initrd.img.original -o /root/initrd.img.original.cpio
cd /root/initrd && cpio -i </root/initrd.img.original.cpio

# Copy the ISO file into the extracted initrd directory.
cp /root/${proxmox_version}.iso /root/initrd/proxmox.iso
chmod 444 /root/initrd/proxmox.iso

# Repack the initrd.img.
tmp=$(mktemp)
cd /root/initrd
find . >$tmp
cpio -o -H newc <$tmp >/root/initrd.img.cpio
cd /root
zstd -z initrd.img.cpio -o initrd.img

# Update the ISO's /boot/initrd.img with our modified initrd.img containing the ISO.
# This is quick and dirty, doubling the size of the ISO to around 2.2 GB (for Proxmox VE 7.4).
xorriso -dev /root/${proxmox_version}.iso -boot_image any keep -boot_image grub partition_table=on -update /root/initrd.img /boot/initrd.img

# Add a grub entry for booting the ISO.
cat <<EOF >/etc/grub.d/40_custom
#!/bin/sh
exec tail -n +3 \$0
# This file provides an easy way to add custom menu entries.  Simply type the
# menu entries you want to add after this comment.  Be careful not to change
# the 'exec tail' line above.
menuentry 'Install Proxmox VE' --class debian --class gnu-linux --class gnu --class os {
        insmod gzio
        insmod iso9660
        loadfont /boot/grub/unicode.pf2
        set gfxmode=${installer_screen_resolution}
        set gfxpayload=${installer_screen_resolution}
        insmod all_video
        loopback loop (hd0,1)/root/${proxmox_version}.iso
        echo    'Loading Proxmox VE Installer ...'
        linux   (loop)/boot/linux26 rd.live.dir=/ rd.live.squashimg=pve-installer.squashfs rd.live.ram=1 rd.info
        echo    'Loading initial ramdisk ...'
        initrd  (loop)/boot/initrd.img
}
EOF

# Update grub and reboot into the ISO LiveCD.
update-grub
grub-reboot "Install Proxmox VE"

# Wait for a moment before rebooting, so the user can briefly review what just happened.
sleep 5
reboot
