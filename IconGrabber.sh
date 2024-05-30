#!/bin/zsh --no-rcs
# shellcheck shell=bash
set -x

#useDialog=false

# IconGrabber.sh by: Trevor Sysock
# 2024-05-18

# Provide one argument to this script: An app or directory containing apps/icns files
# Script will search the provided path for .icns files and convert them to png.
# Output will be saved in /var/tmp/  and the folder will be opened when complete.

#################
#   Functions   #
#################

if [ -x /usr/local/bin/dialog ] && [[ $useDialog != false ]]; then
useDialog=true
# execute a dialog command
function dialog_command(){
    /bin/echo "$@"  >> "$dialogCommandFile"
    #log_message "$@"
    sleep .1
}

else
useDialog=false
function dialog_command(){
    true
}

fi

function increment_dialog(){
    count=0
    while [ "$count" -lt 90 ]; do
        dialog_command "progress: increment"
        sleep .5
        count=$(( count + 1 ))
    done
}

##########################
#   Script Starts Here   #
##########################

# Requires 1 arument.
if [ -z "$1" ]; then
    echo "Argument required: Directory or .app containing one or more .icns files"
    echo "Example: ./IconGrabber.sh /Applications/Utilities"
    exit 2
fi

# Set our search dir based on input
searchDir="${1}"

# Set the tmp output dir as a unique folder
dirName="/var/tmp/Grabbed-Icons-$(date +%s)"

# Make the tmp output dir
if ! mkdir -p "${dirName}"; then
    echo "Could not create ${dirName}"
    exit 1
fi

# Initiate an empty array
fileList=()

if "$useDialog"; then
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
fi

# read/find commands put each found .icns file into an array so we can iterate through later
while IFS=  read -r -d $'\0'; do
    #$REPLY is our relative file path, this is part of the `read` command
    currentFile="${REPLY}"
    fileList+=("$currentFile")
done < <(find "$searchDir" -name "*.icns" -print0 )

dialog_command "progresstext: Converting all .icns to .png..."
increment_dialog & killPID=$!

dialog_command "height: 200"

# Iterate through our list of icons and do the conversion
count=1
for icon in "${fileList[@]}"; do
    iconAppParent="$(echo ${icon} | sed 's/.app.*/.app/')"
    iconBaseName="$(basename ${iconAppParent})"
    outputName="${dirName}/${iconBaseName:r}-$count.png"
    sips -s format png "${icon}" --out "${outputName}"

    echo "icon: ${outputName}" >> "$dialogCommandFile"
    count=$(( count + 1 ))
done

kill "$killPID"

dialog_command "progress: complete"
sleep 2

dialog_command "quit:"

rm "${dialogCommandFile}"

open "${dirName}"
