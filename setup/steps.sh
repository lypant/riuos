#!/bin/bash
#===============================================================================
# FILE:         steps.sh
#
# USAGE:        Include in other scripts, e.g. source steps.sh
#
# DESCRIPTION:  Defines but does not execute functions that can be used
#               in other scripts.
#               A step is a complete set of commands that are needed to achieve
#               given task, like adding a user, installing an application, etc.
# REQUIRED
# VARIABLES:    LOG_FILE - path to a file used for logging
#===============================================================================

# Treat unset variables as an error when peforming parameter expansion
# Exit immediately on errors
set -o nounset -o errexit

# Include functions definitions
source functions.sh

#-------------------------------------------------------------------------------
# Configuration variables
#-------------------------------------------------------------------------------

#---------------------------------------
# Disks, partitions and file systems
#---------------------------------------

SYSTEM_HDD=sda

MBR_PART_NB=1
MBR_PART_SIZE=+2M

BOOT_PART_NB=2
BOOT_PART_SIZE=+128M
BOOT_PART_FS=ext2

SWAP_PART_NB=3
SWAP_PART_SIZE=+1G

ROOT_PART_NB=4
ROOT_PART_SIZE=""
ROOT_PART_FS=ext4

#---------------------------------------
# Stage3 tarball
#---------------------------------------

S3_URL=http://distfiles.gentoo.org/releases/x86/autobuilds/current-install-x86-minimal
S3_TARBALL=""   # Empty - autodetect

#---------------------------------------
# Compilation options
#---------------------------------------

CFLAGS="-march=pentium2 -mno-accumulate-outgoing-args -mno-fxsr -mno-sahf -O2"
MAKEOPTS="-j2"

#---------------------------------------
# Profile
#---------------------------------------

#PROFILE="desktop"
PROFILE="13.0"

#---------------------------------------
# Use flags
#---------------------------------------

USE_FLAGS=""    # No special needs at the moment

#---------------------------------------
# Locales
#---------------------------------------

LOCALE="en_US.utf8"

#---------------------------------------
# Kernel
#---------------------------------------

ARCH="i386"

#---------------------------------------
# Ethernet interface
#---------------------------------------

ETHERNET="enp0s12"

#-------------------------------------------------------------------------------
# Base system installation
#-------------------------------------------------------------------------------

#---------------------------------------
# Preparations
#---------------------------------------

createLogDir()
{
    local logDir="../logs"

    # Use plain commands and simple echo since log dir
    # needed for "log", "cmd" does not exist yet

    mkdir -p $logDir
    if [[ "$?" -ne 0 ]]; then
        echo "Failed to create log dir $logDir"
        echo "Aborting script!"
        exit 1
    fi
}

#---------------------------------------
# Disks, partitions and file systems
#---------------------------------------

checkInitialPartitionsCount()
{
    local hdd="/dev/$SYSTEM_HDD"

    log "Check initial partitions count..."
    checkPartitionsCount $hdd 0
    log "Check initial partition counts...done"
}

createMbrPartition()
{
    log "Create MBR partition..."
    createPartition /dev/$SYSTEM_HDD p $MBR_PART_NB "$MBR_PART_SIZE" 83
    log "Create MBR partition...done"
}

createBootPartition()
{
    log "Create boot partition..."
    createPartition /dev/$SYSTEM_HDD p $BOOT_PART_NB "$BOOT_PART_SIZE" 83
    log "Create boot partition...done"
}

createSwapPartition()
{
    log "Create swap partition..."
    createPartition /dev/$SYSTEM_HDD p $SWAP_PART_NB "$SWAP_PART_SIZE" 82
    log "Create swap partition...done"
}

createRootPartition()
{
    log "Create root partition..."
    createPartition /dev/$SYSTEM_HDD p $ROOT_PART_NB "$ROOT_PART_SIZE" 83
    log "Create root partition...done"
}

checkCreatedPartitionsCount()
{
    local hdd="/dev/$SYSTEM_HDD"

    log "Check created partitions..."
    checkPartitionsCount $hdd 4
    log "Check created partitions...done"
}

