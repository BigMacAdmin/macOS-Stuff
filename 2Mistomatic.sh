#!/bin/zsh
#set -x 

# This script will get the latest versions of macOS 11+ installers in both DMG and IPSW format.
# Older installers for the same major version of macOS will be deleted.
# The intent is to have a script that can be run once a day or once a week in order to ensure
# you have a library of the latest installers for macOS 11, 12, 13, etc.

mistPath="/usr/local/bin/mist"

#########################
#   User Configuration  #
#########################

# This is the oldest macOS major version that we want to look for versions of. Must be 11 or greater.
lowestOS='11'

# This is the newest macOS major version that we want to look for. 
# You can set this higher than existing versions with the only downside being log spam looking for those version numbers
highestOS='15'

# This is the directory path that we are keeping our installers. We'll make sub-directories for DMGs and IPSWs
mistStore='/Users/Shared/Mist'

# Log file path. Leave empty to put output to standard out.
logFile=''

#####################################
# DO NOT EDIT BELOW FOR NORMAL USE  #
#####################################

#############
#   Paths   #
#############

mistPath='/usr/local/bin/mist'
pBuddy='/usr/libexec/PlistBuddy'

plistFile="full.plist"

tmpPlist="mistomatic-temp_$(date +%s).plist"

##############
#   Arrays   #
##############

desiredFirmwares=()
desiredInstallers=()
exemptedInstallers=()
exemptedFirmwares=()

#################
#   Functions   #
#################

# Script start time
scriptStartTime=$(date +%s)

function no_sleeping()
{

    /usr/bin/caffeinate -d -i -m -u &
    caffeinatepid=$!

}

function log_message()
{
    if [ -n "$logFile" ]; then
    	/bin/echo "$(date +%Y-%m-%d_%H:%M:%S): $*" >> "$logFile"
    else
    	/bin/echo "$(date +%Y-%m-%d_%H:%M:%S): $*"
    fi
}

function cleanup_and_exit(){
    #^^^ rm *_full.plist
    #^^^ rm "$tmpPlist"
    kill "$caffeinatepid"
    scriptExitTime=$(date +%s)
    scriptRunTime=$(( scriptExitTime - scriptStartTime ))
    log_message "Exiting after $scriptRunTime seconds with code ${1}: ${2}"
    exit ${1}

}

function validate_prerequisites(){
    if [ ! -x "$mistPath" ]; then
        cleanup_and_exit 1 "Mist-CLI does not appear to be installed: $mistPath"
    fi

    if [ ! -e "$mistStore" ]; then
        cleanup_and_exit 1 "Path to installers does not exist. Please create or redefine: $mistStore"
    fi

    if [ ! -d "$mistStore"/DMGs ]; then
        mkdir -p "$mistStore"/DMGs
    fi
    if [ ! -d "$mistStore"/IPSWs ]; then
        mkdir -p "$mistStore"/DMGs
    fi

    if [ ! -d "$mistStore"/IPSWs ] || [ ! -d "$mistStore"/DMGs ]; then
        cleanup_and_exit 1 "Error creating required directories"
    fi

    # Create a new tmpPlist with some basic values
    "$pBuddy" -c "Add $(date +%s)" /var/tmp/mist.plist  > /dev/null 2>&1
    "$pBuddy" -c "Add InstallersToDownload array" "$tmpPlist" > /dev/null 2>&1
    "$pBuddy" -c "Add FirmwaresToDownload array" "$tmpPlist" > /dev/null 2>&1

}

function generate_mist_plist(){
    # Provide arguemnts [ firmware | installer ]
    mistPlist="${1}_full.plist"
    "$mistPath" list $1 --export "$mistPlist" > /dev/null 2>&1
    chown 655 "${1}_full.plist"
}

