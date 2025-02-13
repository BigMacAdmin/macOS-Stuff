#!/bin/zsh --no-rcs
# shellcheck shell=bash
#set -x

# UnsignConfigurationProfile.sh by: Trevor Sysock
# 2024-10-29
# v.0.0

# Copyright (c) 2024 Second Son Consulting
#
# Unauthorized use is strictly prohibited

# This script accepts 1 argument, which is a file path to a signed mobileconfig file
# It will remove the signature from the file and output the unsigned file to the same directory
# Credit to Ben Toms: https://macmule.com/2015/11/16/making-downloaded-jss-configuration-profiles-readable/

#####################
#   Configuration   #
#####################
unsignedSuffix="_unsigned"

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
fileToUnsign="${1}"
basenameFileToUnsign=$(basename "${fileToUnsign}")
dirnameFileToUnsign=$(dirname "${fileToUnsign}")
finalOutputPath="${dirnameFileToUnsign}/${basenameFileToUnsign%.*}${unsignedSuffix}.${basenameFileToUnsign##*.}"

#################
#   Functions   #
#################


##########################
#   Script Starts Here   #
##########################

# Check if the file exists
if [[ ! -f "${fileToUnsign}" ]]; then
    echo "File does not exist, exiting: ${fileToUnsign}"
    exit 1
fi

# Check if the destination file already exists, and if so exit
if [[ -f "${finalOutputPath}" ]]; then
    echo "Unsigned file already exists, exiting: ${finalOutputPath}"
    exit 1
fi

# Check that this is a .mobileconfig file
if [[ "${fileToUnsign##*.}" != "mobileconfig" ]]; then
    echo "This is not a .mobileconfig file, exiting: ${fileToUnsign}"
    exit 1
fi

# Remove the signature from the file
if openssl smime -inform DER -verify -in "${fileToUnsign}" -noverify -out "${finalOutputPath}"; then
    echo "Successfully unsigned the file: ${finalOutputPath}"
else
    echo "Failed to unsigned the file"
    exit 1
fi

# Format the output using plutil
if plutil -convert xml1 "${finalOutputPath}"; then
    echo "Successfully formatted the output"
else
    echo "Failed to format the output. File may not be valid XML: ${finalOutputPath}"
    exit 1
fi
