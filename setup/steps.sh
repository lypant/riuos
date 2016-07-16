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

