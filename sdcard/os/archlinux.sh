
# First invoked by sdcard/write
mountpartitions(){
    # Partition the sd card
    case $MACHINENAME in
        rpi|rpi-2|rpi-3|parallella)
            twopartitionformat 100;; # Make 100 MB fat partition for the RPi
        cubietruck|bananapro|odroid-c2)
            onepartitionformat;;
        *)
            exit;;
    esac
}

# Invoked by sdcard/write
initos(){
    case $MACHINENAME in
        rpi|rpi-2|rpi-3|parallella)
            generaldownload
            move_boot;;
        odroid-c2)
            generaldownload;;
        cubietruck|bananapro)
            allwinnerdownload;;
        *)
            exit;;
    esac
}

# Invoked by sdcard/write
cleanup(){
    case $MACHINENAME in
        rpi|rpi-2|rpi-3|parallella)
            umount_boot_and_root;;
        cubietruck|bananapro)
            umount_root;;
        odroid-c2)
            write_boot_loader_and_umount_root;;
        *)
            exit;;
    esac
}

checkrootfs(){

    # Arch Linux supports these root filesystems
    if [[ ${ROOTFSNAME} != "docker-multinode" ]]; then
        echo "archlinux does only work with docker-multinode"
        exit
    fi
}


## ------------------------- PARTITION AND DOWNLOAD THE OS --------------------------------

# Format the SD Card with two partitions, boot and root. Boot is $1 MB big.
# This makes the root partition as big as the sd card minus boot
twopartitionformat(){

    # Here we "press" the keys in order, commanding fdisk to make a partition
    echo "Now $SDCARD is going to be partitioned."
    fdisk $SDCARD <<EOF
o
p
n
p
1

+${1}M
t
c
n
p
2


w
EOF

    # Require mkfs.vfat
    require mkfs.vfat dosfstools

    # Make boot filesystem
    mkfs.vfat $PARTITION1

    # Mount partition 1 to boot, for editing
    mount $PARTITION1 $BOOT

    # Make root filesystem, answer y to if we want to overwrite the ext4 partition
    mkfs.ext4 $PARTITION2 <<EOF
y
EOF

    # Mount partition 2 to root, for editing
    mount $PARTITION2 $ROOT
}


# Download the OS, and redirect the tar warnings to the log
generaldownload(){
    ARCH_BOARD=$MACHINENAME
    if [[ $MACHINENAME == "rpi-3" ]]; then
        ARCH_BOARD="rpi-2"
    fi

    # Download, redirect stderr (all errors) to stdout, which in turn is appended to a log file
    curl -sSL -k http://archlinuxarm.org/os/ArchLinuxARM-${ARCH_BOARD}-latest.tar.gz | tar -xz -C $ROOT >> $LOGFILE 2>&1

    sync
}

move_boot(){
    echo "Moving boot files to boot partition"
    # Move /boot to separate partition
    mv $ROOT/boot/* $BOOT
}

# Umount both root and boot on a RPi for example
umount_boot_and_root(){
    umount $BOOT $ROOT
}



# Cubietruck guide: http://archlinuxarm.org/platforms/armv7/allwinner/cubietruck
# All the commands copied from there
onepartitionformat(){

    fdisk $SDCARD <<EOF
o
p
n
p
1
2048

w
EOF

    mkfs.ext4 $PARTITION1 <<EOF
y
EOF
    # Mount partition 1 to root, for editing
    mount $PARTITION1 $ROOT
}

allwinnerdownload(){
    # Download, redirect stderr (all errors) to stdout, which in turn is appended to a log file
    curl -sSL -k http://archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz | tar -xz -C $ROOT >> $LOGFILE 2>&1

    sync

    if [[ $MACHINENAME == "cubietruck" ]]; then
        curl -sSL http://archlinuxarm.org/os/sunxi/boot/cubietruck/u-boot-sunxi-with-spl.bin > $TMPDIR/u-boot-sunxi-with-spl.bin
    elif [[ $MACHINENAME == "bananapro" ]]; then
        curl -sSL https://github.com/luxas/kubernetes-on-arm/releases/download/v0.6.0/banana-u-boot-sunxi-with-spl.bin > $TMPDIR/u-boot-sunxi-with-spl.bin
    fi

    dd if=$TMPDIR/u-boot-sunxi-with-spl.bin of=$SDCARD bs=1024 seek=8

    curl -sSL http://archlinuxarm.org/os/sunxi/boot/cubietruck/boot.scr > $ROOT/boot/boot.scr
}

umount_root(){
    umount $ROOT
}

write_boot_loader_and_umount_root(){
    CURRDIR=`pwd`
    cd $ROOT/boot

    # Flash the bootloader files
    ./sd_fusing.sh $SDCARD
    cd $CURRDIR

    umount_root
}
