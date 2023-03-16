#!/bin/zsh
#set -x

#############################################
# PreRequisites - Don't change this section #
#############################################

# Get the currently logged in user
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )

# Current User home folder
userHomeFolder=$(dscl . -read /users/${currentUser} NFSHomeDirectory | cut -d " " -f 2)

#########################
#   User Customization  #
#########################

# This is the root folder for our notes organization
notesDir="${userHomeFolder}/Documents/DailyNotes"

# This is the folder you want to keep "Daily" notes
dailyNotesDir="${notesDir}/Daily"

# Days to keep notes in in the root directory before they're filed away.
currentNoteCount='7'

#########################
#   Setting Variables   #
#########################

fileFriendlyDate=$(date +%Y-%m-%d)

thisYear=$(echo $fileFriendlyDate | cut -d '-' -f 1 )
thisMonth=$(echo $fileFriendlyDate | cut -d '-' -f 2 )
thisDay=$(echo $fileFriendlyDate | cut -d '-' -f 3 )

# The directory for the current month's notes
currentMonthFolder="${notesDir}/${thisYear}/${thisMonth}"

# The file path of today's note.
todaysNote="${dailyNotesDir}/${fileFriendlyDate}.md"

#################
#   Functions   #
#################

function check_folder()
{
    # Takes a path to a directory as an argument. If that directory doesn't exist, it will be created.
    # Terminal failure, if the dir can't be created then the script exits.
    # Check if our notes directory exists
    if [ -d "$1" ]; then
        #echo "Directory found: $1"
    else
        if ! mkdir -p "$1"; then
            echo "Failed to create directory: $1"
            exit 1
        else
            #echo "Directory created: $1"
        fi
    fi
}

function open_todays_note()
{
    touch "${todaysNote}" && open "obsidian://open?vault=DailyNotes&file=Daily%2F${fileFriendlyDate}"
}

function check_todays_note()
{
    # Check if todays note already exists
    if [ -f "$todaysNote" ]; then
        #echo "Todays note exists: $todaysNote"
    else
        #echo "Todays note does not exist"
        check_folder "$currentMonthFolder"
        check_folder "$dailyNotesDir"
    fi
    open_todays_note
}

function rotate_daily_notes()
{
    #Create array containing filenames for the past 7 days of notes
    #Start at yesterday, this will iterate up in our loop
    subtractDays='1'
    #Create an empty array
    currentNotesArray=()
    #Add today's note to the array so it doesnt get moved
    currentNotesArray+="$todaysNote"
    #Loop this until we reach n days old (n = currentNoteCount value set above)
    while [ "$subtractDays" -lt "$currentNoteCount" ]; do
        #Craft the expected daily filename to exclude from moving
        currentNotesArray+="$dailyNotesDir/$(date -v -${subtractDays}d  +%Y-%m-%d).md"
        #Iterate our count up 1
        subtractDays=$(( subtractDays +1 ))
    done
    
    fileList=()
    while IFS=  read -r -d $'\0'; do
        #$REPLY is our relative file path, this is part of the `read` command
        fileList+="${REPLY}"
    done < <(find "$dailyNotesDir" -name "*.md" -print0)

    for i in "${fileList[@]}"; do
        if (($currentNotesArray[(Ie)$i])); then
            #echo "file is in our currentNotesArray"
        else
            fileBaseName=$(basename $i)
            fileNoExtension="${fileBaseName:r}"
            # Check if the file we're processing is actually a date.md file
            if ! date -jf "%Y-%m-%d" "$fileNoExtension" +%s  > /dev/null 2>&1; then
                #echo "Skipping $i"
            else
                cleanupNoteYear=$(basename $i | cut -d '-' -f 1)
                cleanupNoteMonth=$(basename $i | cut -d '-' -f 2)
                # NEED TO ADD REGEX HERE TO CHECK AND BAIL IF WE FIND A NOTE THAT DOESNT CONFORM
                finalCleanupDir="${notesDir}/${cleanupNoteYear}/${cleanupNoteMonth}"
                check_folder "$finalCleanupDir"
                if [ -e "${finalCleanupDir}/$fileBaseName" ]; then
                    #echo "WARNING - FILE ALREADY EXISTS"
                    mv "${i}" "${finalCleanupDir}/${fileNoExtension}_${RANDOM}.md"
                else
                    mv "${i}" "${finalCleanupDir}/${fileBaseName}"
                fi
            fi
        fi
    done
}

#########################
#   Script Starts Here  #
#########################

check_todays_note

rotate_daily_notes