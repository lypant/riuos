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
# Base system installation
#---------------------------------------

#-------------------
# Disks, partitions and file systems
#-------------------

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
    local s3Url="http://distfiles.gentoo.org"
          s3Url="$s3Url/releases/x86/autobuilds/current-install-x86-minimal"
    local s3Tarball="" # Empty - autodetect

    log "Get stage3 tarball..."

    # Check/get tarball file name
    if [[ -z "$s3Tarball" ]]; then
        # If name of tarball was not configured explicitly - obtain one from web
        s3Tarball=$(curl -sL $s3Url | grep -o $regEx | head -n 1)
        log "Using current stage3 tarball found in web: $s3Tarball"
    else
        log "Using stage3 tarball specified in config variable: $s3Tarball"
    fi

    log "Downloading stage3 tarball file"
    remoteTarball=$s3Url/$s3Tarball
    localTarball=$dstDir/$s3Tarball
    downloadFile $remoteTarball $localTarball

    log "Downloading stage3 tarball digest file"
    remoteDigests=$remoteTarball.DIGESTS
    localDigests=$dstDir/$s3Tarball.DIGESTS
    downloadFile $remoteDigests $localDigests

    log "Verifying tarball integrity"
    expectedHash=`grep $s3Tarball $localDigests | head -n 1 | awk '{print $1;}'`
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
    local cflags="-march=pentium2 -mno-accumulate-outgoing-args"
          cflags="$cflags -mno-fxsr -mno-sahf -O2"
    local makeopts="-j2"

    log "Set compilation options..."
    log "Replace CFLAGS"
    replaceVarValueQuoted CFLAGS $file "$cflags"
    log "Set MAKEOPTS"
    cmd "echo \"MAKEOPTS=\\\"$makeopts\\\"\" >> $file"
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
    #local profile="desktop"
    local profile="13.0"

    log "Select profile..."

    log "Find profile nb"
    findProfile $profile $chrootedFile

    if [[ -s "$file" ]]; then
        profileNb=$(<$file)
        log "Setting profile $profileNb - $profile"
        gentooChroot "eselect profile set $profileNb"
    else
        log "Profile $profile not found; available profiles:"
        gentooChroot "eselect profile list"
        exit 1
    fi

    gentooChroot "eselect profile list"

    log "Select profile...done"
}

setGlobalUseFlags()
{
    local file="/mnt/gentoo/etc/portage/make.conf"
    local useFlags="alsa"

    log "Set use flags..."
    replaceVarValueQuoted USE $file "$useFlags"
    log "Set use flags...done"
}

setV86dUseFlags()
{
    local file="/mnt/gentoo/etc/portage/package.use/v86d"
    local entry="sys-apps/v86d x86emu"

    log "Set v86d use flags..."
    cmd "echo $entry >> $file"
    log "Set v86d use flags...done"
}

setFbsplashUseFlags()
{
    local file="/mnt/gentoo/etc/portage/package.use/fbsplash"
    local entry1="media-gfx/splashutils fbcondecor"
    local entry2="media-libs/freetype static-libs"
    local entry3="media-libs/libpng static-libs"
    local entry4="media-libs/libjpeg-turbo static-libs"
    local entry5="virtual/jpeg static-libs"
    local entry6="sys-libs/zlib static-libs"
    local entry7="app-arch/bzip2 static-libs"

    log "Set fbsplash use flags..."
    cmd "echo $entry1 >> $file"
    cmd "echo $entry2 >> $file"
    cmd "echo $entry3 >> $file"
    cmd "echo $entry4 >> $file"
    cmd "echo $entry5 >> $file"
    cmd "echo $entry6 >> $file"
    cmd "echo $entry7 >> $file"
    log "Set fbsplash use flags...done"
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
    local locale="en_US.utf8"

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
    findLocale $locale $chrootedFile

    if [[ -s "$file" ]]; then
        localeNb=$(<$file)
        log "Setting locale $localeNb - $locale"
        gentooChroot "eselect locale set $localeNb"
    else
        log "Locale $locale not found; available locales:"
        gentooChroot "eselect locale list"
        exit 1
    fi

    gentooChroot "eselect locale list"

    log "Update environment"
    gentooChroot "env-update"

    log "Set locales...done"
}

