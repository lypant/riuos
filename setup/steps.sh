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
    # needed for "log", "cmd" and "err" does not exist yet

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
    err "$?" "$FUNCNAME" "Disk $hdd does not have expected partitions count"
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
    err "$?" "$FUNCNAME" "Disk $hdd does not contain required partitions"
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
    err "$?" "$FUNCNAME" "failed to create boot file system"
    log "Create boot file system...done"
}

createSwap()
{
    log "Create swap..."
    cmd "mkswap /dev/$SYSTEM_HDD$SWAP_PART_NB"
    err "$?" "$FUNCNAME" "failed to create swap"
    log "Create swap...done"
}

activateSwap()
{
    log "Activate swap..."
    cmd "swapon /dev/$SYSTEM_HDD$SWAP_PART_NB"
    err "$?" "$FUNCNAME" "failed to activate swap"
    log "Activate swap...done"
}

createRootFileSystem()
{
    log "Create root file system..."
    cmd "mkfs.$ROOT_PART_FS /dev/$SYSTEM_HDD$ROOT_PART_NB"
    err "$?" "$FUNCNAME" "failed to create root file system"
    log "Create root file system...done"
}

mountRootPartition()
{
    log "Mount root partition..."
    cmd "mount /dev/$SYSTEM_HDD$ROOT_PART_NB /mnt/gentoo"
    err "$?" "$FUNCNAME" "failed to mount root partition"
    log "Mount root partition...done"
}

mountBootPartition()
{
    local mntPnt="/mnt/gentoo/boot"

    log "Mount boot partition..."
    cmd "mkdir $mntPnt"
    err "$?" "$FUNCNAME" "failed to create boot partition mount point $mntPnt"
    cmd "mount /dev/$SYSTEM_HDD$BOOT_PART_NB $mntPnt"
    err "$?" "$FUNCNAME" "failed to mount root partition"
    log "Mount boot partition...done"
}

unmountBootPartition()
{
    log "Unmount boot partition..."
    cmd "umount  /mnt/gentoo/boot"
    err "$?" "$FUNCNAME" "failed to unmount boot partition"
    log "Unmount boot partition...done"
}

unmountRootPartition()
{
    log "Unmount root partition..."
    cmd "umount  /mnt/gentoo"
    err "$?" "$FUNCNAME" "failed to unmount root partition"
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
        err "1" "$FUNCNAME" "Calculated hash $calculatedHash is different than expected hash $expectedHash"
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
    replaceVarValue CFLAGS $file "$CFLAGS"
    err "$?" "$FUNCNAME" "failed to set CFLAGS in $file"
    cmd "echo \"MAKEOPTS=\\\"$MAKEOPTS\\\"\" >> $file"
    err "$?" "$FUNCNAME" "failed to add MAKEOPTS to $file"
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
    err "$?" "$FUNCNAME" "failed to select mirrors"
    log "Select mirrors...done"
}

setupGentooRepos()
{
    local dir=/mnt/gentoo/etc/portage/repos.conf
    local src=/mnt/gentoo/usr/share/portage/config/repos.conf
    local dst=/mnt/gentoo/etc/portage/repos.conf/gentoo.conf

    log "Setup Gentoo repos..."
    cmd "mkdir -p $dir"
    err "$?" "$FUNCNAME" "failed to create repos directory $dir"
    cmd "cp $src $dst"
    err "$?" "$FUNCNAME" "failed to copy Gentoo repos from $src to $dst"
    log "Setup Gentoo repos...done"
}

copyDnsInfo()
{
    local src=/etc/resolv.conf
    local dst=/mnt/gentoo/etc/

    log "Copy DNS info..."
    cmd "cp -L $src $dst"
    err "$?" "$FUNCNAME" "failed to copy DNS info from $src to $dst"
    log "Copy DNS info...done"
}

mountLiveFilesystems()
{
    local fs=""

    log "Mount live filesystems..."

    fs=/mnt/gentoo/proc
    cmd "mount -t proc proc $fs"
    err "$?" "$FUNCNAME" "failed to mount $fs"

    fs=/mnt/gentoo/sys
    cmd "mount --rbind /sys $fs"
    err "$?" "$FUNCNAME" "failed to rbind $fs"

    fs=/mnt/gentoo/sys
    cmd "mount --make-rslave $fs"
    err "$?" "$FUNCNAME" "failed to make rslave $fs"

    fs=/mnt/gentoo/dev
    cmd "mount --rbind /dev $fs"
    err "$?" "$FUNCNAME" "failed to rbind $fs"

    fs=/mnt/gentoo/dev
    cmd "mount --make-rslave $fs"
    err "$?" "$FUNCNAME" "failed to make rslave $fs"

    log "Mount live filesystems...done"
}

chroot()
{
    log "Chroot..."

    cmd "chroot /mnt/gentoo /bin/bash"
    err "$?" "$FUNCNAME" "failed to chroot"

    cmd "source /etc/profile"
    err "$?" "$FUNCNAME" "failed to load /etc/profile"

    log "Chroot...done"
}

