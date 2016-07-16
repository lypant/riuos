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

