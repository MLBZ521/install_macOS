#!/bin/bash

###################################################################################################
# Script Name:  install_macOS.sh
# By:  Zack Thompson / Created:  9/15/2017
# Version:  2.0.3 / Updated:  10/18/2018 / By:  ZT
#
# Description:  This script handles in-place upgrades or clean installs of macOS.
#
###################################################################################################

echo "*****  install_macOS process:  START  *****"

##################################################
# Define Environmental Variables

# Jamf Pro Server URL
	jamfPS="https://jss.company.com:8443"
# Download Icon IDs
	elCapitanIconID="182"
	sierraIconID="181"
	highSierraIconID="180"
	mojaveIconID="183"
# Custom Trigger used for FileVault Authenticated Reboot
	authRestartFVTrigger="AuthenticatedRestart"
# Custom Trigger used for Downloading Installation Media
	elCapitanDownloadTrigger="macOSUpgrade_ElCapitan"
	sierraDownloadTrigger="macOSUpgrade_Sierra"
	highSierraDownloadTrigger="macOSUpgrade_HighSierra"
	mojaveDownloadTrigger="macOSUpgrade_Mojave"

##################################################
# Define Variables

# jamfHelper location
	jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
# Check if machine is FileVault enabled
	statusFV=$(/usr/bin/fdesetup isactive)
# Check if machine supports authrestart
	authRestartFV=$(/usr/bin/fdesetup supportsauthrestart)
# Define array to hold the startosinstall arguments
	installSwitch=()
# Define the value for the --newvolumename Switch
	volumeName="Macintosh HD"
# Define the value for the --installpackage Switch
	packageName="/tmp/Jamf_QuickAdd.pkg"
# Reassign passed parameters
	macOSVersion="${4}"
	methodType="${5}"
	convertAPFS="${6}"
	eraseinstall="${7}"
	preserveAPFS="${8}"

##################################################
# Setup Functions

# Function containing new switches available in 10.13.4+
modernFeatures() {
	installSwitch+=("--agreetolicense")

	# macOS High Sierra 10.13.x option; File System Type?  APFS or HFS+
	if [[ "${1}" != "" && ("${macOSVersion}" == "High Sierra" || "${macOSVersion}" == "10.13") ]]; then
		echo "Convert to APFS:  ${1}"
		installSwitch+=("--converttoapfs ${1}")
	fi

	# macOS High Sierra 10.13.4+ Options:
	# Wipe Drive (if supported)?
	if [[ "${2}" == "Yes" ]]; then
		osVersion=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F '.' '{print $2"."$3}')
		fileSystemType=$(/usr/sbin/diskutil info / | /usr/bin/awk -F "File System Personality:" '{print $2}' | /usr/bin/xargs)

		if [[ $(/usr/bin/bc <<< "${osVersion} >= 13.4") -eq 1 && "${fileSystemType}" == "APFS" ]]; then
			echo "Erase Install:  ${2}"
			installSwitch+=("--eraseinstall --newvolumename" \'"${volumeName}"\')

			# macOS Mojave 10.14.0+ Options:
			# Preserve Volumes in APFS Container when using --eraseinstall
			if [[ "${3}" == "Yes" ]]; then
				if [[ "${macOSVersion}" == "Mojave" || "${macOSVersion}" == "10.14" ]]; then
					echo "Preserve Volumes in APFS Container:  ${3}"
					installSwitch+=("--preservecontainer")
				else
					echo "ERROR:  --preservecontainer is only supported on macOS 10.14 Mojave and newer!"
					echo "*****  install_macOS process:  FAILED  *****"
					exit 7
				fi
			fi

			# macOS High Sierra 10.13+ option
			# Check if device is DEP Enrolled, if it is not, stage a QuickAdd package to enroll after wiping drive and installing the new OS.
			if [[ $(/usr/bin/profiles status -type enrollment | /usr/bin/awk -F "Enrolled via DEP: " '{print $2}' | /usr/bin/xargs) == "No" ]]; then
				installSwitch+=("--installpackage ${packageName}")
			fi
		else
			# jamfHelper Install Failed
				inform "Failed"

			echo "ERROR:  Current FileSystem and/or OS Version is not supported!"
			echo "*****  install_macOS process:  FAILED  *****"
			exit 1
		fi
	fi
}

