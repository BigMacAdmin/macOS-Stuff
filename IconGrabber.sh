#!/bin/zsh --no-rcs
# shellcheck shell=bash
#set -x

#useDialog=false

# IconGrabber.sh by: Trevor Sysock
# 2024-05-29

# Programmatically Find icns Files and Convert Them to PNG

# Provide one argument to this script: An app or directory containing apps/icns files
# Script will search the provided path for .icns files and convert them to png.
#
# Default directory to scan is /Applications
#
# Output will be saved in /var/tmp/  and the folder will be opened when complete.

#################
#   Functions   #
#################

# Check if we're using Dialog, setup our functions
if [ -x /usr/local/bin/dialog ] && [[ $useDialog != false ]]; then
useDialog=true
# execute a dialog command
function dialog_command(){
    /bin/echo "$@"  >> "$dialogCommandFile"
    #log_message "$@"
    sleep .1
}

function increment_dialog(){
    count=0
    while [ "$count" -lt 90 ]; do
        dialog_command "progress: increment"
        sleep .5
        count=$(( count + 1 ))
    done
}

else
# Not using dialog, make dummy functions
useDialog=false
function dialog_command(){
    true
}

function increment_dialog(){
    true
}

fi

##########################
#   Script Starts Here   #
##########################
echo "Initiated IconGrabber.sh: $(date)"

# Requires 1 arument.
if [ -z "$1" ]; then
    searchDir="/Applications"
else
    # Set our search dir based on input
    searchDir="${1}"
fi

echo "Search Directory set: $searchDir"

# Set the tmp output dir as a unique folder
dirName="$(mktemp -d /var/tmp/IconGrabber.XXXXXXX)"

# Make the tmp output dir
if ! mkdir -p "${dirName}"; then
    echo "Could not create ${dirName}"
    exit 1
else
    echo "Temporary Directory: $dirName"
fi

# Initiate an empty array
fileList=()

# Start a dialog window
if "$useDialog"; then
    echo "Creating dialog window"
    dialogCommandFile=$(mktemp /var/tmp/IconGrabberDialog.XXXXXX)

    /usr/local/bin/dialog \
        --title none \
        --message " " \
        --icon "SF=rectangle.and.text.magnifyingglass" \
        --progress \
        --moveable \
        --ontop \
        --width 420 \
        --height 150 \
        --centericon \
        --button1disabled \
        --commandfile "$dialogCommandFile" &

    sleep 1
else
    echo "Skipping Dialog"
fi

echo "Finding .icns files"
# read/find commands put each found .icns file into an array so we can iterate through later
fileCount=0
while IFS=  read -r -d $'\0'; do
    #$REPLY is our relative file path, this is part of the `read` command
    currentFile="${REPLY}"
    fileList+=("$currentFile")
    fileCount=$(( fileCount + 1 ))
done < <(find "$searchDir" -name "*.icns" -print0 )
echo "Converting $fileCount files"

# Update dialog window
dialog_command "progresstext: Converting all .icns to .png..."
dialog_command "height: 200"

# This is a fake progress bar, gotcha
increment_dialog & killPID=$!


# Iterate through our list of icons and do the conversion
count=1
for icon in "${fileList[@]}"; do
    iconAppParent="$(echo ${icon} | sed 's/.app.*/.app/')"
    iconBaseName="$(basename ${iconAppParent})"
    outputName="${dirName}/${iconBaseName:r}-$count.png"
    sips -s format png "${icon}" --out "${outputName}" > /dev/null 2>&1

    echo "icon: ${outputName}" >> "$dialogCommandFile"
    count=$(( count + 1 ))
done

if [ -n "$killPID" ]; then
    kill "$killPID"
fi

dialog_command "progress: complete"
sleep 2

dialog_command "quit:"

rm "${dialogCommandFile}"

open "${dirName}"
