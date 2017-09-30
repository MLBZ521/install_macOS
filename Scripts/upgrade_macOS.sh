#!/bin/bash

###################################################################################################
# Script Name:  upgrade_macOS.sh
# By:  Zack Thompson / Created:  9/15/2017
# Version:  0.5 / Updated:  9/20/2017 / By:  ZT
#
# Description:  This script downloads an in-place upgrade of macOS.
#
###################################################################################################

/usr/bin/logger -s "*****  In-place macOS Upgrade process:  START *****"

##################################################
# Define Variables

# jamfHelper location
	jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
# Download Cache
	jamfCache="/Library/Application Support/JAMF/Downloads"
# Custom Trigger used for download.
	customTrigger="${4}"

# Setup jamfHelper Windows
## Title for all jamfHelper windows
	title="macOS Upgrade"

## Setup jamfHelper window for Downloading message
	downloadHeading="Downloading macOS Upgrade...                               "
	downloadDescription="This process may potentially take 30 minutes or more depending on your connection speed.
Once downloaded, you will be prompted to continue."
	downloadIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/DownloadsFolder.icns"
## End jamfHelper Setup


## Setup jamfHelper window for Download Complete message
	completeHeading="Download Complete!                                         "
	completeDescription="Before continuing, please complete the following actions:
	- Save all open work and close all applications.
	- A power adapter is required to continue, connect it now if you are running on battery.
Click OK when you are ready to continue; once you do so, the upgrade process will begin."
	completeIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInfo.icns"
## End jamfHelper Setup


## Setup jamfHelper window for Download Complete message
	powerHeading="AC Power Required                      "
	powerDescription="To continue, please plug in your Power Adapter.  Press 'OK' when you have connected your power adapter."
	powerIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns"
## End jamfHelper Setup


## Setup jamfHelper window for Installing message
	installHeading="Initializing macOS Upgrade..."
	installDescription="This process may take some time depending on the configuration of your machine.
Your computer will reboot and begin the upgrade process."
## End jamfHelper Setup

##################################################
# Download Process

# jamfHelper Download prompt
	"${jamfHelper}" -windowType hud -title "${title}" -icon $downloadIcon -heading "${downloadHeading}" -description "${downloadDescription}" -button1 OK &

# Call jamf Download Policy
	/usr/bin/logger -s "Downloading the macOS Upgrade Package from Jamf..."
		/usr/local/jamf/bin/jamf policy -event $customTrigger
	/usr/bin/logger -s "Upgrade Package download complete!"

# jamfHelper Download Complete prompt
	"${jamfHelper}" -windowType hud -title "${title}" -icon $completeIcon -heading "${completeHeading}" -description "${completeDescription}" -button1 OK

##################################################
# Check Process

# Check if the device is on AC or battery power first
until [[ $powerStatus ==  "PASSED" ]]; do
	powerSource=$(/usr/bin/pmset -g ps)

	if [[ ${powerSource} == *"AC Power"* ]]; then
		powerStatus="PASSED"
		/usr/bin/logger -s "Power Status:  PASSED - AC Power Detected"
	else
		powerStatus="FAILED"
		/usr/bin/logger -s "Power Status:  FAILED - AC Power Not Detected"
		# jamfHelper Plug in Power Adapter prompt
			userCanceled=$("${jamfHelper}" -windowType hud -title "${title}" -icon "${powerIcon}" -heading "${powerHeading}" -description "${powerDescription}" -iconSize 100 -button1 "OK" -button2 "Cancel" -defaultButton 1)

		if [[ $userCanceled == 2 ]]; then
			/usr/bin/logger -s "User canceled the process.  Aborting..."
			/usr/bin/logger -s "*****  In-place macOS Upgrade process:  CANCELED *****"
			exit 1
		fi

		# Give user a few seconds to connect the power adapter before checking again...
		/bin/sleep 5

	fi
done

##################################################
# Install Process

if [[ $powerStatus == "PASSED" ]]; then

	# Grab the cached package name.
	cachedPkg=$(/bin/ls "${jamfCache}" | /usr/bin/grep "macOS Upgrade")

	# Full Path of Package
	installPkg=$(echo "${jamfCache}/${cachedPkg}")

	# Grab the Install Icon
	iconHighSierra="$installPkg/Contents/Resources/InstallAssistant.icns"

	# jamfHelper Install prompt
	"${jamfHelper}" -windowType fs -title "${title}" -icon "${iconHighSierra}" -heading "${installHeading}" -description "${installDescription}" -iconSize 100 &

	# Use installer to run the Cached Package
	if [[ -d "$installPkg" ]]; then
		/usr/bin/logger -s "Executing macOS Upgrade Package..."
		/usr/sbin/installer -dumplog -verbose -pkg "${installPkg}" -allowUntrusted -target /
	else
		/usr/bin/logger -s "A cached macOS Upgrade Package was not found.  Aborting..."
		/usr/bin/logger -s "*****  In-place macOS Upgrade process:  ERROR *****"
		exit 2
	fi
fi

/usr/bin/logger -s "*****  In-place macOS Upgrade process:  SUCCESS *****"

exit 0
