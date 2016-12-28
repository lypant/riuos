#!/bin/bash
#===============================================================================
# FILE:         02_install_programs.sh
#
# USAGE:        Boot already installed base system from hdd and log in as a
#               root user.
#               Go to /riuos/setup and execute the script, e.g.
#               ./02_install_programs.sh
#
# DESCRIPTION:  Second stage of system installation.
#               The script creates regular user account, installs and configures
#               various programs and tools.
#               TODO Describe in more details
#===============================================================================

# Treat unset variables as an error when peforming parameter expansion
# Exit immediately on errors
set -o nounset -o errexit

# Include steps definitions
source steps.sh

# Set log file name
LOG_FILE="../logs/02_install_programs.log"

#-------------------------------------------------------------------------------
# Define main function
#-------------------------------------------------------------------------------

main()
{
    #---------------------------------------
    # Preparations
    #---------------------------------------
    createLogDir

    log "Install programs..."

    #---------------------------------------
    # Regular user account
    #---------------------------------------
    createRegularUserAccount
    setRegularUserPassword
    installSudo
    addRegularUserToSudoers

    #---------------------------------------
    # Git and riuos files
    #---------------------------------------
    installGit
    configureGitUser
    cloneRiuosRepo
    checkoutCurrentRiuosBranch
    copyOverRiuosFiles

    #---------------------------------------
    # Custom home directories
    #---------------------------------------
    createForgeDir
    addRiuosBinDirToPath
    installBashrcDotfile
    installBashProfileDotfile

    #---------------------------------------
    # Vim
    #---------------------------------------
    installVim
    installPathogen
    installNerdTree
    installNerdCommenter
    installTagbar
    installVimrcDotfile

    #---------------------------------------
    # Console based user interface programs
    #---------------------------------------
    installRanger
    installTmux
    installTmuxconfDotfile

    #---------------------------------------
    # Sound
    #---------------------------------------
    installAlsa
    configureAlsa
    installCmus

    #---------------------------------------
    # Graphics
    #---------------------------------------

    #-------------------
    # Uvesafb
    #-------------------
    rebuildKlibcWithUvesafbSupport
    installV86d
    setV86dKernelOptions    # Requires kernel, initramfs and modules reinstall
    setUvesafbBootParams
    addUserToVideoGroup

    #-------------------
    # Yaft
    #-------------------
    installIdumpDependencies
    installIdump
    cloneYaftRepo
    configureYaftFont
    configureYaftColors
    buildAndInstallYaft

    #-------------------
    # Fbsplash
    #-------------------
    installFbsplash
    installCustomFbsplashTheme
    enableSplashThemeInclusionToInitramfs   # Requires initramfs recreation
    setFbsplashBootParams
    setLoginMessage
    disableLastLoginMessage

    #---------------------------------------
    # Utilities
    #---------------------------------------
    installGentoolkit
    installPciutils

    #---------------------------------------
    # Kernel, modules, initramfs recreation
    #---------------------------------------
    rebuildInitramfs
    recompileKernel
    reinstallKernel
    reinstallKernelModules

    #---------------------------------------
    # Final steps
    #---------------------------------------
    changeHomeOwnership
    # TODO Copy logs to user directory from root's home

    log "Install programs...done"
}

#-------------------------------------------------------------------------------
# Execute main function when script is launched; measure execution time
#-------------------------------------------------------------------------------

time main

