#!/bin/bash
#===============================================================================
# FILE:         functions.sh
#
# USAGE:        Include in other scripts, e.g. source functions.sh
#
# DESCRIPTION:  Defines but does not execute functions that can be used
#               in other scripts
# REQUIRED
# VARIABLES:    LOG_FILE - path to a file used for logging
#===============================================================================

# Treat unset variables as an error when peforming parameter expansion
# Exit immediately on errors
set -o nounset -o errexit

#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------

# @brief Writes a message to a screen and to a log file, with the "log:" prefix
# @param message to be logged
# @return status of file logging command
# @example log "Hello world"
log()
{
    # Use message with prefix to distinguish logs generated by setup scripts
    local msg="log: $@"

    # Write message to screen and log file
    (echo "$msg" 2>&1) | tee -a $LOG_FILE
    return ${PIPESTATUS[1]}
}

# @brief Logs a command with "cmd:" prefix and executes it
# @param command to be executed
# @return status of executed command
# @example cmd "echo 'I was printed with cmd function'"
cmd()
{
    # Record command to be executed to the log file
    echo "cmd: $@" >> $LOG_FILE

    # Execute command
    # Redirect stdout and stderr to screen and log file
    (eval "$@" 2>&1) | tee -a $LOG_FILE
    return ${PIPESTATUS[0]}
}

# @brief Checks whether partitions count for given hdd is as expected
# @param path to hdd, without partition number
# @param expected partitions count
# @return 0 when hdd has expected number of partions; 1 otherwise
# @example checkPartitionsCount /dev/sda 3
checkPartitionsCount()
{
    local hdd=$1
    local cnt=$2

    local lines=$(lsblk $hdd | wc -l)
    local ptns=$(($lines - 2))
    local ret=0

    if [[ "$cnt" -ne "$ptns" ]]; then
        log "Wrong partition count on $hdd. Expected:$cnt; found:$ptns"
        ret=1
    fi

    return $ret
}

# @brief Creates a partition on a hdd
# @param path to hdd, without partition number, e.g. /dev/sda
# @param partition type - "p" for primary, "e" for extended
# @param partition number, e.g. "1" for "/dev/sda1"
# @param partition size, e.g. "+1G" for 1 GiB, "" for remaining space
# @param partition code, e.g. "82" for swap, "83" for Linux partition, etc
# @example createPartition /dev/sda p 2 "+128M" 83
createPartition()
{
    local hdd="$1"
    local partType="$2"
    local partNb="$3"
    local partSize="$4"
    local partCode="$5"

    local partCodeNb="" # No partition nb for code setting for 1st partition
    
    # For parititons >1 it is necessary to provide partition number
    if [[ $partNb -ne 1 ]]; then
        partCodeNb=$partNb
    fi

    cat <<-EOF | fdisk $hdd
	n
	$partType
	$partNb
	
	$partSize
	t
	$partCodeNb
	$partCode
	w
	EOF

    # TODO Try to find more elegant solution
    # sync and partprobe did not work to avoid following report:
    # "Re-reading the partition table failed: Device or resource busy"
    sleep 10
}

# @brief Sets bootable flag of the partition to true
# @param path to hdd, without partition number, e.g. /dev/sda
# @param partition number, .e.g. "1" for "/dev/sda1"
# @example setPartitionBootable /dev/sda 2
# @note Best executed when all (at least two) partitions are created
setPartitionBootable()
{
    local hdd="$1"     # e.g. /dev/sda
    local partNb="$2"   # e.g. "1" for "/dev/sda1"

    cat <<-EOF | fdisk $hdd
	a
	$partNb
	w
	EOF
}

# @brief Downloads file from given url and saves it under given destination path
# @param url of source file to be downloaded from web
# @param destination path and file name
# @example downloadFile https://www.archlinux.org/mirrorlist/?country=PL /etc/pacman.d/mirrorlist
# @note creates nested directories in destination path, if necessary
downloadFile()
{
    local url=$1
    local dst=$2

    log "Downloading file from $url to $dst..."
    cmd "curl -LSo $dst --create-dirs $url"
    log "Downloading file from $url to $dst...done"
}

