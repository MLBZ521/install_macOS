#!/bin/bash

###################################################################################################
# Script Name:  upgrade_macOS.sh
# By:  Zack Thompson / Created:  9/15/2017
# Version:  1.5 / Updated:  5/17/2018 / By:  ZT
#
# Description:  This script handles an in-place upgrade of macOS.
#
###################################################################################################

/usr/bin/logger -s "*****  In-place macOS Upgrade process:  START  *****"

##################################################
# Define Variables

# jamfHelper location
	jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
# Check if machine is FileVault enabled
	statusFV=$(/usr/bin/fdesetup isactive)
# Check if machine supports authrestart
	authRestartFV=$(/usr/bin/fdesetup supportsauthrestart)
# Custom Trigger used for FileVault Authenticated Reboot.
	authRestartFVTrigger="AuthenticatedRestart"
# Workflow Method
	methodType="${5}"

# Turn on case-insensitive pattern matching
shopt -s nocasematch

# Set the variables based on the version that is being provided.
case "${4}" in
	"High Sierra" | "10.13" )
		# macOS High Sierra 10.13 Options:
		# File System Type?  APFS/HFS+
		if [[ "${6}" != "" ]]; then
			fileSystemType="--converttoapfs ${6}"
		fi

		# Wipe Drive (if supported)?
		if [[ "${7}" == "Yes" ]]; then
			osVersion=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F '.' '{print $2"."$3}')
			fileSystemType=$(/usr/sbin/diskutil info / | /usr/bin/awk -F "File System Personality:" '{print $2}' | /usr/bin/xargs)

			if [[ $(/usr/bin/bc <<< "${osVersion} >= 13.4") -eq 1 && "${fileSystemType}" -eq "APFS" ]]; then
				eraseDisk="--eraseinstall --newvolumename \"Macintosh HD\""
			else
				/usr/bin/logger -s "Current FileSystem and OS Version is not supported!"
				exit 1
			fi
		fi

		/usr/bin/curl --silent https://jss.company.com:8443/icon?id=180 > /private/tmp/downloadIcon.png
		appName="Install macOS High Sierra.app"
		downloadTrigger="macOSUpgrade_HighSierra"
		installSwitch="--agreetolicense ${fileSystemType} ${eraseDisk}"
		;;
	"Sierra" | "10.12" )
		/usr/bin/curl --silent https://jss.company.com:8443/icon?id=181 > /private/tmp/downloadIcon.png
		appName="Install macOS Sierra.app"
		downloadTrigger="macOSUpgrade_Sierra"
		installSwitch="--agreetolicense"
		;;
	"El Capitan" | "10.11" )
		/usr/bin/curl --silent https://jss.company.com:8443/icon?id=182 > /private/tmp/downloadIcon.png
		appName="Install OS X El Capitan.app"
		downloadTrigger="macOSUpgrade_ElCapitan"
		installSwitch="--volume /"
		;;
esac

# Turn off case-insensitive pattern matching
shopt -u nocasematch

##################################################
# Setup Functions

# Setup jamfHelper Windows
inform() {

	## Title for all jamfHelper windows
	title="macOS Upgrade"

	# Messages are based on the Workflow method chosen...
	case "${methodType}" in
		"Forced" )
			case "${1}" in
				"Installing" )
					## Setup jamfHelper window for Installing message
					windowType="hud"
					Heading="Initializing macOS Upgrade..."
					Description="Your machine has been scheduled to for a macOS upgrade, please save all open work and close all applications.  This process may take some time depending on the configuration of your machine.
Your computer will reboot and begin the upgrade process shortly."
					Icon="${upgradeOS}/Contents/Resources/ProductPageIcon.icns"
					extras=""
					waitOrGo="Go"
				;;
				"Reboot" )
					## Setup jamfHelper window for a non-FileVaulted Restart message
					windowType="hud"
					Heading="Rebooting System...                      "
					Description="This machine will reboot in one minute..."
					Icon="${upgradeOS}/Contents/Resources/ProductPageIcon.icns"
					extras=""
					waitOrGo="Go"
				;;
			esac
		;;
		"Classroom" )
			case "${1}" in
				"Download" )
					## Setup jamfHelper window for Installing message
					windowType="fs"
					Heading="Initializing macOS Upgrade..."
					Description="This process may take some time depending on the configuration of the machine.
