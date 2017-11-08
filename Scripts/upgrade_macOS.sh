#!/bin/bash

###################################################################################################
# Script Name:  upgrade_macOS.sh
# By:  Zack Thompson / Created:  9/15/2017
# Version:  1.1 / Updated:  11/7/2017 / By:  ZT
#
# Description:  This script handles an in-place upgrade of macOS.
#
###################################################################################################

/usr/bin/logger -s "*****  In-place macOS Upgrade process:  START  *****"

##################################################
# Define Variables

# jamfHelper location
	jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
# Download Cache
	jamfCache="/Library/Application Support/JAMF/Downloads"
# Check if machine is FileVault enabled
	statusFV=$(/usr/bin/fdesetup isactive)
# Check if machine supports authrestart
	authRestartFV=$(/usr/bin/fdesetup supportsauthrestart)
# Custom Trigger used for FileVault Authenticated Reboot.
	authRestartFVTrigger="AuthenticatedRestart"

# Set the variables based on the version that is being provided.
case "${4}" in
	"High Sierra" | "10.13" )
		curl --silent https://jss.company.com:8443/icon?id=180 > /private/tmp/downloadIcon.png
		appName="Install macOS High Sierra.app"
		downloadTrigger="macOSUpgrade_HighSierra"
		;;
	"Sierra" | "10.12" )
		curl --silent https://jss.company.com:8443/icon?id=181 > /private/tmp/downloadIcon.png
		appName="Install macOS Sierra.app"
		downloadTrigger="macOSUpgrade_Sierra"
		;;
	"El Capitan" | "10.11" )
		curl --silent https://jss.company.com:8443/icon?id=182 > /private/tmp/downloadIcon.png
		appName="Install OS X El Capitan.app"
		downloadTrigger="macOSUpgrade_ElCapitan"
		;;
esac

##################################################
# Setup jamfHelper Windows

## Title for all jamfHelper windows
	title="macOS Upgrade"

## Setup jamfHelper window for Downloading message
	downloadHeading="Downloading macOS Upgrade...                               "
	downloadDescription="This process may potentially take 30 minutes or more depending on your connection speed.
Once downloaded, you will be prompted to continue."
	downloadIcon="/private/tmp/downloadIcon.png"

## Setup jamfHelper window for Download Complete message
	completeHeading="Download Complete!                                         "
	completeDescription="Before continuing, please complete the following actions:
	- Save all open work and close all applications.
	- A power adapter is required to continue, connect it now if you are running on battery.

Click OK when you are ready to continue; once you do so, the upgrade process will begin."
	completeIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInfo.icns"

## Setup jamfHelper window for Download Complete message
	powerHeading="AC Power Required                      "
	powerDescription="To continue, please plug in your Power Adapter.

Press 'OK' when you have connected your power adapter."
	powerIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns"

## Setup jamfHelper window for Installing message
	installHeading="Initializing macOS Upgrade..."
	installDescription="This process may take some time depending on the configuration of your machine.
Your computer will reboot and begin the upgrade process."

## Setup jamfHelper window for Manual FileVault Restart message
	manualFVHeading="Reboot Required                      "
	manualFVDescription="For the upgrade to continue, you will need to unlock the FileVault encrypted disk on this machine after the pending reboot."
	fileVaultIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns"

## Setup jamfHelper window for a non-FileVaulted Restart message
	noFVHeading="Rebooting System...                      "
	noFVDescription="This machine will reboot in one minute..."

## Setup jamfHelper window for Installing message
	failedHeading="Failed to install the macOS Upgrade..."
	failedDescription="If you continue to have issues, please contact your Deskside Support for assistance."
	failedIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"

##################################################
# Setup Functions

# Function to Download the installer if needed.
	function downloadInstaller {
		# jamfHelper Download prompt
			"${jamfHelper}" -windowType hud -title "${title}" -icon "${downloadIcon}" -heading "${downloadHeading}" -description "${downloadDescription}" -iconSize 100 -button1 OK &

		# Call jamf Download Policy
			/usr/bin/logger -s "Downloading the macOS Upgrade Package from Jamf..."
				/usr/local/jamf/bin/jamf policy -event $downloadTrigger
			/usr/bin/logger -s "Upgrade Package download complete!"

		# jamfHelper Download Complete prompt
			"${jamfHelper}" -windowType hud -title "${title}" -icon "${completeIcon}" -heading "${completeHeading}" -description "${completeDescription}" -button1 OK
	}

# Function to check if the device is on AC or battery power first
	function powerCheck {
		until [[ $powerStatus == "PASSED" ]]; do

			powerSource=$(/usr/bin/pmset -g ps)

			if [[ ${powerSource} == *"AC Power"* ]]; then
				powerStatus="PASSED"
				/usr/bin/logger -s "Power Status:  PASSED - AC Power Detected"
			else
				powerStatus="FAILED"
				/usr/bin/logger -s "Power Status:  FAILED - AC Power Not Detected"
				# jamfHelper Plug in Power Adapter prompt
					userCanceled=$("${jamfHelper}" -windowType hud -title "$title" -icon "${powerIcon}" -heading "${powerHeading}" -description "${powerDescription}" -iconSize 100 -button1 "OK" -button2 "Cancel" -defaultButton 1)

				if [[ $userCanceled == 2 ]]; then
					/usr/bin/logger -s "User canceled the process.  Aborting..."
					/usr/bin/logger -s "*****  In-place macOS Upgrade process:  CANCELED  *****"
					exit 101
				fi

				# Give user a few seconds to connect the power adapter before checking again...
				/bin/sleep 3

			fi
		done
	}