# Create USB Media Function
createUSB() {
	# Confirm the Installation Bundle still exists...
	if [[ -d "${upgradeOS}" ]]; then

		promptForChoice="tell application (path to frontmost application as text) to choose from list every paragraph of \"${volumeNames}\" with prompt \"Choose the volume to use:\" OK button name \"Select\" cancel button name \"Cancel\""
		selectedVolumeID=$(/usr/bin/osascript -e "$promptForChoice")
		# echo "Selected Volume:  ${selectedVolumeID}"

		# Handle if the user pushes the cancel button.
		if [[ $selectedVolumeID == "false" ]]; then
			echo "A volume selection was not made."
			createAnother="button returned:No"
			return
		fi

		# Get the Volume ID of the selected printer.
		selectedVolumeName=$(/usr/bin/printf "${selectedVolumeID}" | /usr/bin/awk -F '\\) ' '{print $2}')
		echo "Selected Volume:  ${selectedVolumeName}"

		# macOS High Sierra 10.13 and Mojave 10.14 no longer need the "--applicationpath" switch, including it only if it's not being installed
		if [[ "${macOSVersion}" == "Sierra" || "${macOSVersion}" == "10.12" || "${macOSVersion}" == "El Capitan" || "${macOSVersion}" == "10.11" ]]; then
			legacySwitch+=("--applicationpath" \'"${upgradeOS}"\')
		fi

		# jamfHelper CreatingMedia prompt
			inform "CreatingMedia"

		echo "Calling the createinstallmedia binary..."
		exitOutput=$(eval '"${upgradeOS}"'/Contents/Resources/createinstallmedia --volume '"/Volumes/${selectedVolumeName}"' --nointeraction ${legacySwitch[@]} 2>&1)

		# Grab the exit value.
		exitStatus=$?
		echo "*****  createinstallmedia exist status was:  ${exitStatus}  *****"
		echo "Exit Output was:  ${exitOutput%%$'\n'*}"

		# jamfHelper MediaCreated prompt
			inform "MediaCreated"
	else
		# jamfHelper Install Failed
			inform "Failed"

		echo "A cached macOS install Package was not found.  Aborting..."
		echo "*****  install_macOS process:  ERROR  *****"
		exit 4
	fi
}

# Setup jamfHelper Windows
inform() {

	## Title for all jamfHelper windows
	title="macOS Install"

	# Messages are based on the Workflow method chosen...
	case "${methodType}" in
		"Forced" )
			case "${1}" in
				"Installing" )
					## Setup jamfHelper window for Installing message
					windowType="hud"
					Heading="Initializing macOS..."
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
					Heading="Initializing macOS..."
					Description="This process may take some time depending on the configuration of the machine.
This computer will reboot and begin the install process shortly."
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
					Heading="Downloading macOS installatino media...                               "
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

Click OK when you are ready to continue; once you do so, the install process will begin."
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
					Heading="Initializing macOS..."
					Description="This process may take some time depending on the configuration of your machine.
Your computer will reboot and begin the install process."
					Icon="${upgradeOS}/Contents/Resources/ProductPageIcon.icns"
					extras=""
					waitOrGo="Go"
				;;
				"ManualFV" )
					## Setup jamfHelper window for Manual FileVault Restart message
					windowType="hud"
					Heading="Reboot Required                      "
					Description="For the install to continue, you will need to unlock the FileVault encrypted disk on this machine after the pending reboot."
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
					extras="-timeout 58 -button1 \"OK\" -defaultButton 1"
					waitOrGo="Go"
				;;
				"Failed" )
					## Setup jamfHelper window for Failed message
					windowType="hud"
					Heading="Failed to install macOS..."
					Description="If you continue to have issues, please contact your Deskside Support for assistance."
					Icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"
					extras="-button1 \"OK\" -defaultButton 1"
					waitOrGo="Go"
				;;
			esac
		;;
		"Create USB" )
			case "${1}" in
				"Download" )
					## Setup jamfHelper window for Downloading message
					windowType="hud"
					Heading="Downloading macOS installation media...                               "
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
					Description="Before continuing, please insert the USB drive(s) you wish to use.

Click OK when you are ready to continue and you will be prompted to select the volume to use."
					Icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInfo.icns"
					extras="-button1 OK"
					waitOrGo="Wait"
				;;
				"CreatingMedia" )
					## Setup jamfHelper window for Download Complete message
					windowType="hud"
					Heading="Creating USB Drive!                                         "
					Description="The selected drive will be wiped and used to create a USB Installation disk.

Please do not remove the USB drive."
					Icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInfo.icns"
					extras="-button1 OK"
					waitOrGo="Wait"
				;;
				"MediaCreated" )
					## Setup jamfHelper window for Download Complete message
					windowType="hud"
					Heading="Media creation is complete!                                         "
					Description="The drive is now ready to install macOS."
					Icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInfo.icns"
					extras="-button1 OK"
					waitOrGo="Go"
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
			echo "Downloading the macOS insatllation package from Jamf..."
				/usr/local/jamf/bin/jamf policy -event $downloadTrigger
			echo "Download complete!"

		# jamfHelper Download Complete prompt
			inform "DownloadComplete"
	}

