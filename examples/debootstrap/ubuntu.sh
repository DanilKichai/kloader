#!/usr/bin/env bash

source "/archshell/include/fatal.sh"

BLKDEV="$(
    for dev in $(ls /sys/block); do
        echo -n "$dev"
        break
    done
)"

echo "Hello! Installing Ubuntu on the first found block device: \"$BLKDEV\"..."

HEAD="$(
    head --bytes=4096 "/dev/$BLKDEV" | \
        base64 --wrap=0 | \
            gzip -9 | \
                base64 --wrap=0
)"

NULL="H4sIAAAAAAACA+3BsQAAAAACMLKO/KVSCGBbCwAAAADALxkQEyzgWBUAAA=="

[[ "$HEAD" = "$NULL" ]] || \
    fatal "The block device \"$BLKDEV\" is not clean!"

sfdisk "/dev/$BLKDEV"<<EOF
label: gpt
unit: sectors
first-lba: 2048
sector-size: 512
: start=    2048, size= 2097152, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
: start= 2099200,                type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF
[[ "$?" -ne 0 ]] && \
    fatal "Could not partition the block device!"

export ESP="$(
    lsblk \
        "/dev/$BLKDEV" \
        --output NAME,TYPE \
        --raw \
        --noheadings | \
            awk '{
                if ($2 == "part" && NR == 2) {
                    print $1
                }
            }'
)"

export ROOT="$(
    lsblk \
        "/dev/$BLKDEV" \
        --output NAME,TYPE \
        --raw \
        --noheadings | \
            awk '{
                if ($2 == "part" && NR == 3) {
                    print $1
                }
            }'
)"

mkfs.vfat "/dev/$ESP" -I || \
    fatal "Could not format the ESP partition: \"$ESP\"!"

mkfs.ext4 "/dev/$ROOT" -F || \
    fatal "Could not format the ROOT partition: \"$ROOT\"!"

mount "/dev/$ROOT" /mnt || \
    fatal "Could not mount the ROOT partition: \"$ROOT\"!"

mkdir --parents /mnt/boot/efi || \
    fatal "Could not prepare the target directory structure!"

mount "/dev/$ESP" /mnt/boot/efi || \
    fatal "Could not mount the ESP partition!"

debootstrap noble /mnt https://mirror.clearsky.vn/ubuntu || \
    fatal "Could not bootstrap debian!"

arch-chroot /mnt /bin/bash -c '
    set -e

    export DEBIAN_FRONTEND=noninteractive
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    apt-get --yes update
    apt-get --yes upgrade
    apt-get --yes install --no-install-recommends \
        linux-generic \
        grub-efi-amd64

    grub-install \
        --efi-directory="/boot/efi" \
        --no-bootsector
    update-grub

    echo -e "ubuntu\nubuntu" | passwd
' || fatal "Could not prepare the target!"

genfstab /mnt -U >/mnt/etc/fstab || \
    fatal "Could not render the target fstab!"

umount /mnt/boot/efi || \
    fatal "Could not unmount: \"/mnt/boot/efi\"!"

umount /mnt || \
    fatal "Could not unmount: \"/mnt\"!"

fatal "Installation complete!"
