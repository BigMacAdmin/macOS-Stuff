#!/bin/zsh
#set -x

# Written by Trevor Sysock aka BigMacAdmin

# This script makes a copy of a mobileconfig file, and swaps out the UUIDs making it a unique profile.
# Use this to create copies of your profiles before making minor edits and sending up to your MDM.
# Use this to avoid uploading two profiles with the same UUIDs to your MDM server

# Usage: ./regenerateProfileUUID.sh /path/to/profile-to-edit.mobileconfig
# Only mobileconfig files are supported, and only one at a time.

# Set argument 1 as our file to edit
mobileConfigFile="$1"
# Generate a new file name. We want this new file to be in the same directory as the existing file, and we will generate a unique file name by using unix epoc time
# /path/to/test1.mobileconfig will become /path/to/test1_epoctime.mobileconfig
newMobileConfigFile="$(dirname $mobileConfigFile)/${mobileConfigFile:t:r}_$(date +%s).mobileconfig"

# Plist Buddy path
pBuddy="/usr/libexec/PlistBuddy"

# Verify we have 1 argument
if [ $# != 1 ]; then
    echo "ERROR: Must provide the path to the mobileconfig to edit. Only one file supported."
    exit 1
fi

# Check the file type, we're limiting only to mobileconfig files
if [ "${mobileConfigFile:e}" != "mobileconfig" ]; then
    echo "ERROR: Script only intended for use with mobileconfig file type"
    exit 2
fi

# Copy the profile and edit the new one
if ! cp "$mobileConfigFile" "$newMobileConfigFile"; then
    echo "ERROR: Cannot copy mobileconfig. Check file permissions"
fi

# Get the existing PayloadIdentifier, and the UUID into their own variables
payloadIdentifierFull=$($pBuddy -c "Print PayloadIdentifier" "$mobileConfigFile")
payloadIdentifierSuffix=$(echo $payloadIdentifierFull | awk -F '.' '{print $NF}')

# Set the new PayloadIdentifier and PayloadUUID values. Use zsh string substitution tricks to make this easy
$pBuddy -c "Set PayloadIdentifier ${payloadIdentifierFull/${payloadIdentifierSuffix}/$(uuidgen)}" "$newMobileConfigFile"
$pBuddy -c "Set PayloadUUID $(uuidgen)" "$newMobileConfigFile"

count=0
while $pBuddy -c "Print PayloadContent:${count}" "$newMobileConfigFile" > /dev/null 2>&1; do
    $pBuddy -c "Set PayloadContent:${count}:PayloadUUID $(uuidgen)" "$newMobileConfigFile"
    count=$(( count + 1 ))
done
