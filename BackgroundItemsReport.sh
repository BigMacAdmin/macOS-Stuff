#!/bin/zsh
#set -x
scriptName="${0}"

#/ Background Items Report v1.0
#/ Written by: Trevor Sysock aka BigMacAdmin
#/
#/ This script will gather information about all LaunchDaemons and LaunchAgents running on a macOS device
#/ May not be fully compatible with SMAppService LaunchD items
#/ 
#/ Usage: 
#/ ./BackgroundItemsReport.sh [ --plist|-p ] [--csv|-c ] [--output|-o /path/to/file ]
#/ --plist|-p
#/              Print output in plist format
#/ --csv|-c
#/              Print output in csv format
#/ --output|-o /path/file
#/              Output to a file. If unset, output will go to standard out
#/ --plist and --csv mode are exclusive and cannot be used together
#/
#/ Run as root for best results

print_usage(){
    grep '^#/' "$scriptName" | cut -c4-
    }

# By default zsh exits the script if a wildcard search fails. Turn that off.
unsetopt nomatch

# We use PlistBuddy to read data in the LaunchD items
pBuddy="/usr/libexec/PlistBuddy"

# Define our exit function
cleanup_and_exit(){
    rm $tempFile  > /dev/null 2>&1
    /bin/echo "${2}"
    exit "${1}"
}

# Set default options to false
csvMode=false
plistMode=false
outputMode=false
# Define our temp file
tempFile=$(mktemp -u /var/tmp/backgroundItems.XXXXX)

## Process script arguments
while [ ! -z "${1}" ]; do
    case $1 in;
        --csv|-c) #/ Print output in csv format
            csvMode=true
            ;;
        --plist|-p) #/ Print output in plist format
            plistMode=true
            ;;
        --output|-o) #/ Output to a file. If not set, output will go to standard out
            outputMode=true
            shift; outputFile=$1
            ;;
        --help|-h) #/ Print this help document
            print_usage
            exit 0
            ;;
        *)
            print_usage
            cleanup_and_exit 1 "ERROR: Unknown argument"
            ;;
    esac
    shift
done

# Check we haven't selected both csv and plist
if $plistMode && $csvMode ; then
    print_usage
    cleanup_and_exit 2 "ERROR: Invalid arguments. Cannot use both csv and plist mode"
fi

# Initialize Temp File for CSV mode
if $csvMode; then
    # Column headers
    /bin/echo "Label,TeamID,Program,LaunchD Item" > $tempFile
fi

# Primary script function
check_folder(){
    # $1 is a folder which contains LaunchD items
    # $2 is the Plist key for the array of dicts
    # Initialize Temp File for Plist mode
    if $plistMode; then
        $pBuddy -c "Add ${2} array" "$tempFile" > /dev/null 2>&1
    fi
    index=0
    # For every ile in $1
    for backgroundItem in "${1}"/*; do
        if [ -e "$backgroundItem" ]; then
            # Provide the full file path
            fullPath="$(realpath $backgroundItem)"
            # Read the LaunchD Label
            label="$($pBuddy -c "Print Label" $backgroundItem)"
            # Find the Program the LaunchD item is running.
            if $($pBuddy -c "Print Program" $backgroundItem  > /dev/null 2>&1) ; then
                program=$($pBuddy -c "Print Program" $backgroundItem)
            # If there is no Program value, probably there are only ProgramArguments. The first entry in that array is the program thats being run.
            elif $($pBuddy -c "Print ProgramArguments" $backgroundItem  > /dev/null 2>&1); then
                program=$($pBuddy -c "Print ProgramArguments:0" $backgroundItem)
            # Something weird, the LaunchD item has no Program? May be edge case? May be impossible? Including anyhow...
            else
                program="null"
            fi
            # If the program in the LaunchD item doesn't exist, report an error
            if [ ! -e "$program" ]; then
                program="ERROR: Program does not exist: $program"
            fi
            # Get the TeamID of the program
            if ! teamID=$(codesign -dv "$program" 2>&1 | grep 'TeamIdentifier' | awk -F '=' '{print $2}'); then
                teamID="null"
            fi
            # If the item isn't signed, set the TeamID to null
            if [[ "$teamID" == 'not set' ]] || [ -z "$teamID" ]; then
                teamID="null"
            fi

            # Put item details in csv file
            if $csvMode; then
                /bin/echo "$label,$teamID,$program,$fullPath" >> "$tempFile"
            # Put item details in plist file
            elif $plistMode; then
                "$pBuddy" -c "Add ${2}:${index} dict" \
                    -c "Add ${2}:${index}:Label string $label" \
                    -c "Add ${2}:${index}:TeamID string $teamID" \
                    -c "Add ${2}:${index}:Program string $program" \
                    -c "Add ${2}:${index}:FullPath string $fullPath" \
                    "$tempFile"
            # Put item details in text semi-readable format
            else
                /bin/echo "****************" >> "$tempFile"
                /bin/echo "$label" >> "$tempFile"
                /bin/echo "$teamID" >> "$tempFile"
                /bin/echo "$program" >> "$tempFile"
                /bin/echo "$fullPath" >> "$tempFile"
            fi
        fi
        # Iterate our index for the next item
        index=$(( index + 1 ))
    done
}


check_folder /Library/LaunchDaemons LaunchDaemons
check_folder /Library/LaunchAgents LaunchAgents

# Check for LaunchAgents in each user's home folder
#^^^ Improve this to look for all users
for homeFolder in /Users/*; do
    check_folder $homeFolder/Library/LaunchAgents UserLaunchAgents-$homeFolder
done

# If the outputFile variable is set, copy the temp file to the final location
if [ ! -z "$outputFile" ]; then
    cp "$tempFile" "$outputFile"
    /bin/echo "Report complete: $outputFile"
else
    # Read to standard out
    cat "$tempFile"
fi

cleanup_and_exit 0
