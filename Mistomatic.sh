#!/bin/zsh
#set -x 

# This script will get the latest versions of macOS 11+ installers in both DMG and IPSW format.
# Older installers for the same major version of macOS will be deleted.
# The intent is to have a script that can be run once a day or once a week in order to ensure
# you have a library of the latest installers for macOS 11, 12, 13, etc.

#########################
#   User Configuration  #
#########################

# This is the oldest macOS major version that we want to look for versions of. Must be 11 or greater.
lowestOS='11'

# This is the directory path that we are keeping our installers. We'll make sub-directories for DMGs and IPSWs
mistStore='/Users/Shared/Mist'

#############
#   Tools   #
#############

mistPath='/usr/local/bin/mist'
pBuddy='/usr/libexec/PlistBuddy'
tmpMistPlist="/var/tmp/mist_$(date +%s).plist"

#################
#   Functions   #
#################

log_message()
{
    echo "$(date): $@"
}

function check_root()
{
# check we are running as root
if [[ $(id -u) -ne 0 ]]; then
  echo "ERROR: This script must be run as root **EXITING**"
  exit 1
fi
}

#########################
#   Script Starts Here  #
#########################

check_root

majorOS="$lowestOS"

# Keep looping until we break or exit
while true ; do
    # Get the latest build number in a variable. We do this by telling Mist to output a plist, then grabbing the build value using PlistBuddy, then delete that plist
    latestBuild=$("$mistPath" list installer --latest $majorOS -e $tmpMistPlist > /dev/null 2>&1 && $pBuddy -c "Print :0:build" $tmpMistPlist 2>/dev/null && rm "$tmpMistPlist")
    # Big Sur was build 20XXXX. If we're getting a build lower than that, our loop needs to end. See the sanity check below for details. Also exit if $latestBuild is unset.
    if [ ${latestBuild:0:2} -lt '20' ] || [ -z "$latestBuild" ]; then
        log_message "End major versions"
        break
    fi
    log_message "Latest installer build of macOS $majorOS is: $latestBuild"
    # Check to see if we have a .dmg for this build already
    buildDMG=$(find "$mistStore" -name "*$latestBuild.dmg")
    if [ -n "$buildDMG" ]; then
        log_message "No new dmg to download"
    else
        log_message "New macOS $majorOS installer version found $latestBuild"
        log_message "Deleting old versions and initiating download..."
        # This finds any dmg with the same major OS version and deletes it
        find "$mistStore" -name "*-${latestBuild:0:2}*.dmg" -exec rm -rf {} \; 
        if "$mistPath" download installer "$latestBuild" image -o "$mistStore/DMGs" > /dev/null 2>&1; then
            log_message "Successfully downloaded new DMG for build $latestBuild"
        else
            log_message "**ERROR: Mist failed to download DMG for build $latestBuild"
        fi
    fi
    majorOS=$(( majorOS + 1 ))
    
    # Sanity check.
    # Because we're relying on a quirk of Mist that shows old versions of macOS when you ask for a list of macOS installers which doesn't exist yet
    # (for example, in February 2023 13 is the highest release and if you ask for the latest version of 14 it responds with 10.14 builds)
    # So maybe this gets fixed or changed in the future. If this variable gets to 20, something has gone rogue and we'll exit the script.
    if [ $majorOS -ge 20 ]; then
        log_message "Something wonky is happening with looking for new versions. Exiting"
        exit 1
    fi
done

# Now repeat for IPSW files
majorOS="$lowestOS"

while true ; do
    # Get the latest build number in a variable. We do this by telling Mist to output a plist, then grabbing the build value using PlistBuddy
    latestBuild=$("$mistPath" list firmware --latest $majorOS -e $tmpMistPlist > /dev/null 2>&1 && $pBuddy -c "Print :0:build" $tmpMistPlist 2>/dev/null && rm "$tmpMistPlist" )
    # Big Sur was build 20XXXX. If we're getting a build lower than that, our loop needs to end. See the sanity check below for details. Also exit if $latestBuild is unset.
    if  [ -z "$latestBuild" ] || [ ${latestBuild:0:2} -lt '20' ]; then
        log_message "End major versions"
        break
    fi
    log_message "Latest firmware build of macOS $majorOS is: $latestBuild"
    # Check to see if we have a .ipsw for this build already
    buildIPSW=$(find "$mistStore" -name "*$latestBuild.ipsw")
    if [ -n "$buildIPSW" ]; then
        log_message "No new ipsw to download"
    else
        log_message "New macOS $majorOS firmware version found $latestBuild"
        log_message "Deleting old versions and initiating download..."
        # This finds any ipsw with the same major OS version and deletes it
        find "$mistStore" -name "*-${latestBuild:0:2}*.ipsw" -exec rm -rf {} \; 
        if "$mistPath" download firmware "$latestBuild" -o "$mistStore/IPSWs" > /dev/null 2>&1; then
            log_message "Successfully downloaded new IPSW for build $latestBuild"
        else
            log_message "**ERROR: Mist failed to download IPSW for build $latestBuild"
        fi
    fi
    
    # Increase the variable so we look for the next macOS release and loop
    majorOS=$(( majorOS + 1 ))
    
    # Sanity check.
    if [ $majorOS -ge 20 ]; then
        log_message "Something wonky is happening with looking for new versions. Exiting"
        exit 1
    fi
done

# All done
exit 0