setBootPartitionBootable()
{
    log "Set boot partition bootable..."
    setPartitionBootable /dev/$SYSTEM_HDD $BOOT_PART_NB
    log "Set boot partition bootable...done"
}

createBootFileSystem()
{
    log "Create boot file system..."
    cmd "mkfs.$BOOT_PART_FS /dev/$SYSTEM_HDD$BOOT_PART_NB"
    log "Create boot file system...done"
}

createSwap()
{
    log "Create swap..."
    cmd "mkswap /dev/$SYSTEM_HDD$SWAP_PART_NB"
    log "Create swap...done"
}

activateSwap()
{
    log "Activate swap..."
    cmd "swapon /dev/$SYSTEM_HDD$SWAP_PART_NB"
    log "Activate swap...done"
}

createRootFileSystem()
{
    log "Create root file system..."
    cmd "mkfs.$ROOT_PART_FS /dev/$SYSTEM_HDD$ROOT_PART_NB"
    log "Create root file system...done"
}

mountRootPartition()
{
    log "Mount root partition..."
    cmd "mount /dev/$SYSTEM_HDD$ROOT_PART_NB /mnt/gentoo"
    log "Mount root partition...done"
}

mountBootPartition()
{
    local mntPnt="/mnt/gentoo/boot"

    log "Mount boot partition..."
    cmd "mkdir $mntPnt"
    cmd "mount /dev/$SYSTEM_HDD$BOOT_PART_NB $mntPnt"
    log "Mount boot partition...done"
}

unmountBootPartition()
{
    log "Unmount boot partition..."
    cmd "umount  /mnt/gentoo/boot"
    log "Unmount boot partition...done"
}

unmountRootPartition()
{
    log "Unmount root partition..."
    cmd "umount  /mnt/gentoo"
    log "Unmount root partition...done"
}

getStage3Tarball()
{
    local regEx=stage3-i686-[0-9]*.tar.bz2
    local dstDir=/mnt/gentoo
    local remoteTarball=""
    local localTarball=""
    local remoteDigests=""
    local localDigests=""
    local expectedHash=""
    local calculatedHash=""

    log "Get stage3 tarball..."

    # Check/get tarball file name
    if [[ -z "$S3_TARBALL" ]]; then
        # If name of tarball was not configured explicitly - obtain one from web
        S3_TARBALL=$(curl -sL $S3_URL | grep -o $regEx | head -n 1)
        log "Using current stage3 tarball found in web: $S3_TARBALL"
    else
        log "Using stage3 tarball specified in config variable: $S3_TARBALL"
    fi

    log "Downloading stage3 tarball file"
    remoteTarball=$S3_URL/$S3_TARBALL
    localTarball=$dstDir/$S3_TARBALL
    downloadFile $remoteTarball $localTarball

    log "Downloading stage3 tarball digest file"
    remoteDigests=$remoteTarball.DIGESTS
    localDigests=$dstDir/$S3_TARBALL.DIGESTS
    downloadFile $remoteDigests $localDigests

    log "Verifying tarball integrity"
    expectedHash=`grep $S3_TARBALL $localDigests | head -n 1 | awk '{print $1;}'`
    calculatedHash=`sha512sum $localTarball | awk '{print $1;}'`
    if [[ "$expectedHash" == "$calculatedHash" ]];then
        log "Tarball hash ok"
    else
        log "Calculated hash $calculatedHash is different than expected hash $expectedHash; aborting"
        exit 1
    fi

    log "Unpack stage3 tarball"
    # TODO Consider removing verbosity flag from tar for less clugged output
    cmd "tar xvjpf $localTarball -C $dstDir --xattrs"

    log "Remove tarball file"
    cmd "rm $localTarball"

    log "Remove digests file"
    cmd "rm $localDigests"

    log "Get stage3 tarball...done"
}

setCompilationOptions()
{
    local file=/mnt/gentoo/etc/portage/make.conf

    log "Set compilation options..."
    log "Replace CFLAGS"
    replaceVarValueQuoted CFLAGS $file "$CFLAGS"
    log "Set MAKEOPTS"
    cmd "echo \"MAKEOPTS=\\\"$MAKEOPTS\\\"\" >> $file"
    log "Set compilation options...done"
}