setKeymap()
{
    log "Set keymap..."
    replaceVarValueQuoted "keymap" "/mnt/gentoo/etc/conf.d/keymaps" "pl"
    log "Set keymap...done"
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
    gentooChroot "make -C /usr/src/linux i386_defconfig"
    log "Generate default kernel config...done"
}

backupDefaultKernelConfig()
{
    local srcDir="/mnt/gentoo/usr/src/linux"
    local file=".config"

    log "Backup default kernel config..."
    backupMountedKernelConfig
    # Add marker in file after which newly introduced options will be added
    cmd "echo >> $srcDir/$file"
    cmd "echo '# Options added by riuos setup scripts' >> $srcDir/$file"
    log "Backup default kernel config...done"
}

setKernelConfigForAlsa()
{
    log "Set kernel config for alsa..."

    # Backup current config
    backupMountedKernelConfig

    # Change existing options
    setKernelOption CONFIG_SND_RAWMIDI_SEQ
    setKernelOption CONFIG_SND_OPL3_LIB_SEQ
    setKernelOption CONFIG_SND_CMIPCI

    # Add new options
    addKernelOption CONFIG_SND_RAWMIDI
    addKernelOption CONFIG_SND_MPU401_UART
    addKernelOption CONFIG_SND_OPL3_LIB

    log "Set kernel config for alsa...done"
}

setKernelConfigForUvesafb()
{
    log "Set kernel config for uvesafb..."

    # Backup current config
    backupMountedKernelConfig

    # Change existing options
    setKernelOption CONFIG_FIRMWARE_EDID
    setKernelOption CONFIG_FB_UVESA

    log "Set kernel config for uvesafb...done"
}

setKernelConfigForFbsplash()
{
    log "Set kernel config for fbsplash..."

    # Backup current config
    backupMountedKernelConfig

    # Change existing options
    unsetKernelOption CONFIG_FB_TILEBLITTING

    # Add new options
    addKernelOption CONFIG_FB_CON_DECOR

    log "Set kernel config for fbsplash...done"
}

setKernelConfigForCustomFont()
{
    log "Set kernel config for custom font..."

    # Backup current config
    backupMountedKernelConfig

    # Change existing options
    setKernelOption CONFIG_FONTS
    unsetKernelOption CONFIG_FONT_8x8

    # Add new options
    addKernelOption CONFIG_FONT_AUTOSELECT
    addUnsetKernelOption CONFIG_FONT_6x11
    addUnsetKernelOption CONFIG_FONT_7x14
    addUnsetKernelOption CONFIG_FONT_PEARL_8x8
    addUnsetKernelOption CONFIG_FONT_ACORN_8x8
    addUnsetKernelOption CONFIG_FONT_MINI_4x6
    addUnsetKernelOption CONFIG_FONT_6x10
    addUnsetKernelOption CONFIG_FONT_SUN8x16
    addUnsetKernelOption CONFIG_FONT_SUN12x22
    addUnsetKernelOption CONFIG_FONT_10x18

    log "Set kernel config for custom font...done"
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
    cmd "echo config_enp0s12=\"dhcp\" >> /mnt/gentoo/etc/conf.d/net"
    log "Set dhcp...done"
}

setNetworkStarting()
{
    local common="/etc/init.d"
    local target="$common/net.lo"
    local linkFile="net.enp0s12"
    local link="$common/$linkFile"

    log "Set network starting..."
    gentooChroot "ln -s $target $link"
    gentooChroot "rc-update add $linkFile default"
    log "Set network starting...done"
}

installDhcpcd()
{
    log "Install dhcpcd..."
    gentooChroot "emerge net-misc/dhcpcd"
    gentooChroot "rc-update add dhcpcd default"
    log "Install dhcpcd...done"
}

installSystemLogger()
{
    log "Install system logger..."
    gentooChroot "emerge app-admin/sysklogd"
    gentooChroot "emerge app-admin/logrotate"
    gentooChroot "rc-update add sysklogd default"
    log "Install system logger...done"
}

