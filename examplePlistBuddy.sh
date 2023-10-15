#!/bin/zsh
#set -x 

# Path to PlistBuddy
pBuddy="/usr/libexec/PlistBuddy"

# Path to your temporary plist file
tempPlistFile="/var/tmp/PlistBuddyExample_$(date +%s).plist"

# This command generates the Installer history
system_profiler SPInstallHistoryDataType -xml -detailLevel mini > "${tempPlistFile}"

# Set Index to 0
index=0

# Make an until loop. This loops through the plist, increasing index by 1 each time. 
# When the command fails, it means there are no more entries in the array and the loop exits.
until ! $pBuddy -c "Print :0:_items:$index:_name" "$tempPlistFile"  > /dev/null 2>&1; do
    # Get the current items name
    itemName=$($pBuddy -c "Print :0:_items:$index:_name" "$tempPlistFile")
    
    # Get the current items installation date.
    itemDate=$($pBuddy -c "Print :0:_items:$index:install_date" "$tempPlistFile")
    
    # Get the version info for the current item. Since this doesn't exist for all entries, pipe errors to dev/null.
    # If the version info doesn't exist for this item, this variable will be empty.
    itemVersion=$($pBuddy -c "Print :0:_items:$index:install_version" "$tempPlistFile" 2> /dev/null)
    
    # If the "version" variable is empty, add some text so that things are formatted nicely.
    if [ -z $itemVersion ]; then
        itemVersion="No Version Info"
    fi

    # Print the details of this item out into a single line.
    echo "$itemName - $itemVersion - $itemDate"

    # Increase our index value before looping through again.
    index=$(( index + 1))
done

cp "${tempPlistFile}" /Users/tsysock/Downloads/.

# Delete temp plist file
rm "${tempPlistFile}"