selectMirrors()
{
    local file=/mnt/gentoo/etc/portage/make.conf
    local servers="rsync://gentoo.prz.rzeszow.pl/gentoo"
    local servers="$servers http://gentoo.prz.rzeszow.pl"
    local servers="$servers rsync://ftp.vectranet.pl/gentoo/"
    local servers="$servers ftp://ftp.vectranet.pl/gentoo/"
    local servers="$servers http://ftp.vectranet.pl/gentoo/"

    log "Select mirrors..."
    cmd "echo \"GENTOO_MIRRORS=\\\"$servers\\\"\" >> $file"
    log "Select mirrors...done"
}

selectMirrorsAutomatically()
{
    log "Select mirrors automatically..."
    cmd "mirrorselect -c Poland -s 3 -o >> /mnt/gentoo/etc/portage/make.conf"
    log "Select mirrors automatically...done"
}

setupGentooRepos()
{
    local dir=/mnt/gentoo/etc/portage/repos.conf
    local src=/mnt/gentoo/usr/share/portage/config/repos.conf
    local dst=/mnt/gentoo/etc/portage/repos.conf/gentoo.conf

    log "Setup Gentoo repos..."
    cmd "mkdir -p $dir"
    cmd "cp $src $dst"
    log "Setup Gentoo repos...done"
}

copyDnsInfo()
{
    local src=/etc/resolv.conf
    local dst=/mnt/gentoo/etc/

    log "Copy DNS info..."
    cmd "cp -L $src $dst"
    log "Copy DNS info...done"
}

mountLiveFilesystems()
{
    local fs=""

    log "Mount live filesystems..."

    fs=/mnt/gentoo/proc
    cmd "mount -t proc proc $fs"

    fs=/mnt/gentoo/sys
    cmd "mount --rbind /sys $fs"

    fs=/mnt/gentoo/sys
    cmd "mount --make-rslave $fs"

    fs=/mnt/gentoo/dev
    cmd "mount --rbind /dev $fs"

    fs=/mnt/gentoo/dev
    cmd "mount --make-rslave $fs"

    log "Mount live filesystems...done"
}

installPortageSnapshot()
{
    log "Install Portage snapshot..."
    gentooChroot "emerge-webrsync"
    log "Install Portage snapshot...done"
}

selectProfile()
{
    local chrootedFile="/tmp/profile"
    local file="/mnt/gentoo$chrootedFile"
    local profileNb=0

    log "Select profile..."

    log "Find profile nb"
    findProfile $PROFILE $chrootedFile

    if [[ -s "$file" ]]; then
        profileNb=$(<$file)
        log "Setting profile $profileNb - $PROFILE"
        gentooChroot "eselect profile set $profileNb"
    else
        log "Profile $PROFILE not found; available profiles:"
        gentooChroot "eselect profile list"
        exit 1
    fi

    gentooChroot "eselect profile list"

    log "Select profile...done"
}

setUseFlags()
{
    local file="/mnt/gentoo/etc/portage/make.conf"

    log "Set use flags..."
    replaceVarValueQuoted USE $file "$USE_FLAGS"
    log "Set use flags...done"
}

updateWorldSet()
{
    log "Update world set..."
    gentooChroot "emerge --update --deep --newuse @world"
    log "Update world set...done"
}

setTimeZone()
{
    log "Set time zone..."

    log "Set zone"
    gentooChroot "echo 'Europe/Warsaw' > /etc/timezone"

    log "Reconfigure sys-libs/timezone-data package"
    gentooChroot "emerge --config sys-libs/timezone-data"

    log "Set time zone...done"
}