installBootloader()
{
    local src="/usr/share/syslinux"
    local dst="/boot/extlinux"
    local files="menu.c32 memdisk libcom32.c32 libutil.c32"

    log "Install bootloader..."

    # Use syslinux/extlinux as a bootloader
    gentooChroot "emerge sys-boot/syslinux"

    # Write MBR
    gentooChroot "dd bs=440 conv=notrunc count=1 if=/usr/share/syslinux/mbr.bin of=/dev/sda"

    # Install extlinux
    gentooChroot "mkdir $dst"
    gentooChroot "extlinux --install /boot/extlinux"
    gentooChroot "ln -snf . /boot/boot"

    # Copy necessary files
    for file in $files
    do
        gentooChroot "cp $src/$file $dst"
    done

    log "Install bootloader...done"
}

configureBootloader()
{
    local bootPath="/mnt/gentoo/boot"
    local cfgFile="$bootPath/extlinux/extlinux.conf"
    local linux=$(ls $bootPath | grep vmlinuz)
    local initrd=$(ls $bootPath | grep initramfs)
    local append="root=/dev/sda4"

    local timeout="30"
    local menuTitle="RobCo Industries Simplified Bootloader"
    local menuLabel="RobCo Industries Unified Operating System v0.1"

    log "Configure bootloader..."

    cmd "echo TIMEOUT $timeout >> $cfgFile"
    cmd "echo ONTIMEOUT robco >> $cfgFile"
    cmd "echo  >> $cfgFile"
    cmd "echo UI menu.c32 >> $cfgFile"
    cmd "echo MENU TITLE $menuTitle >> $cfgFile"
    cmd "echo  >> $cfgFile"
    cmd "echo LABEL robco >> $cfgFile"
    cmd "echo \"    MENU LABEL $menuLabel\"" >> $cfgFile
    cmd "echo \"    LINUX /boot/$linux\" >> $cfgFile"
    cmd "echo \"    INITRD /boot/$initrd\" >> $cfgFile"
    cmd "echo \"    APPEND $append\" >> $cfgFile"

    log "Configure bootloader...done"
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

copyRiuosFiles()
{
    local src="/root/riuos"
    local dst="/mnt/gentoo/root/riuos"

    # Do not perform typical logging in this function...
    # This would spoil nice logs copied to new system
    mkdir -p $dst
    cp -R $src/* $dst

    # This is only for livecd output and logs consistency
    log "Copy riuos files..."
    log "Copy riuos files...done"
}

unmountPartitions()
{
    local common="/mnt/gentoo"
    local paths="$common/dev/shm $common/dev/pts $common/dev"
    paths="$paths $common/boot $common/sys $common/proc $common"

    log "Unmount partitions..."

    for path in $paths
    do
        cmd "umount -l $path"
    done

    log "Unmount partitions...done"
}

#-------------------------------------------------------------------------------
# Programs installation
#-------------------------------------------------------------------------------

createRegularUserAccount()
{
    log "Create regular user account..."
    cmd "useradd -m -g users -G wheel -s /bin/bash adam"
    log "Create regular user account...done"
}

setRegularUserPassword()
{
    local ask=1

    log "Set regular user password..."

    # Disable exit on error - to get a chance of correcting misspelled password
    set +o errexit
    while [ $ask -ne 0 ]; do
        log "Provide password for regular user adam"
        cmd "passwd adam"
        ask=$?
    done
    # Enable exiting on error again
    set -o errexit

    log "Set regular user password...done"
}

installSudo()
{
    log "Install sudo..."
    cmd "emerge app-admin/sudo"
    log "Install sudo...done"
}

addRegularUserToSudoers()
{
    log "Add regular user to sudoers..."
    cmd "echo \"adam ALL=(ALL) ALL\" >> /etc/sudoers"
    log "Add regular user to sudoers...done"
}

installGit()
{
    log "Install git..."
    cmd "emerge dev-vcs/git"
    log "Install git...done"
}

configureGitUser()
{
    log "Configure git user..."
    cmd "git config --global user.email \"lypant@tlen.pl\""
    cmd "git config --global user.name \"lypant\""
    log "Configure git user...done"
}

cloneRiuosRepo()
{
    log "Clone riuos repo..."
    cmd "git clone https://github.com/lypant/riuos /home/adam/riuos"
    log "Clone riuos repo...done"
}

checkoutCurrentRiuosBranch()
{
    log "Checkout current riuos branch..."
    cmd "git -C /home/adam/riuos checkout 01"
    log "Checkout current riuos branch...done"
}

copyOverRiuosFiles()
{
    log "Copy over riuos files..."
    cmd "cp -r /root/riuos /home/adam"
    log "Copy over riuos files...done"
}

# Directory for building non-packaged SW etc.
createForgeDir()
{
    log "Create forge dir..."
    cmd "mkdir -p /home/adam/forge"
    log "Create forge dir...done"
}

addRiuosBinDirToPath()
{
    log "Add riuos bin dir to path..."
    cmd "echo 'export PATH=/home/adam/riuos/bin:$PATH' >> /home/adam/.bashrc"
    log "Add riuos bin dir to path...done"
}

installBashrcDotfile()
{
    log "Install .bashrc dotfile..."
    installDotfile .bashrc
    log "Install .bashrc dotfile...done"
}

installBashProfileDotfile()
{
    log "Install .bash_profile dotfile..."
    installDotfile .bash_profile
    log "Install .bash_profile dotfile...done"
}

installVim()
{
    log "Install vim..."
    cmd "emerge app-editors/vim"
    log "Install vim...done"
}

installPathogen()
{
    log "Install pathogen..."
    cmd "mkdir -p /home/adam/.vim/autoload"
    cmd "mkdir -p /home/adam/.vim/bundle"
    downloadFile "https://tpo.pe/pathogen.vim"\
                 "/home/adam/.vim/autoload/pathogen.vim"
    log "Install pathogen...done"
}

installNerdTree()
{
    log "Install nerdtree..."
    cmd "git -C /home/adam/.vim/bundle"\
        "clone https://github.com/scrooloose/nerdtree.git"
    log "Install nerdtree...done"
}

installNerdCommenter()
{
    log "Install nerdcommenter..."
    cmd "git -C /home/adam/.vim/bundle"\
        "clone https://github.com/scrooloose/nerdcommenter.git"
    log "Install nerdcommenter...done"
}

installTagbar()
{
    log "Install tagbar..."
    cmd "git -C /home/adam/.vim/bundle"\
        "clone https://github.com/majutsushi/tagbar.git"
    log "Install tagbar...done"
}

installVimrcDotfile()
{
    log "Install .vimrc dotfile..."
    installDotfile .vimrc
    log "Install .vimrc dotfile...done"
}

installRanger()
{
    log "Install ranger..."
    cmd "emerge app-misc/ranger"
    log "Install ranger...done"
}

installTmux()
{
    log "Install tmux..."
    cmd "emerge app-misc/tmux"
    log "Install tmux...done"
}

installTmuxconfDotfile()
{
    log "Install .tmux.conf dotfile..."
    installDotfile .tmux.conf
    log "Install .tmux.conf dotfile...done"
}

installAlsa()
{
    log "Install alsa..."
    cmd "emerge media-sound/alsa-utils"
    log "Install alsa...done"
}

configureAlsa()
{
    log "Configure alsa..."
    # Add user to audio group for access priviliges
    cmd "gpasswd -a adam audio"
    # Start alsa service at boot
    cmd "rc-update add alsasound boot"
    log "Configure alsa...done"
}

installCmus()
{
    log "Install cmus..."
    cmd "emerge media-sound/cmus"
    log "Install cmus...done"
}

# Requires uvesafb kernel parameters to be set first.
# This is done during base system installation
rebuildKlibcWithUvesafbSupport()
{
    log "Rebuild klibc with uvesafb support..."
    cmd "emerge --oneshot --changed-use dev-libs/klibc"
    log "Rebuild klibc with uvesafb support...done"
}

installV86d()
{
    log "Install v86d..."
    cmd "emerge sys-apps/v86d"
    log "Install v86d...done"
}

setV86dKernelOptions()
{
    local option="CONFIG_INITRAMFS_SOURCE"
    local value="/usr/share/v86d/initramfs"
    local file="/usr/src/linux/.config"

    log "Include v86d initramfs in kernel config..."
    setQuotedKernelOption $option $value $file
    addKernelOption CONFIG_INITRAMFS_ROOT_UID 0 $file
    addKernelOption CONFIG_INITRAMFS_ROOT_GID 0 $file
    log "Include v86d initramfs in kernel config...done"
}

# TODO Consider alternative approach - setting params at configureBootloader step
setUvesafbBootParams()
{
    local params="video=uvesafb:800x600-32,mtrr:3,ywrap"
    local pattern="APPEND"
    local file="/boot/extlinux/extlinux.conf"

    log "Set uvesafb boot params..."
    cmd "mount /boot"
    appendToLineContaining $params $pattern $file
    cmd "umount /boot"
    log "Set uvesafb boot params...done"
}

# Needed to be able to access framebuffer device /dev/fb0
addUserToVideoGroup()
{
    log "Add user to video group..."
    cmd "gpasswd -a adam video"
    log "Add user to video group...done"
}

installIdumpDependencies()
{
    log "Install idump dependencies..."
    cmd "emerge media-libs/libjpeg-turbo"
    cmd "emerge media-libs/libpng"
    log "Install idump dependencies...done"
}

installIdump()
{
    local srcDir="/home/adam/forge"
    local repo="https://github.com/uobikiemukot/idump"
    local bldDir="$srcDir/idump"
    local binDir="/home/adam/riuos/bin"

    log "Install idump..."
    # Clone idump git repo
    cmd "git -C $srcDir clone $repo"
    # Build idump
    cmd "make -C $bldDir"
    # "Install" idump by copying it to user's home bin dir
    cmd "cp $bldDir/idump $binDir"
    log "Install idump...done"
}

cloneYaftRepo()
{
    local srcDir="/home/adam/forge"
    local repo="https://github.com/uobikiemukot/yaft"

    log "Clone yaft repo..."
    # Clone yaft git repo
    cmd "git -C $srcDir clone $repo"
    log "Clone yaft repo...done"
}

configureYaftFont()
{
    local font="nixedsys-normal.bdf"
    local bdf="/home/adam/riuos/fonts/$font"
    local bldDir="/home/adam/forge/yaft"
    local newValue="	./mkfont_bdf table/alias fonts/$font > glyph.h"
    local file="$bldDir/makefile"

    log "Configure yaft font..."
    # Copy font description file
    cmd "cp $bdf $bldDir/fonts"

    # Backup makefile
    cmd "cp $file $file.bkp"

    # Edit makefile to use the copied font
    # Temporarily disable exiting script on error to show msg on failure...
    set +o errexit

    cmd "sed -i \"/\bmkfont_bdf table\b/{s|.*|$newValue|;h};\\\${x;/./{x;q0};x;q1}\" $file"
    err="$?"
    if [[ "$err" -ne 0 ]]; then
        log "Failed to change yaft font; err: $err; aborting script"
        exit $err
    fi

    # Re-enable exiting script on error
    set -o errexit

    log "Configure yaft font...done"
}

configureYaftColors()
{
    local oldLine1="0x000000, 0xAA0000, 0x00AA00, 0xAA5500, 0x0000AA, 0xAA00AA, 0x00AAAA, 0xAAAAAA"
    local oldLine2="0x555555, 0xFF5555, 0x55FF55, 0xFFFF55, 0x5555FF, 0xFF55FF, 0x55FFFF, 0xDFDFDF"
    local newLine1="    0x305042, 0x3DF5A0, 0x007D28, 0x00913C, 0x00A550, 0x01B964, 0x15CD78, 0x29E18C,"
    local newLine2="    0x406052, 0x47FFAA, 0x008732, 0x009B46, 0x00AF5A, 0x0BC36E, 0x1FD782, 0x33EB96,"
    local file="/home/adam/forge/yaft/color.h"
    local fileBkp="$file.bkp"

    log "Configure yaft colors..."
    # Backup file to be modified
    cmd "cp $file $fileBkp"
    # Replace system color definition lines
    replaceLineContainingWord "$newLine1" "$oldLine1" "$file"
    replaceLineContainingWord "$newLine2" "$oldLine2" "$file"
    log "Configure yaft colors...done"
}

buildAndInstallYaft()
{
    local bldDir="/home/adam/forge/yaft"

    log "Build and install yaft..."
    # Build yaft
    cmd "make -C $bldDir"
    # Install yaft
    cmd "make -C $bldDir install"
    log "Build and install yaft...done"
}

# Fbsplash is available under package splashutils
installFbsplash()
{
    log "Install fbsplash..."
    cmd "emerge media-gfx/splashutils"
    cmd "rc-update add fbcondecor boot"
    log "Install fbsplash...done"
}

installCustomFbsplashTheme()
{
    log "Install custom fbsplash theme..."
    cmd "cp -R /root/riuos/backgrounds/robco1 /etc/splash/"
    log "Install custom fbsplash theme...done"
}

# Requires initramfs recreation - genkernel
enableSplashThemeInclusionToInitramfs()
{
    local file="/etc/genkernel.conf"
    local oldThemeLine="#SPLASH_THEME="
    local newThemeLine="SPLASH_THEME=\\\"robco1\\\""

    log "Enable splash theme inclusion to initramfs..."
    # Create backup of genkernel config
    cmd "cp $file $file.bkp"
    # Enable splash theme
    uncommentVar "SPLASH" $file
    # Change theme name
    replaceLineContaining "$newThemeLine" "$oldThemeLine" "$file"
    log "Enable splash theme inclusion to initramfs...done"
}

# TODO Consider alternative approach - setting params at configureBootloader step
setFbsplashBootParams()
{
    local theme="robco1"
    local params="splash=silent,theme:$theme quiet logo.nologo console=tty1"
          params="$params vt.default_red=0x30,0x3D,0x00,0x00,0x00,0x01,0x15,0x29,0x40,0x47,0x00,0x00,0x00,0x0B,0x1F,0x33 vt.default_grn=0x50,0xF5,0x7D,0x91,0xA5,0xB9,0xCD,0xE1,0x60,0xFF,0x87,0x9B,0xAF,0xC3,0xD7,0xEB vt.default_blu=0x42,0xA0,0x28,0x3C,0x50,0x64,0x78,0x8C,0x52,0xAA,0x32,0x46,0x5A,0x6E,0x82,0x96"
    local pattern="APPEND"
    local file="/boot/extlinux/extlinux.conf"

    log "Set fbsplash boot params..."
    cmd "mount /boot"
    appendToLineContaining "$params" "$pattern" "$file"
    cmd "umount /boot"
    log "Set fbsplash boot params...done"
}

setLoginMessage()
{
    log "Set login message..."
    cmd "echo -e '\n\n\n\n' > /etc/issue"
    log "Set login message...done"
}

disableLastLoginMessage()
{
    log "Disable last login message..."
    cmd "touch /home/adam/.hushlogin"
    log "Disable last login message...done"
}

# Requires kernel rebuild
setCustomKernelFont()
{
    local orgPath="/usr/src/linux/lib/fonts"
    local srcFile="$orgPath/font_8x16.c"
    local objFile="$orgPath/font_8x16.o"

    log "Set custom kernel font..."
    # Backup original font source file
    cmd "cp $srcFile ${srcFile}.bkp"
    # Remove original font object file
    cmd "rm -f $objFile"
    # Copy custom font source file
    cmd "cp /root/riuos/fonts/font_8x16.c $srcFile"
    log "Set custom kernel font...done"
}

installGentoolkit()
{
    log "Install gentoolkit..."
    cmd "emerge app-portage/gentoolkit"
    log "Install gentoolkit...done"
}

installPciutils()
{
    log "Install pciutils..."
    cmd "emerge sys-apps/pciutils"
    log "Install pciutils...done"
}

rebuildInitramfs()
{
    log "Rebuild initramfs..."
    cmd "mount /boot"
    cmd "genkernel --install initramfs"
    cmd "umount /boot"
    log "Rebuild initramfs...done"
}

recompileKernel()
{
    log "Recompile kernel..."
    cmd "make -C /usr/src/linux"
    log "Recompile kernel...done"
}

reinstallKernel()
{
    log "Reinstall kernel..."
    cmd "mount /boot"
    cmd "make -C /usr/src/linux install"
    cmd "umount /boot"
    log "Reinstall kernel...done"
}

reinstallKernelModules()
{
    log "Reinstall kernel modules..."
    cmd "mount /boot"
    cmd "make -C /usr/src/linux modules_install"
    cmd "umount /boot"
    log "Reinstall kernel modules...done"
}

changeHomeOwnership()
{
    log "Change home dir ownership..."
    cmd "chown -R adam:users /home/adam"
    log "Change home dir ownership...done"
}

