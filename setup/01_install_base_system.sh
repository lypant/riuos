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

    # TODO Perform installation
    log "TODO implement base system installation!"

    #---------------------------------------
    # Post-install steps
    #---------------------------------------
    log "Install base system...done"
}

#-------------------------------------------------------------------------------
# Execute main function when script is launched; measure execution time
#-------------------------------------------------------------------------------

time main

