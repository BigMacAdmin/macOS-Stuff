#!/bin/bash
#set -x

# Dynamic-swiftDialog-Install.sh by: Trevor Sysock
# 2024-08-11
# v.1.0

# This script will utilize Installomator to deploy swiftDialog.
#
# Installomator is required to be installed on the device running this script.
#
# Since swiftDialog has OS version dependencies, we'll account for this
#   by overriding the default Installomator options at runtime.

# MIT License
#
# Copyright (c) 2024 Trevor Sysock aka @BigMacAdmin
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#####################
#   Configuration   #
#####################

# These are the Installomator options we want to use regardless of 
#   which major OS the device is running
# If you do not want to configure options, leave this blank (but do not comment out)
#   This will initialize an empty array which will be used later in the script
# Example: installomatorOptions=()
installomatorOptions=(
    NOTIFY=silent
    BLOCKING_PROCESS_ACTION=ignore
)

#################
#   Variables   #
#################
# Define the paths to our tools
dialogPath="/usr/local/bin/dialog"
installomatorPath="/usr/local/Installomator/Installomator.sh"

# Get the major OS version this device is running. e.g. "11" or "15"
osMajorVersion=$(sw_vers -productVersion | awk -F '.' '{ print $1 }')

##########################
#   Script Starts Here   #
##########################

# For testing, you can set this variable to an OS major version number and see how the script behaves
#osMajorVersion=12

# If we're not running at least macOS 11, we need to exit because swiftDialog isn't supported
if [[ "$osMajorVersion" -lt "11" ]]; then
    echo "ERROR: macOS 11 or newer is required for SwiftDialog"
    exit 1
# If we're on macOS 11, set Installomator options to "pin" the appropriate version
elif [[ "$osMajorVersion" == "11" ]]; then
    installomatorOptions+=("appNewVersion=2.2.1" "downloadURL=https://github.com/swiftDialog/swiftDialog/releases/download/v2.2.1/dialog-2.2.1-4591.pkg")
# If we're on macOS 11, set Installomator options to "pin" the appropriate version
elif [[ "$osMajorVersion" == "12" ]]; then
    installomatorOptions+=("appNewVersion=2.4.2" "downloadURL=https://github.com/swiftDialog/swiftDialog/releases/download/v2.4.2/dialog-2.4.2-4755.pkg")
# There is no "else" statement, because if we're not running 11 or 12 we want to allow
#   Installomator to discover and install the latest version (which is what it does best).
fi

# Run installomator with the swiftDialog label and any additionally configured options
if "$installomatorPath" swiftdialog "${installomatorOptions[@]}"; then
    # Report what version of Dialog is actually installed, by calling that tool directly
    echo "Installed dialog version is: $("$dialogPath" --version)"
else
    echo "Installomator failed to install swiftDialog"
fi
