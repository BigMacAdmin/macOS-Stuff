#!/bin/zsh
#set -x

# By default zsh exits the script if a wildcard search fails. Turn that off.
unsetopt nomatch

# We use PlistBuddy to read data in the LaunchD items
pBuddy="/usr/libexec/PlistBuddy"

# Column headers
/bin/echo "Label,TeamID,Program,LaunchD Item"

check_folder(){
    # $1 is a folder which contains LaunchD items
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
        if [ ! -e "$program" ]; then
            program="ERROR: Program does not exist: $program"
        fi
        # Get the TeamID of the program
        if ! teamID=$(codesign -dv "$program" 2>&1 | grep 'TeamIdentifier' | awk -F '=' '{print $2}'); then
            teamID="null"
        fi
        if [[ "$teamID" == 'not set' ]] || [ -z "$teamID" ]; then
            teamID="null"
        fi
        /bin/echo "$label,$teamID,$program,$fullPath"
        fi
    done
}

check_folder /Library/LaunchDaemons
check_folder /Library/LaunchAgents

# Check for LaunchAgents in each user's home folder
for homeFolder in /Users/*; do
    check_folder $homeFolder/Library/LaunchAgents
done