This computer will reboot and begin the upgrade process shortly."
					Icon="${upgradeOS}/Contents/Resources/ProductPageIcon.icns"
					extras=""
					waitOrGo="Go"
				;;
				"Reboot" )
					## Setup jamfHelper window for a non-FileVaulted Restart message
					windowType="hud"
					Heading="Rebooting System...                      "
					Description="This machine will reboot in one minute..."
					Icon="${upgradeOS}/Contents/Resources/ProductPageIcon.icns"
					extras=""
					waitOrGo="Go"
				;;
			esac
		;;
		"Self Service" | "" )
			case "${1}" in 
				"Download" )
					## Setup jamfHelper window for Downloading message
					windowType="hud"
					Heading="Downloading macOS Upgrade...                               "
					Description="This process may potentially take 30 minutes or more depending on your connection speed.
Once downloaded, you will be prompted to continue."
					Icon="/private/tmp/downloadIcon.png"
					extras="-button1 OK"
					waitOrGo="Go"
				;;
				"DownloadComplete" )
					## Setup jamfHelper window for Download Complete message
					windowType="hud"
					Heading="Download Complete!                                         "
					Description="Before continuing, please complete the following actions:
	- Save all open work and close all applications.
	- A power adapter is required to continue, connect it now if you are running on battery.

Click OK when you are ready to continue; once you do so, the upgrade process will begin."
					Icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInfo.icns"
					extras="-button1 OK"
					waitOrGo="Wait"
				;;
				"PowerMessage" )
					## Setup jamfHelper window for AC Power Required message
					windowType="hud"
					Heading="AC Power Required                      "
					Description="To continue, please plug in your Power Adapter.

Press 'OK' when you have connected your power adapter."
					Icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns"
					extras="-button1 \"OK\" -button2 \"Cancel\" -defaultButton 1"
					waitOrGo="Wait"
				;;
				"Installing" )
					## Setup jamfHelper window for Installing message
					windowType="fs"
					Heading="Initializing macOS Upgrade..."
					Description="This process may take some time depending on the configuration of your machine.
Your computer will reboot and begin the upgrade process."
					Icon="${upgradeOS}/Contents/Resources/ProductPageIcon.icns"
					extras=""
					waitOrGo="Go"
				;;
				"ManualFV" )
					## Setup jamfHelper window for Manual FileVault Restart message
					windowType="hud"
					Heading="Reboot Required                      "
					Description="For the upgrade to continue, you will need to unlock the FileVault encrypted disk on this machine after the pending reboot."
					Icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns"
					extras="-timeout 58"
					waitOrGo="Wait"
				;;
				"Reboot" )
					## Setup jamfHelper window for a non-FileVaulted Restart message
					windowType="hud"
					Heading="Rebooting System...                      "
					Description="This machine will reboot in one minute..."
					Icon="${upgradeOS}/Contents/Resources/ProductPageIcon.icns"
					extras="-button1 \"OK\" -defaultButton 1"
					waitOrGo="Wait"
				;;
				"Failed" )
					## Setup jamfHelper window for Failed message
					windowType="hud"
					Heading="Failed to install the macOS Upgrade..."
					Description="If you continue to have issues, please contact your Deskside Support for assistance."
					Icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"
					extras="-button1 \"OK\" -defaultButton 1"
					waitOrGo="Wait"
				;;
			esac
		;;
	esac

	jamfHelperType "${waitOrGo}"
}

# Function that calls JamfHelper and either puts it in the background or wait for user interaction.
	jamfHelperType() {
		if [[ "${1}" == "Go" ]]; then
			"${jamfHelper}" -windowType "${windowType}" -title "${title}" -icon "${Icon}" -heading "${Heading}" -description "${Description}" -iconSize 300 $extras & 2>&1 > /dev/null
		else
			"${jamfHelper}" -windowType "${windowType}" -title "${title}" -icon "${Icon}" -heading "${Heading}" -description "${Description}" -iconSize 300 $extras 2>&1 > /dev/null
		fi	
	}

# Function to Download the installer if needed.
	downloadInstaller() {
		# jamfHelper Download prompt
			inform "Download"

		# Call jamf Download Policy
			/usr/bin/logger -s "Downloading the macOS Upgrade Package from Jamf..."
				/usr/local/jamf/bin/jamf policy -event $downloadTrigger
			/usr/bin/logger -s "Upgrade Package download complete!"

		# jamfHelper Download Complete prompt
			inform "DownloadComplete"
	}

