#!/bin/zsh
#set -x

# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), 
# to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
# IN THE SOFTWARE.

# Trevor Sysock aka BigMacAdmin
# v1.0 - 2023-09-26

# Usage:
# ./installerHistory.sh [ "App Name" ]
    # $1 "App Name" is an optional argument which filters only for the application name given
    # If no argument is given, all installation information is given.
    # Partial matches are accepted, and the string is not case sensitive.
    # For example: ./installerHistory.sh "Microsoft" will print the installation information for any app with "Microsoft" in the name.
    # Alternately, change the "appFilter" variable below to hard code an app name into the script.

#############
# Variables #
#############

appFilter=""

# PlistBuddy path for convenience
pBuddy="/usr/libexec/PlistBuddy"

# A temporary file location which will be deleted later
tempPlistFile="/var/tmp/$(date +%s)_InstallerHistory.plist"

#############
# Functions #
#############

function check_app_filter(){
    # A function to check whether an appFilter variable was set. 
    # If so, use "continue" command to exit our loop when we are processing an item that doesn't match.
    if [ -n "$appFilter" ]; then
        # Check if the current Item Name contains the given string
        if ! $(echo "$itemName" | grep -qi "$appFilter"); then
            index=$(( index + 1 ))
            continue
        fi
    fi
}

######################
# Script Starts Here #
######################

if [ $# != 0 ]; then
    appFilter="${1}"
fi

# This command generates the plist 
system_profiler SPInstallHistoryDataType -xml -detailLevel mini > "${tempPlistFile}"

# Set index to 0
index=0

arrayOfEntries=()

# Repeat this loop until we get to an index item that doesn't have an entry. That means we've gone through every item.
until ! $pBuddy -c "Print :0:_items:$index:_name" "$tempPlistFile"  > /dev/null 2>&1; do
    # Get the name of the current item
    itemName=$($pBuddy -c "Print :0:_items:$index:_name" "$tempPlistFile")
    # Check if the itemName matches the appFilter.
    check_app_filter

    # Get the date of install for the current item
    itemDate=$($pBuddy -c "Print :0:_items:$index:install_date" "$tempPlistFile")
    
    # Get the version info for the current item. Since this doesn't exist for all entries, pipe errors to dev/null.
    # If the version info doesn't exist for this item, this variable will be empty.
    itemVersion=$($pBuddy -c "Print :0:_items:$index:install_version" "$tempPlistFile" 2> /dev/null)
    
    # If the "version" variable is empty, add some text so that things are formatted nicely.
    if [ -z $itemVersion ]; then
        itemVersion="No Version Info"
    fi

    # This prints a single line per item in the list to standard output
    echo "$itemName - $itemVersion - $itemDate"

    # Increment our index and repeat the loop
    index=$(( index + 1 ))
done

# Delete our temp plist file
rm "${tempPlistFile}"