# Function to check if the device is on AC or battery power first
	powerCheck() {
		until [[ $powerStatus == "PASSED" ]]; do

			powerSource=$(/usr/bin/pmset -g ps)

			if [[ ${powerSource} == *"AC Power"* ]]; then
				powerStatus="PASSED"
				echo "Power Status:  PASSED - AC Power Detected"
			else
				powerStatus="FAILED"
				echo "Power Status:  FAILED - AC Power Not Detected"
				# jamfHelper Plug in Power Adapter prompt
					inform "PowerMessage"
					userCanceled=$?

				if [[ $userCanceled == 0 ]]; then
					echo "User clicked OK"
				elif [[ "${methodType}" != "Self Service" ]]; then
					echo "This system is not on AC Power.  Aborting..."
					echo "*****  install_macOS process:  ABORTED  *****"
					exit 2
				else
					echo "User canceled the process.  Aborting..."
					echo "*****  install_macOS process:  CANCELED  *****"
					exit 3
				fi

				# Give user a few seconds to connect the power adapter before checking again...
				/bin/sleep 3

			fi
		done
	}

# Function for the Install Process
	installProcess() {

		# Confirm the Installation Bundle still exists...
		if [[ -d "${upgradeOS}" ]]; then

			# macOS Mojave 10.14 no longer needs the "--applicationpath" switch, including it only if it's not being installed
			if [[ "${macOSVersion}" != "Mojave" || "${macOSVersion}" != "10.14" ]]; then
				installSwitch+=("--applicationpath" \'"${upgradeOS}"\')
			fi

			# jamfHelper Install prompt
				inform "Installing"
				# Get the PID of the Jamf Helper Process incase the installation fails
				installInformPID=$!

			# Setting this key prevents the 'startosinstall' binary from rebooting the machine.
			/usr/bin/defaults write -globalDomain IAQuitInsteadOfReboot -bool YES

			echo "Calling the startosinstall binary..."
			exitOutput=$(eval '"${upgradeOS}"'/Contents/Resources/startosinstall --nointeraction ${installSwitch[@]} 2>&1)

			# Grab the exit value.
			exitStatus=$?
			echo "*****  startosinstall exist status was:  ${exitStatus}  *****"
			echo "Exit Output was:  ${exitOutput%%$'\n'*}"

			# Cleaning up, don't want to leave this key set as it's not documented.
			/usr/bin/defaults delete -globalDomain IAQuitInsteadOfReboot
		else
			# jamfHelper Install Failed
				inform "Failed"

			echo "ERROR:  A cached macOS installation package was not found.  Aborting..."
			echo "*****  install_macOS process:  FAILED  *****"
			exit 4
		fi
	}

# Function for the Reboot Process
	rebootProcess() {
		if [[ $exitStatus == 127 || $exitStatus == 255 || $exitOutput == *"Preparing reboot..."* ]]; then
				# Exit Code of '255' = Results on Sierra --> High Sierra
				# Exit Code of '127' = Results on Yosemite --> El Capitan
			echo "*****  The macOS install has been successfully staged.  *****"

			if [[ $statusFV == "true" ]]; then
				echo "Machine is FileVaulted."

				if [[ $authRestartFV == "true" ]]; then
					echo "Attempting an Authenticated Reboot..."
					checkAuthRestart=$(/usr/local/jamf/bin/jamf policy -event $authRestartFVTrigger)

					if [[ $checkAuthRestart == *"No policies were found for the \"${authRestartFVTrigger}\" trigger."* ]]; then
						# Function manualFileVaultReboot
							manualFileVaultReboot
					else
						echo "*****  install_macOS process:  SUCCESS  *****"
						exit 0
					fi
				else
					# Function manualFileVaultReboot
						manualFileVaultReboot
				fi
			else
				echo "Machine is not FileVaulted."
					inform "Reboot"

				# Function scheduleReboot
					scheduleReboot

				echo "*****  install_macOS process:  SUCCESS  *****"
				exit 0
			fi
		else

			# Kill the Full Screen Install Window
			/bin/kill $installInformPID
			wait $! 2>/dev/null

			# jamfHelper Install Failed
				inform "Failed"

			echo "*****  install_macOS process:  FAILED  *****"
			exit 5
		fi
	}

# Function for unsupported FileVault Authenticated Reboot.
	manualFileVaultReboot() {
		echo "Machine does not support FileVault Authenticated Reboots..."

		# jamfHelper Unsupported FileVault Authenticated Reboot prompt
			inform "ManualFV"

		# Function scheduleReboot
		scheduleReboot

		echo "*****  install_macOS process:  SUCCESS  *****"
		exit 0
	}

# Function to Schedule a Reboot in one minute.
	scheduleReboot() {
		echo "Scheduling a reboot one minute from now..."
		rebootTime=$(/bin/date -v "+1M" "+%H:%M")

		echo "Rebooting at $rebootTime"
		/sbin/shutdown -r $rebootTime
	}

##################################################
# Now that we have our work setup...

if [[ -z "${macOSVersion}" || -z "${methodType}" ]]; then
	echo "Failed to provide required options!"
	echo "*****  install_macOS process:  FAILED  *****"
	exit 6
fi

# Turn on case-insensitive pattern matching
shopt -s nocasematch

# Set the variables based on the version that is being provided.
case "${macOSVersion}" in
	"Mojave" | "10.14" )
		downloadIcon=${mojaveIconID}
		appName="Install macOS Mojave.app"
		downloadTrigger="${mojaveDownloadTrigger}"

		# Function modernFeatures
			modernFeatures "${convertAPFS}" "${eraseinstall}" "${preserveAPFS}"
	;;
	"High Sierra" | "10.13" )
		downloadIcon=$highSierraIconID
		appName="Install macOS High Sierra.app"
		downloadTrigger="${highSierraDownloadTrigger}"

		# Function modernFeatures
			modernFeatures "${convertAPFS}" "${eraseinstall}" "${preserveAPFS}"
	;;
	"Sierra" | "10.12" )
		downloadIcon=$sierraIconID
		appName="Install macOS Sierra.app"
		downloadTrigger="${sierraDownloadTrigger}"
		installSwitch+=("--agreetolicense")
	;;
	"El Capitan" | "10.11" )
		downloadIcon=$elCapitanIconID
		appName="Install OS X El Capitan.app"
		downloadTrigger="${elCapitanDownloadTrigger}"
		installSwitch+=("--volume /")
	;;
