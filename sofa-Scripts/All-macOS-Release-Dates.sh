#!/bin/zsh --no-rcs
# shellcheck shell=bash
#set -x

# macOS-Releases.sh by: Trevor Sysock
# 2024-05-02

#################
#   Functions   #
#################
# Pico Mitchell's json function: https://github.com/RandomApplications/JSON-Shell-Tools-for-macOS/blob/main/json_value.sh
#
# Created by Pico Mitchell (of Random Applications)
#
# MIT License
#
# Copyright (c) 2023 Pico Mitchell (Random Applications)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

# NOTE: This file can be saved and installed to be run as a standalone script, or the function below can be copy-and-pasted to integrate into your own sh/bash/zsh scripts.

# The following "json_value" function is best for doing very direct/simple value retrievals from JSON structures,
# for more advanced capabilites, check out https://randomapplications.com/json_extract instead.

json_value() { # Version 2023.7.24-1 - Copyright (c) 2023 Pico Mitchell - MIT License - Full license and help info at https://randomapplications.com/json_value
	{ set -- "$(/usr/bin/osascript -l 'JavaScript' -e 'ObjC.import("unistd"); function run(argv) { const stdin = $.NSFileHandle.fileHandleWithStandardInput; let out; for (let i = 0;' \
		-e 'i < 3; i ++) { let json = (i === 0 ? argv[0] : (i === 1 ? argv[argv.length - 1] : ($.isatty(0) ? "" : $.NSString.alloc.initWithDataEncoding((stdin.respondsToSelector("re"' \
		-e '+ "adDataToEndOfFileAndReturnError:") ? stdin.readDataToEndOfFileAndReturnError(ObjC.wrap()) : stdin.readDataToEndOfFile), $.NSUTF8StringEncoding).js.replace(/\n$/, "")))' \
		-e '); if ($.NSFileManager.defaultManager.fileExistsAtPath(json)) json = $.NSString.stringWithContentsOfFileEncodingError(json, $.NSUTF8StringEncoding, ObjC.wrap()).js; if (' \
		-e '/^\s*[{[]/.test(json)) try { out = JSON.parse(json); (i === 0 ? argv.shift() : (i === 1 && argv.pop())); break } catch (e) {} } if (out === undefined) throw "Failed to" +' \
		-e '" parse JSON."; argv.forEach(key => { out = (Array.isArray(out) ? (/^-?\d+$/.test(key) ? (key = +key, out[key < 0 ? (out.length + key) : key]) : (key === "=" ? out.length' \
		-e ': undefined)) : (out instanceof Object ? out[key] : undefined)); if (out === undefined) throw "Failed to retrieve key/index: " + key }); return (out instanceof Object ?' \
		-e 'JSON.stringify(out, null, 2) : out) }' -- "$@" 2>&1 >&3)"; } 3>&1; [ "${1##* }" != '(-2700)' ] || { set -- "json_value ERROR${1#*Error}"; >&2 printf '%s\n' "${1% *}"; false; }
}

##########################
#   Script Starts Here   #
##########################

sofaURL="https://sofafeed.macadmins.io/v1/macos_data_feed.json"

sofaJSON=$(/usr/bin/curl -L -m 3 -s "$sofaURL")

# Exit if we can't get data
if [[ ! "$sofaJSON" ]]; then
    echo "Could not obtain data"
    exit
fi

# Initiate Indexes
majorRelease=0
minorRelease=0

# While we have a major version to iterate through
while json_value "${sofaJSON}" 'OSVersions' $majorRelease 'SecurityReleases' 0 'ProductVersion'  > /dev/null 2>&1; do
    # While we have a minor version to iterate through
    while json_value "${sofaJSON}" 'OSVersions' $majorRelease 'SecurityReleases' $minorRelease 'ProductVersion'  > /dev/null 2>&1; do
        # Grab the release name/date of the release we've found
        releaseName=$(json_value "${sofaJSON}" 'OSVersions' $majorRelease 'SecurityReleases' $minorRelease 'ProductVersion')
        releaseDate=$(json_value "${sofaJSON}" 'OSVersions' $majorRelease 'SecurityReleases' $minorRelease 'ReleaseDate')
        # Echo our results. Edit this for the output you need
        echo "$releaseName,$releaseDate"
        # Increase index for our minor version
        minorRelease=$(( minorRelease + 1 ))
    done
    # We got all minor versions for that major release. Move to the next major release
    majorRelease=$(( majorRelease + 1 ))
    # Index 0 of the minor releases for this new major release, and start our loop again.
    minorRelease=0
done
