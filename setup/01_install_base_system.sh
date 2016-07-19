#!/bin/bash
#===============================================================================
# FILE:         01_install_base_system.sh
#
# USAGE:        Execute from shell, e.g. ./01_install_base_system.sh
#
# DESCRIPTION:  Installs Gentoo Linux base system
#               TODO Describe in more details
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
    # Pre-install steps
    #---------------------------------------
    createLogDir
    log "Install base system..."

    #---------------------------------------
    # Disks, partitions and file systems
    #---------------------------------------
    checkInitialPartitionsCount # Do not remove old partitions as safety measure
    createMbrPartition          # Does not need file system; just reserve space
    createBootPartition
    createSwapPartition
    createRootPartition
    checkCreatedPartitionsCount # Ensure all partitions were created
    setBootPartitionBootable
    createBootFileSystem
    createSwap
    activateSwap
    createRootFileSystem
    mountRootPartition
    mountBootPartition          # Has to be mounted under root partition FS

    #---------------------------------------
    # Stage 3 tarball
    #---------------------------------------
    getStage3Tarball

    #---------------------------------------
    # Compilation options
    #---------------------------------------
    setCompilationOptions

    #---------------------------------------
    # Mirrors, repos, DNS info
    #---------------------------------------
    selectMirrors           # Hardcoded servers; mirrorselect had pipe problems
    setupGentooRepos
    copyDnsInfo

    #---------------------------------------
    # Chrooting
    #---------------------------------------
    mountLiveFilesystems

    #---------------------------------------
    # Post-install steps
    #---------------------------------------
    unmountBootPartition
    unmountRootPartition        # Has to be unmounted as last one
    log "Install base system...done"
}

#-------------------------------------------------------------------------------
# Execute main function when script is launched; measure execution time
#-------------------------------------------------------------------------------

time main

