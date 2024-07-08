#!/bin/zsh --no-rcs
#set -x

# Dialogomator.sh by: Trevor Sysock aka BigMacAdmin
# 2024-06-27

# Quickly run or test Installomator labels with a GUI for input.
# Run this script as root

# MIT License
# 
# Copyright (c) 2024 Trevor Sysock
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#####################
#   Configuration   #
#####################
dialogTitle="Dialogomator"
dialogMessage="What label would you like to run?"

dialogIcon="SF=gear.badge",palette=green,black

####################################
# DO NOT EDIT BELOW FOR NORMAL USE #
####################################
# Syntax:
#   Variables and arrays are "camel case": $thisIsAVariable
#   Functions are "snake case": this_is_a_function
#   Functions are declared with the declaration of "function this_is_a_function(){}"

#################
#   Variables   #
#################
dialogPath="/usr/local/bin/dialog"

#################
#   Functions   #
#################
function check_root(){
    if [ "$(id -u)" != 0 ]; then
        "$dialogPath" \
            --title "Fail" \
            --message "**ERROR:** Script must be run as root." \
            --icon "SF=exclamationmark.triangle",palette=red,pink \
            --centericon \
            --width 330 --height 330 \
            --messagealignment center \
            --ontop --moveable &
        exit 99
    fi
}

##########################
#   Script Starts Here   #
##########################
check_root

labelSelection=$("$dialogPath" \
    --title "$dialogTitle" \
    --message "$dialogMessage" \
    --icon "${dialogIcon}" \
    --textfield "Label",required \
    --textfield "Options" \
    --checkbox "Debug Mode?",checked=true \
    --vieworder textfield,checkbox \
    --checkboxstyle switch \
    --ontop --moveable \
    --height 350 \
    --button2text "Cancel" \
    --infobuttontext "List Labels" \
    --timer 120 --hidetimerbar)
labelSelectionExitCode=$?

# Lets use a case statement to evaluate the exit code of our initial dialog prompt
case "${labelSelectionExitCode}" in; 
    2)
        # Exit code 2 means the user clicked the cancel button
        echo "User cancelled"
        exit 1
        ;;
    3)
        # Exit code 3 means the user clicked the info button. Lets print all available Installomator labels
        touch /var/tmp/LabelList.txt
        "$dialogPath" \
            --title "$dialogTitle" \
            --message "Listing Available Labels" \
            --width 1440 \
            --icon "${dialogIcon}" \
            --progress \
            --ontop --moveable \
            --displaylog /var/tmp/LabelList.txt &

        # swiftDialog 2.5 has a bug where it won't display the first one or two entries added to a file when using `--displaylog`
        echo "Test" > /var/tmp/LabelList.txt
        echo "Test" > /var/tmp/LabelList.txt
        sleep 2
        # Running installomator with no options prints the labels and exits
        /usr/local/Installomator/Installomator.sh >> /var/tmp/LabelList.txt
        # End the progress bar and exit
        echo "progress: 100" >> /var/tmp/dialog.log
        exit 0
        ;;
    0)
        # User selected a label. This is the only exit code that doesn't end the script, so we'll just keep moving along
        echo "User submitted a label name"
        ;;
    4)
        # We use a timer just in case someone runs this from their management tool, we don't want to tie things up
        # Exit code 4 means the timer completed
        echo "Timed out."
        exit 4
        ;;
    *)
        # Some unknown or undefined Dialog exit code, as if `killall Dialog` was used or maybe just CMD+Q
        echo "Dialog quit unexpectedly"
        exit "${labelSelectionExitCode}"
        ;;
esac

# If we made it this far, the user entered a label to run

# Parse the output of our Dialog command to get the label and any configured options
label=$(echo "${labelSelection}" | grep 'Label : ' | awk -F ' : ' '{print $NF}')
InstallomatorOptions=$(echo "${labelSelection}"  | grep 'Options : ' | awk -F ' : ' '{print $NF}')

# Because multiple options may have been passed, and those options will all be in one single variable, this
#   block of code will split them into multiple elements of a new array instead of being all in one var.
currentArgumentArray=()
if [ -n "$InstallomatorOptions" ]; then
    eval 'for argument in '$InstallomatorOptions'; do currentArgumentArray+=$argument; done'
fi

# If the Debug switch was enabled, add that as another argument for Installomator
if echo "${labelSelection}" | grep -q '"Debug Mode?" : "true"' ; then
    currentArgumentArray+="DEBUG=1"
fi

# Open our Dialog log window
"$dialogPath" \
    --title "$dialogTitle" \
    --message " " \
    --width 1440 \
    --icon "${dialogIcon}" \
    --progress \
    --ontop --moveable \
    --displaylog /var/log/Installomator.log &

# Again, swiftDialog 2.5 has a bug where the first few lines won't show, so lets add some empty lines to get around this
echo "" >> /var/log/Installomator.log
sleep 1

echo "" >> /var/log/Installomator.log
sleep 1

# Run the installomator label and report pass or fail
if /usr/local/Installomator/Installomator.sh "${label}" DIALOG_CMD_FILE="/var/tmp/dialog.log" ${currentArgumentArray[@]}; then
    /usr/local/Installomator/Installomator.sh "${label}" DEBUG=0
    echo "progress: 100" >> /var/tmp/dialog.log
    sleep .1
    echo "progresstext: Complete" >> /var/tmp/dialog.log
else
    echo "progress: 100" >> /var/tmp/dialog.log
    sleep .1
    echo "progresstext: Fail" >> /var/tmp/dialog.log
fi

# All Done!
