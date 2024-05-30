#!/bin/zsh
#set -x

#\ SpinUpUTMVM.sh
#\ v.1.2
#\ By Trevor Sysock (aka BigMacAdmin)
#\

# MIT License
# 
# Copyright (c) [year] [fullname]
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#\ Requires UTM v.4.4.5 or later
#\ Requires that your Virtual Machines follow these naming conventions:
#\ - Template VMs must begin with the "$templatePrefix" (Default: TEMPLATE)
#\ - Disposable VMs must begin with the "$disposablePrefix" (Default: DISPOSABLE)

#\ DO NOT RUN AS ROOT

#\ By Default, "utmctl" will appear in your dock after running this script.
#\ To avoid this, use `sudo ln -s /Applications/UTM.app/Contents/MacOS/utmctl /usr/local/bin/utmctl` to put it in your PATH

# For macOS, if no version is specified then the currently running host operating system is assumed
# For Windows, set this variable to the desired default value when no --version is provided as an argument
defaultWindowsVersion=11

defaultUbuntuServerVersion=22

defaultUbuntuVersion=22

####################################
# DO NOT EDIT BELOW FOR NORMAL USE #
####################################

#################
#   Variables   #
#################

utmApp="/Applications/UTM.app"

if [ -x /usr/local/bin/utmctl ]; then
    utmCTL="/usr/local/bin/utmctl"
else
    utmCTL="${utmApp}/Contents/MacOS/utmctl"
fi

templatePrefix="TEMPLATE"

disposablePrefix="DISPOSABLE"

thisScript="${0}"

#################
#   Functions   #
#################

function print_usage(){
    if [ ! -z "$2" ]; then
        echo "$2"
        echo ""
    fi
    grep '#\\' "${thisScript}" | grep -v 'grep'
    exit "$1"
}

function delete_all_disposable_vms(){
    # Create an empty array
    disposableUUIDs=()
    confirmationNames=()

    # Iterate through the "utmctl list" command and get an array containing all existing uuids
    while IFS=  read -r; do
        #$REPLY is our GUID and Name, this is part of the `read` command
        disposableUUIDs+=$(echo "${REPLY}" | awk '{print $1}')
        confirmationNames+="${REPLY}"
    done < <($utmCTL list | grep "${disposablePrefix}_")

    fullList=$($utmCTL list)

    if [ -z "$confirmationNames[1]" ]; then
        echo "There are no disposable VMs with prefix: ${disposablePrefix}_"
        exit 0
    fi
    confirm_deletions

    for UUID in ${disposableUUIDs[@]}; do
        deletingVMName=$(echo "$fullList" | grep "$UUID" | awk '{print $NF}')
        if [[ $("$utmCTL" status "$UUID") != 'stopped' ]]; then
            echo "Stopping VM for deletion: $deletingVMName $UUID"
            if ! "$utmCTL" stop "$UUID" --kill; then
                echo "ERROR: Could not stop VM. VM Will not be deleted: $deletingVMName - $UUID"
                return 1
            fi
        fi
        echo "Deleting VM: Name: $deletingVMName UUID: $UUID"
        "$utmCTL" delete "$UUID"
    done
    echo "Disposable VMs have been deleted"
    exit 0
}

function open_utm(){
    if ps -A | grep -v grep | grep -iq 'utm.app' ; then
        sleep 2
    else
        open "$utmApp"
        echo "Opening UTM.app"
        sleep 15
    fi
}

function copy_vm(){
    newVMName="${disposablePrefix}_${operatingSystem}_${version}_$(date +%s)"
    "$utmCTL" clone "$templateVMUUID" --name "$newVMName"
    echo "New VM Created: $newVMName"
}

function launch_vm(){
    echo "Launching: $finalVM"
}

function get_template_vm_UUID(){
    # $1 is the operating system
    # $2 is the version

    # Get the list of VMs
    utmList=$("$utmCTL" list | awk NR\>1)
    templateVMName="${templatePrefix}_${operatingSystem}_${version}"
    # Parse the list of VMs for our VM Template Name and set UUID variable
    templateVMUUID=$(echo "$utmList"| grep "$templateVMName" | awk '{print $1}')
    
    # If we have no matches or multiple matches exit with an error.
    if [ -z $templateVMUUID ]; then
        print_usage 6 "ERROR: Template VM Does not exist: $templateVMName"
    elif [[ $(echo "$templateVMUUID" | wc -l | xargs ) != 1 ]]; then
        print_usage 7 "ERROR: Multiple matches for template VM: $templateVMName"
    fi
}