setLocales()
{
    local localesFile="/mnt/gentoo/etc/locale.gen"
    local chrootedFile="/tmp/locale"
    local file="/mnt/gentoo$chrootedFile"
    local localeNb=0

    log "Set locales..."

    log "Uncomment en_US locale"
    uncommentVar en_US $localesFile

    log "Uncomment en_US.UTF-8 locale"
    uncommentVar en_US.UTF-8 $localesFile

    log "Append pl_PL locale"
    cmd "echo 'pl_PL.UTF-8 UTF-8' >> $localesFile"

    log "Generate locales"
    gentooChroot "locale-gen"

    log "Find locale nb"
    findLocale $LOCALE $chrootedFile

    if [[ -s "$file" ]]; then
        localeNb=$(<$file)
        log "Setting locale $localeNb - $LOCALE"
        gentooChroot "eselect locale set $localeNb"
    else
        log "Locale $LOCALE not found; available locales:"
        gentooChroot "eselect locale list"
        exit 1
    fi

    gentooChroot "eselect locale list"

    log "Update environment"
    gentooChroot "env-update"

    log "Set locales...done"
}

installKernelSources()
{
    log "Install kernel sources..."
    gentooChroot "emerge sys-kernel/gentoo-sources"
    log "Install kernel sources...done"
}

generateDefaultKernelConfig()
{
    log "Generate default kernel config..."
    gentooChroot "make -C /usr/src/linux ${ARCH}_defconfig"
    log "Generate default kernel config...done"
}

compileKernel()
{
    log "Compile kernel..."
    gentooChroot "make -C /usr/src/linux"
    log "Compile kernel...done"
}

installKernelModules()
{
    log "Install kernel modules..."
    gentooChroot "make -C /usr/src/linux modules_install"
    log "Install kernel modules...done"
}

installKernel()
{
    log "Install kernel..."
    gentooChroot "make -C /usr/src/linux install"
    log "Install kernel...done"
}

# Needed for initramfs generation
installGenkernel()
{
    log "Install genkernel..."
    gentooChroot "emerge sys-kernel/genkernel"
    log "Install genkernel...done"
}

buildInitramfs()
{
    log "Build initramfs..."
    gentooChroot "genkernel --install initramfs"
    log "Build initramfs...done"
}

installFirmware()
{
    log "Install firmware..."
    gentooChroot "emerge sys-kernel/linux-firmware"
    log "Install firmware...done"
}

configureFstab()
{
    log "Configure fstab..."
    # Backup default fstab just for safety
    cmd "mv /mnt/gentoo/etc/fstab /mnt/gentoo/etc/fstab.default"
    # Do not add entry for MBR on /dev/sda1
    addFstabEntry /dev/sda2  /boot       ext2 noauto,noatime 0 2
    addFstabEntry /dev/sda3  none        swap sw             0 0
    addFstabEntry /dev/sda4  /           ext4 noatime        0 1
    addFstabEntry /dev/cdrom /mnt/cdrom  auto noauto,ro      0 0
    addFstabEntry /dev/fd0   /mnt/floppy auto noauto         0 0
    log "Configure fstab...done"
}

setHostname()
{
    log "Set hostname..."
    replaceVarValueQuoted "hostname" "/mnt/gentoo/etc/conf.d/hostname" "robco"
    log "Set hostname...done"
}

# Needed for networking
installNetifrc()
{
    log "Install netifrc..."
    gentooChroot "emerge --noreplace net-misc/netifrc"
    log "Install netifrc...done"
}

setDhcp()
{
    log "Set dhcp..."
    cmd "echo config_${ETHERNET}=\"dhcp\" >> /mnt/gentoo/etc/conf.d/net"
    log "Set dhcp...done"
}

setNetworkStarting()
{
    local common="/etc/init.d"
    local target="$common/net.lo"
    local linkFile="net.$ETHERNET"
    local link="$common/$linkFile"

    log "Set network starting..."
    gentooChroot "ln -s $target $link"
    gentooChroot "rc-update add $linkFile default"
    log "Set network starting...done"
}

setRootPassword()
{
    local ask=1

    log "Set root password..."

    # Disable exit on error - to get a chance of correcting misspelled password
    set +o errexit
    while [ $ask -ne 0 ]; do
        gentooChroot "passwd"
        ask=$?
    done
    # Enable exiting on error again
    set -o errexit

    log "Set root password...done"
}

setKeymap()
{
    log "Set keymap..."
    replaceVarValueQuoted "keymap" "/mnt/gentoo/etc/conf.d/keymaps" "pl"
    log "Set keymap...done"
}