# Function to check if the device is on AC or battery power first
	powerCheck() {
		until [[ $powerStatus == "PASSED" ]]; do

			powerSource=$(/usr/bin/pmset -g ps)

			if [[ ${powerSource} == *"AC Power"* ]]; then
				powerStatus="PASSED"
				/usr/bin/logger -s "Power Status:  PASSED - AC Power Detected"
			else
				powerStatus="FAILED"
				/usr/bin/logger -s "Power Status:  FAILED - AC Power Not Detected"
				# jamfHelper Plug in Power Adapter prompt
					inform "PowerMessage"
					userCanceled="${?}"

				if [[ "${userCanceled}" == 0 ]]; then
					/usr/bin/logger -s "User clicked OK"
				elif [[ "${methodType}" != "Self Service" ]]; then
					/usr/bin/logger -s "This system is not on AC Power.  Aborting..."
					/usr/bin/logger -s "*****  In-place macOS Upgrade process:  ABORTED  *****"
					exit 2
				else
					/usr/bin/logger -s "User canceled the process.  Aborting..."
					/usr/bin/logger -s "*****  In-place macOS Upgrade process:  CANCELED  *****"
					exit 3
				fi

				# Give user a few seconds to connect the power adapter before checking again...
				/bin/sleep 3

			fi
		done
	}

# Function for the Install Process
	installProcess() {

		# Use installer to install the cached package
		if [[ -d "${upgradeOS}" ]]; then

			# jamfHelper Install prompt
				inform "Installing"

			# Setting this key prevents the 'startosinstall' binary from rebooting the machine.
			/usr/bin/defaults write /Library/Preferences/.GlobalPreferences.plist IAQuitInsteadOfReboot -bool YES

			/usr/bin/logger -s "Calling the startosinstall binary..."
			exitOutput=$("${upgradeOS}/Contents/Resources/startosinstall" --applicationpath "${upgradeOS}" --nointeraction ${installSwitch} 2>&1)

			# Grab the exit value.
			exitStatus=$?
			/usr/bin/logger -s "Exit Status was:  ${exitStatus}"
			/usr/bin/logger -s "Exit Output was:  ${exitOutput}"

			# Cleaning up, don't want to leave this key set as it's not documented.
			/usr/bin/defaults delete /Library/Preferences/.GlobalPreferences.plist IAQuitInsteadOfReboot

			/usr/bin/logger -s "*****  startosinstall exist status was:  ${exitStatus}  *****"

		else
			/usr/bin/logger -s "A cached macOS Upgrade Package was not found.  Aborting..."
			/usr/bin/logger -s "*****  In-place macOS Upgrade process:  ERROR  *****"
			exit 4
		fi
	}

# Function for the Reboot Process
	rebootProcess() {
		if [[ $exitStatus == 127 || $exitStatus == 255 || $exitOutput == *"Preparing reboot..."* ]]; then
				# Exit Code of '255' = Results on Sierra --> High Sierra 
				# Exit Code of '127' = Results on Yosemite --> El Capitan
			/usr/bin/logger -s "*****  The macOS Upgrade has been successfully staged.  *****"

			if [[ $statusFV == "true" ]]; then
				/usr/bin/logger -s "Machine is FileVaulted."

				if [[ $authRestartFV == "true" ]]; then

					/usr/bin/logger -s "Attempting an Authenticated Reboot..."
					checkAuthRestart=$(/usr/local/jamf/bin/jamf policy -event $authRestartFVTrigger)

					if [[ $checkAuthRestart == *"No policies were found for the \"${authRestartFVTrigger}\" trigger."* ]]; then
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
					inform "Reboot"

				# Function scheduleReboot
					scheduleReboot

				/usr/bin/logger -s "*****  In-place macOS Upgrade process:  SUCCESS  *****"
				exit 0
			fi
		else
			# jamfHelper Install Failed
				inform "Failed"

			/usr/bin/logger -s "*****  In-place macOS Upgrade process:  FAILED  *****"
			exit 5
		fi
	}

# Function for unsupported FileVault Authenticated Reboot.
	manualFileVaultReboot() {
		/usr/bin/logger -s "Machine does not support FileVault Authenticated Reboots..."

		# jamfHelper Unsupported FileVault Authenticated Reboot prompt
			inform "ManualFV"

		# Function scheduleReboot
		scheduleReboot

		/usr/bin/logger -s "*****  In-place macOS Upgrade process:  SUCCESS  *****"
		
		exit 0
	}

# Function to Schedule a Reboot in one minute.
	scheduleReboot() {
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