# @brief Replaces old value of var with new one, for all instances in a file
# @param variable name to be located in file
# @param file storing variable to be modified
# @param new value of the variable to be set
# @example replaceVarValue CFLAGS /mnt/gentoo/etc/portage/make.conf "-O2"
replaceVarValue()
{
    local var="$1"
    local file="$2"
    local newValue="$3"
    local err=0

    # Temporarily disable exiting script on error to show msg on failure...
    set +o errexit

    cmd "sed -i \"/$var/{s/$var=.*/$var=$newValue/;h};\\\${x;/./{x;q0};x;q1}\" $file"
    err="$?"
    if [[ "$err" -ne 0 ]]; then
        log "Failed to replace variable $var; err: $err; aborting script"
        exit $err
    fi

    # Re-enable exiting script on error
    set -o errexit
}

# @brief Replaces old value of var with new one surrounded by double quotes, for all instances in a file
# @param variable name to be located in file
# @param file storing variable to be modified
# @param new value of the variable to be set
# @example replaceVarValue CFLAGS /mnt/gentoo/etc/portage/make.conf "-O2"
replaceVarValueQuoted()
{
    local var="$1"
    local file="$2"
    local newValue="$3"
    local err=0

    # Temporarily disable exiting script on error to show msg on failure...
    set +o errexit

    cmd "sed -i \"/$var/{s/$var=.*/$var=\\\"$newValue\\\"/;h};\\\${x;/./{x;q0};x;q1}\" $file"
    err="$?"
    if [[ "$err" -ne 0 ]]; then
        log "Failed to replace variable $var; err: $err; aborting script"
        exit $err
    fi

    # Re-enable exiting script on error
    set -o errexit
}

# @brief Executes given command(s) after chroot to /mnt/gentoo
# @param command(s) command to be executed
# @example gentooChroot "emerge-webrsync"
gentooChroot()
{
    cmd chroot /mnt/gentoo /bin/bash -c \""$@"\"
}

# @brief Finds number of given profile name and stores the number into given file
# @param profile profile for which the number needs to be found
# @param file file into which the number will be stored
# @example findProfile desktop /tmp/profile
# @example findProfile 13.0 /tmp/profile
# @note Storing to file is caused by a need of eselct to be executed from chrooted context
findProfile()
{
    local profile="$1"
    local file="$2"

    gentooChroot "eselect profile list | sed 's/\ \*//' | grep $profile\$ | grep -o '[0-9]*' | head -n 1 > $file"
}

# @brief Uncomments given variable in given file
# @param var variable to be uncommented
# @param file file in which variable will be searched
# @example uncommentVar en_US /mnt/gentoo/etc/locale.gen
# TODO return non-zero exit code when variable was not found
uncommentVar()
{
    local var="$1"
    local file="$2"

    cmd "sed -i \"s|^#\(${var}.*\)$|\1|\" ${file}"
}

# @brief Finds number of given locale name and stores the number into given file
# @param locale locale for which the number needs to be found
# @param file file into which the number will be stored
# @example findProfile en_US.utf8 /tmp/locale
# @note Storing to file is caused by a need of eselct to be executed from chrooted context
findLocale()
{
    local locale="$1"
    local file="$2"

    gentooChroot "eselect locale list | sed 's/\ \*//' | grep $locale\$ | grep -o '[0-9]*' | head -n 1 > $file"
}

# @brief Appends fstab entry based on passed parameters
# @param partition partition to be mounted
# @param mntPath path under which partition should be mounted
# @param mntOpts mount options
# @param dumpOpts dump options; usually 0
# @param fsckOpts fsck options; root fs: 0 or 1; non-root 1 or more
# @example addFstabEntry "/dev/sda2" "/boot" "ext2" "noauto,noatime" "0" "2"
addFstabEntry()
{
    local partition="$1"
    local mntPath="$2"
    local fsType="$3"
    local mntOpts="$4"
    local dumpOpts="$5"
    local fsckOpts="$6"
    local entry="$partition $mntPath $fsType $mntOpts $dumpOpts $fsckOpts"

    cmd "echo $entry >> /mnt/gentoo/etc/fstab"
}
