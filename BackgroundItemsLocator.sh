#!/bin/zsh
#set -x

# By default zsh exits the script if a wildcard search fails. Turn that off.
unsetopt nomatch

# We use PlistBuddy to read data in the LaunchD items
pBuddy="/usr/libexec/PlistBuddy"

check_folder(){
    # $1 is a folder which contains LaunchD items
    for backgroundItem in "${1}"/*; do
        if [ -e "$backgroundItem" ]; then
            # Separators for readability
            echo "--"
            echo ""
            # Provide the full file path
            echo "Full path: $(realpath $backgroundItem)"
            # Read the LaunchD Label
            echo "Label: $($pBuddy -c "Print Label" $backgroundItem)"
            # Find the Program the LaunchD item is running.
            if $($pBuddy -c "Print Program" $backgroundItem  > /dev/null 2>&1) ; then
                program=$($pBuddy -c "Print Program" $backgroundItem)
                echo "Program: $program"
            # If there is no Program value, probably there are only ProgramArguments. The first entry in that array is the program thats being run.
            elif $($pBuddy -c "Print ProgramArguments" $backgroundItem  > /dev/null 2>&1); then
                program=$($pBuddy -c "Print ProgramArguments:0" $backgroundItem)
                echo "ProgramArguments: $program"
            # Something weird, the LaunchD item has no Program? May be edge case? May be impossible? Including anyhow...
            else
                echo "No Program Identified"
            fi
        # Get the TeamID of the program
        teamID=$(codesign -dv "$program" 2>&1 | grep 'TeamIdentifier' | awk -F '=' '{print $2}')
        # If there is a teamID, report it
        if [ ! -z "$teamID" ]; then
            echo "TeamID: $teamID"
        else
            # No TeamID here means the item is not signed (like most scripts)
            echo "TeamID: Unsigned"
        fi
        echo ""
        fi
    done
}

check_folder /Library/LaunchDaemons
check_folder /Library/LaunchAgents

# Check for LaunchAgents in each user's home folder
for homeFolder in /Users/*; do
    check_folder $homeFolder/Library/LaunchAgents
done
