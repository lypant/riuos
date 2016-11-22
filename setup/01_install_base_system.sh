#!/bin/bash
#===============================================================================
# FILE:         01_install_base_system.sh
#
# USAGE:        Boot from Gentoo installation media.
#               Obtain riuos installation scripts, e.g.
#               curl -L https://github.com/lypant/riuos/tarball/01 | tar xz
#               Rename unpacked directory to riuos, e.g. mv lypant* riuos
#               Go to setup directory, e.g. cd /riuos/setup
#               Execute the script from shell, e.g. ./01_install_base_system.sh
#
# DESCRIPTION:  Installs Gentoo Linux base system using Gentoo installation cd.
#               After successfull installation it is possible to boot system
#               from a disk and log in as a root user.
#               To continue with next stage of installation,
#               see 02_install_programs.sh
#===============================================================================

# Treat unset variables as an error when peforming parameter expansion
# Exit immediately on errors
set -o nounset -o errexit

# Include steps definitions
source steps.sh

# Set log file name
LOG_FILE="../logs/01_install_base_system.log"

#-------------------------------------------------------------------------------
# Define main function
#-------------------------------------------------------------------------------

main()
{
    #---------------------------------------
    # Preparations
    #---------------------------------------
    createLogDir
    log "Install base system..."

    #---------------------------------------
    # Partitions
    #---------------------------------------
    checkInitialPartitionsCount # Do not remove old partitions as safety measure
    createMbrPartition          # Does not need file system; just reserve space
    createBootPartition
    createSwapPartition
    createRootPartition
    checkCreatedPartitionsCount # Ensure all partitions were created
    setBootPartitionBootable

    #---------------------------------------
    # File systems
    #---------------------------------------
    createBootFileSystem
    createSwap
    activateSwap
    createRootFileSystem

    #---------------------------------------
    # Mounting
    #---------------------------------------
    mountRootPartition
    mountBootPartition          # Has to be mounted under root partition FS

    #---------------------------------------
    # Gentoo-specific configuration
    #---------------------------------------
    getStage3Tarball
    setCompilationOptions
    selectMirrors               # Hardcoded servers
    #selectMirrorsAutomatically  # Obtain servers - for some reason only 1
    setupGentooRepos
    copyDnsInfo

    #---------------------------------------
    # Configure Portage
    #---------------------------------------
    mountLiveFilesystems
    installPortageSnapshot
    selectProfile
    setUseFlags
    updateWorldSet

    #---------------------------------------
    # Localization
    #---------------------------------------
    setTimeZone
    setLocales
    setKeymap
    # TODO Add hwclock setting if needed

    #---------------------------------------
    # Kernel
    #---------------------------------------
    installKernelSources
    generateDefaultKernelConfig
    backupDefaultKernelConfig
    setKernelConfigForAlsa
    # TODO Add here more kernel options configuration steps if needed
    compileKernel
    installKernelModules
    installKernel
    installGenkernel
    buildInitramfs
    # TODO Add here kernel modules automatic loading on startup if needed
    installFirmware

    #---------------------------------------
    # Fstab
    #---------------------------------------
    configureFstab

    #---------------------------------------
    # Networking
    #---------------------------------------
    setHostname
    installNetifrc
    setDhcp
    setNetworkStarting
    installDhcpcd
    # TODO Add services starting if needed

    #---------------------------------------
    # System logger
    #---------------------------------------
    installSystemLogger

    #---------------------------------------
    # Bootloader
    #---------------------------------------
    installBootloader
    configureBootloader

    #---------------------------------------
    # Root account
    #---------------------------------------
    setRootPassword

    log "Install base system...done"

    #---------------------------------------
    # Post-install steps
    #---------------------------------------
    copyRiuosFiles
    unmountPartitions
}

#-------------------------------------------------------------------------------
# Execute main function when script is launched; measure execution time
#-------------------------------------------------------------------------------

time main