# Function for the Install Process
	function installProcess {

		# Use installer to install the cached package
		if [[ -d "${upgradeOS}" ]]; then

			# Grab the Install Icon
			installIcon="${upgradeOS}/Contents/Resources/ProductPageIcon.icns"

			# jamfHelper Install prompt
			"${jamfHelper}" -windowType fs -title "${title}" -icon "${installIcon}" -heading "${installHeading}" -description "${installDescription}" -iconSize 100 &

			# Setting this key prevents the 'startosinstall' binary from rebooting the machine.
			/usr/bin/defaults write /Library/Preferences/.GlobalPreferences.plist IAQuitInsteadOfReboot -bool YES

			/usr/bin/logger -s "Calling the startosinstall binary..."
			exitOutput=$("${upgradeOS}/Contents/Resources/startosinstall" --applicationpath "${upgradeOS}" --agreetolicense --nointeraction 2>&1)

			# Grab the exit value.
			exitStatus=$?
			/usr/bin/logger -s "Exit Status was:  ${exitStatus}"
			/usr/bin/logger -s "Exit Output was:  ${exitOutput}"

			# Cleaning up, don't want to leave this key set as it's not documented.
			/usr/bin/defaults delete /Library/Preferences/.GlobalPreferences.plist IAQuitInsteadOfReboot

			/usr/bin/logger -s "*****  startosinstall exist status was:  ${exitStatus}  *****"
			/usr/bin/logger -s "*****  The macOS Upgrade has been staged.  *****"
		else
			/usr/bin/logger -s "A cached macOS Upgrade Package was not found.  Aborting..."
			/usr/bin/logger -s "*****  In-place macOS Upgrade process:  ERROR  *****"
			exit 102
		fi
	}

# Function for the Reboot Process
	function rebootProcess {
		if [[ $exitStatus == 127 || $exitStatus == 255 || $exitOutput == *"Preparing reboot..."* ]]; then
				# Exit Code of '255' = Results on Sierra --> High Sierra 
				# Exit Code of '127' = Results on Mavericks --> High Sierra

			if [[ $statusFV == "true" ]]; then
				/usr/bin/logger -s "Machine is FileVaulted."

				if [[ $authRestartFV == "true" ]]; then

					/usr/bin/logger -s "Attempting an Authenticated Reboot..."
					checkAuthRestart=$(/usr/local/jamf/bin/jamf policy -event $authRestartFVTrigger)

					if [[ $checkAuthRestart == *"No policies were found for the ${authRestartFVTrigger} trigger."* ]]; then
						# Function manualFileVaultReboot
							manualFileVaultReboot
					else
						/usr/bin/logger -s "*****  In-place macOS Upgrade process:  SUCCESS  *****"
						exit 0
					fi
				else
					# Function manualFileVaultReboot
						manualFileVaultReboot
				fi
			else
				/usr/bin/logger -s "Machine is not FileVaulted."
				"${jamfHelper}" -windowType hud -title "macOS Upgrade" -icon "${installIcon}" -heading "${noFVHeading}" -description "${noFVDescription}" -iconSize 100 -timeout 58

				# Function scheduleReboot
					scheduleReboot

				/usr/bin/logger -s "*****  In-place macOS Upgrade process:  SUCCESS  *****"
				exit 0
			fi
		else
			# jamfHelper Install Failed
			"${jamfHelper}" -windowType hud -title "${title}" -icon "${failedIcon}" -heading "${failedHeading}" -description "${failedDescription}" -iconSize 100 -button1 "OK" -defaultButton 1

			/usr/bin/logger -s "*****  In-place macOS Upgrade process:  FAILED  *****"
			exit 103
		fi
	}

# Function for unsupported FileVault Authenticated Reboot.
	function manualFileVaultReboot {
		/usr/bin/logger -s "Machine does not support FileVault Authenticated Reboots..."

		# jamfHelper Unsupported FileVault Authenticated Reboot prompt
		"${jamfHelper}" -wincdowType hud -title "${title}" -icon "${fileVaultIcon}" -heading "${manualFVHeading}" -description "${manualFVDescription}" -iconSize 100 -button1 "OK" -defaultButton 1

		# Function scheduleReboot
		scheduleReboot

		/usr/bin/logger -s "*****  In-place macOS Upgrade process:  SUCCESS  *****"
		
		exit 0
	}

# Function to Schedule a Reboot in one minute.
	function scheduleReboot {
		/usr/bin/logger -s "Scheduling a reboot one minute from now..."
		rebootTime=$(/bin/date -v "+1M" "+%H:%M")

		/usr/bin/logger -s "Rebooting at $rebootTime"
		/sbin/shutdown -r $rebootTime
	}

##################################################
# Now that we have our work setup... 

# Check if the install .app is already present on the machine (no need to redownload the package).
if [[ -d "/Applications/${appName}" ]]; then
	upgradeOS="/Applications/${appName}"
elif [[ -d "/tmp/${appName}" ]]; then
	upgradeOS="/tmp/${appName}"
else
	# Function downloadInstaller
		downloadInstaller
	# Set the package name.
		upgradeOS="/tmp/${appName}"
fi

# Function powerCheck
	powerCheck
# Function installProcess
	installProcess
# Function rebootProcess
	rebootProcess