#!/bin/zsh
# shellcheck shell=bash
#set -x

# UnsignThatProfile.sh by: Trevor Sysock
# 2024-01-19


#####################
#   Configuration   #
#####################

# Configure what method you want to use to generate a unique filename
# By default, I use date +%s but $(uuidgen) is another great option
set_unique_identifier(){
    # Configure 
    uniqueIdentifier=$(uuidgen)
    #uniqueIdentifier="asdf"
}
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

sourceConfigFile="${1}"
sourceFileName="${sourceConfigFile:t:r}"
sourceFilePath="${sourceConfigFile:h}"
sourceFileType="${sourceConfigFile:t:e}"

#################
#   Functions   #
#################
function set_output_variable(){
    set_unique_identifier
    destinationConfigFile="${sourceFilePath}/${sourceFileName}_${uniqueIdentifier}.${sourceFileType}"
    if [ -e "${destinationConfigFile}" ]; then
        set_unique_identifier
        sleep 2
        destinationConfigFile="${sourceFilePath}/${sourceFileName}_${uniqueIdentifier}.${sourceFileType}"
    fi
    if [ -e "${destinationConfigFile}" ]; then
        echo "Destination file already exists. Check your unique identifier: ${destinationConfigFile}"
        exit 1
    fi
}

##########################
#   Script Starts Here   #
##########################
set_output_variable

if ! openssl smime -inform DER -verify -in "$sourceConfigFile" -noverify -out "$destinationConfigFile" > /dev/null 2>&1; then
    echo "ERROR: Could not unsign the profile"
    exit 1
fi

echo "Success: ${destinationConfigFile}"