function determine_latest_version(){
    ## Usage:
    ## $1 is the version of macOS you want to determine the latest release for
    ## $2 is either [ firmware | installer ]
    
    # Set index to 0 and we will loop through every dictionary of the array in the plist
    count=0

    # While loop until PlistBuddy exits with an error trying to read the index of the array
    while currentVersionCheck=$("$pBuddy" -c "Print $count:version" "${2}_$plistFile") > /dev/null 2>&1; do
        # Get the major version of the dictionary we're looking at
        currentMajorVersionCheck=$(echo "$currentVersionCheck" | cut -d '.' -f 1)
        # If the current item we're looking at is of the expected major version, then
        if [ $currentMajorVersionCheck = ${1} ]; then
            # Add the build number to the array of what we want to download
            if [ ${2} = "firmware" ]; then
                "$pBuddy" -c "Add :FirmwaresToDownload: string $($pBuddy -c "Print $count:build" ${2}_$plistFile)" "$tmpPlist"
            elif [ ${2} = "installer" ]; then
                "$pBuddy" -c "Add :InstallersToDownload: string $($pBuddy -c "Print $count:build" ${2}_$plistFile)" "$tmpPlist"
            fi

            # Now check if there is more than one item with the same version number. 
            # This happens when Apple releases two builds of the same major version (like when new hardware releases in the middle of an OS lifecycle.)
            # In the interest of keeping my sanity, I'm limiting this to two build versions of the same OS. If Apple for some reason releases three builds of the same OS, this will break.
            # I grow old … I grow old … I shall wear the bottoms of my trousers rolled.
            testCount=$(( count + 1 ))

            # If the next entry in the index is valid, then
            if testVersion=$("$pBuddy" -c "Print $testCount:version" "${2}_$plistFile" ) > /dev/null 2>&1; then
                # If this entry has the same value as the preceding version"
                if [ "$currentVersionCheck" = $testVersion ]; then
                    # Add the build do the array of builds we want to download
                    if [ ${2} = "firmware" ]; then
                        desiredFirmwares+="$("$pBuddy" -c "Print $testCount:build" "${2}_$plistFile")"
                        "$pBuddy" -c "Add :FirmwaresToDownload: string $($pBuddy -c "Print $testCount:build" ${2}_$plistFile)" "$tmpPlist"
                    elif [ ${2} = "installer" ]; then
                        desiredInstallers+="$("$pBuddy" -c "Print $testCount:build" "${2}_$plistFile")"
                        "$pBuddy" -c "Add :InstallersToDownload: string $($pBuddy -c "Print $testCount:build" ${2}_$plistFile)" "$tmpPlist"
                    fi
                fi
            break
            fi
        fi
        count=$(( count + 1 ))
    done

}

function cleanup_directory_dmg(){
    # This function deletes items from the DMGs folder, unless they've been identified as a build number we want to keep.

    # For every DMG in the DMGs directory, 
    set -x
    for existingItem in "$mistStore"/DMGs/*.dmg; do
        # Get the filename by itself
        existingItemFilename=$(basename "${existingItem}")
        # Get the Build number by parsing the filename
        existingItemBuild=$(basename ${existingItem:r} | cut -d '-' -f 2 )

        # If the build number is in our array of desired installers
        if removeBuildIndex=$("$pBuddy" -c "Print :InstallersToDownload" "$tmpPlist" | grep -n "$existingItemBuild" | /usr/bin/awk -F ":" '{print $1}'); then
            log_message "DMG already exists: $existingItemBuild"
            "$pBuddy" -c "Delete InstallersToDownload:$removeBuildIndex" "$tmpPlist"
        else
        #^^^ rm "${mistStore}/DMGs/${existingItemFilename}"
        ls "${mistStore}/DMGs/${existingItemFilename}"
        fi
    done
    set +x
}

#########################
#   Script Starts Here  #
#########################

no_sleeping

validate_prerequisites

log_message "Generating Firmware Plist"
#^^^ generate_mist_plist firmware

log_message "Generating Installer Plist"
#^^^ generate_mist_plist installer

checkingForOS="$lowestOS"

while [ $checkingForOS -le $highestOS ]; do
    log_message "Checking for OS Version: ${checkingForOS}"
    determine_latest_version $checkingForOS firmware
    determine_latest_version $checkingForOS installer
    checkingForOS=$(( checkingForOS +1 ))
done

cleanup_directory_dmg

cleanup_and_exit 0 "Script Completed Successfully"