function start_vm(){
    if $noStart; then
        echo "VM not started due to option"
        exit 0
    fi

    $utmCTL start "$newVMName"
    sleep 5
    if [[ $("$utmCTL" status "$newVMName") != 'started' ]]; then
        echo "ERROR: VM not started as expected."
        exit 6
    fi

}

function confirm_deletions(){
    echo "The following VMs will be deleted: "
    for name in $confirmationNames; do
        echo "$name"
    done
    echo -n "Do you want to proceed with deletion? (Yes or No):    "
    read "REPLY"
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]] || [[ $REPLY =~ ^[Yy] ]]; then
        echo "User Confirmed. Proceeding with deletion."
    else
        echo "Cancelled. To confirm, type \"y\" or \"yes\""
        exit 5
    fi

}

##########################
#   Script Starts Here   #
##########################

# Prerequisites
if [[ $(id -u) = 0 ]]; then
    print_usage 8 "ERROR: Cannot run as root"
fi

#\ Arguments
if [ -z "${1}" ]; then
    echo "Default options will be used."
fi

while [ ! -z "${1}" ]; do
    case "$1" in
        -m|--macOS|--macos|--MACOS)                         #\ Spin up a macOS VM - This option is default if no OS is specified
            operatingSystem="macOS" ; shift
            ;;
        -w|--windows|--Windows|--WINDOWS)                   #\ Spin up a Windows VM
            operatingSystem="Windows" ; shift
            ;;
        -us|--UbuntuServer|--ubuntuserver|--UBUNTUSERVER)   #\ Spin up an Ubuntu Server VM
            operatingSystem="UbuntuServer" ; shift
            ;;
        -u|--ubuntu|--Ubuntu|--UBUNTU)                      #\ Spin up a Ubuntu VM
            operatingSystem="Ubuntu" ; shift
            ;;
        -v|--version)                                       #\ What version of the specified OS to spin up. (i.e. 11, 12, 13, 14)
                                                            #\ If not supplied, the host version of macOS is used or the version of Windows
                                                            #\ specified in the script configuration section.
            version="${2}"; shift; shift
            ;;
        -n|-ns|--nostart)                                   #\ Do not start the VM after cloning
            noStart=true; shift
            ;;
        -d|--delete)                                        #\ Cleanup mode. All VMs with "DISPOSABLE" names will be deleted
                delete_all_disposable_vms
            ;;
        -h|--help)                                          #\ Print this help info
            print_usage 0
            ;;
        *)                                                  #\ Any unknown arguments cause the script to exit.
            print_usage
            exit 9
            ;;
    esac
done

# Set variables
if [ -z "$operatingSystem" ]; then
    operatingSystem="macOS"
fi

# If no version is set, use determine the appropriate default
#if [ -z "$version" ] && [[ "$operatingSystem" == "macOS" ]]; then
#    version=$(sw_vers | grep "ProductVersion" | awk '{print $NF}' | cut -d '.' -f 1)
#elif [ -z "$version" ] && [[ "$operatingSystem" == "Windows" ]]; then
#    version="$defaultWindowsVersion"
#elif [ -z "$version" ] && [[ "$operatingSystem" == "Ubuntu" ]]; then
#    version="$defaultUbuntuVersion"
#elif [ -z "$version" ] && [[ "$operatingSystem" == "UbuntuServer" ]]; then
#    version="$defaultUbuntuServerVersion"
#fi

if [ -z "$version" ]; then
    case $operatingSystem in
        macOS)
            version=$(sw_vers | grep "ProductVersion" | awk '{print $NF}' | cut -d '.' -f 1)
            ;;
        Windows)
            version="$defaultWindowsVersion"
            ;;
        Ubuntu)
            version="$defaultUbuntuVersion"
            ;;
        UbuntuServer)
            version="$defaultUbuntuServerVersion"
            ;;
        *)
            echo "Unknown operating system - Exiting"
            exit 6
            ;;
    esac
fi

# If "No Start" was not set, put the variable to false
if [ -z $noStart ]; then
    noStart=false
fi

open_utm

get_template_vm_UUID

copy_vm

start_vm

echo "Script complete"

#\
#\ For more detailed information on how to use this tool, please see my blog post: https://bigmacadmin.wordpress.com/2024/01/09/spinupvm-sh-a-convenience-script-to-quickly-spin-up-a-macos-test-vm-in-utm/