esac

# Turn off case-insensitive pattern matching
shopt -u nocasematch

# Download the icon from the JPS
/usr/bin/curl --silent $jamfPS/icon?id=$downloadIcon > /private/tmp/downloadIcon.png

# Check if the install .app is already present on the machine (no need to redownload the package).
if [[ -d "/Applications/${appName}" ]]; then
	echo "Using installation files found in /Applications"
	upgradeOS="/Applications/${appName}"
elif [[ -d "/tmp/${appName}" ]]; then
	echo "Using installation files found in /tmp"
	upgradeOS="/tmp/${appName}"
else
	# Function downloadInstaller
		downloadInstaller
	# Set the package name.
		upgradeOS="/tmp/${appName}"
fi

# This section handles if we want to create a USB.
if [[ "${methodType}" == "Create USB" ]]; then
	# Get a list of all externally mounted volumes.
		volumeInfo=$(diskutil list -plist external physical | /usr/bin/xmllint --format - | /usr/bin/xpath 'plist/dict/key[text()="VolumesFromDisks"]/following-sibling::array[1]' 2>/dev/null)
	# Get the number of externally mounted volumes.
		numberOfVolumes=$(echo $(/usr/bin/printf '%s\n' "$volumeInfo") | /usr/bin/xmllint --format - | /usr/bin/xpath 'count(//string)' 2>/dev/null)
	# Clear the variable, in case we're rerunning the process.
		unset volumeNames

	# Loop through each XML string element to only get the volume name and add in an "ID".
	for ((i=1; i<=$numberOfVolumes; ++i)); do
		volumeName=$(echo $(/usr/bin/printf '%s\n' "$volumeInfo") | /usr/bin/xmllint --format - | /usr/bin/xpath //string[$i] 2>/dev/null | LANG=C /usr/bin/sed -e 's/<[^/>]*>//g' | LANG=C /usr/bin/sed -e 's/<[^>]*>/\'$'\n/g')
		volumeNames+=$"${i}) ${volumeName}\n"
	done

	# Drop the final \n (newline).
		volumeNames=$(echo -e ${volumeNames} | /usr/bin/perl -pe 'chomp if eof')

	# We prompt to create another USB drive in the function; either continue creating more USB drives or complete script.
	until [[ $createAnother == "button returned:No" ]]; do
		# Function createPrinter
		createUSB
	done

	echo "*****  install_macOS process:  SUCCESS  *****"
	exit 0
else
	# Function powerCheck
		powerCheck
	# Function installProcess
		installProcess
	# Function rebootProcess
		rebootProcess
fi
