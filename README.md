# install_macOS

I have renamed this project as the overall scope and functionality has changed.

I have added several new pieces of functionality which I have documented below.


<img src="https://github.com/MLBZ521/install_macOS/blob/master/images/upgrade_macOS.png" width="512" height="512" />

The overall scope of this project is to:
  * Easily provide in-place upgrades of macOS or reprovision a Mac easily through a Policy and script
  * Allow Full Jamf Admins to provide a way for Site Admins to easily utilize the script without having to do more than create a Policy with a script
  * Allow Full Jamf Admins to provide a way for Site Admins to easily create USB installation media (Using the `createinstallmedia` utility)

Essentially, this is a script that can be used to initiate an upgrade of macOS via Self Service (or force an upgrade on clients) or reprovision a Mac using the --eraseinstall flag.  The script is added to a policy and will call pre-configured policies that complete the upgrade task.

I'm using the `startosinstall` binary which supports the following:
  * Upgrading to macOS 10.11 through 10.14
  * Upgrading from macOS 10.10 and newer


**Features that I may add in the future**
  * Specify macOS version to look for on a locally cached "Install macOS <version>.app"


**Inspired by**
  * Numerous discussions on JamfNation on the subject
  * Several scripts and code snippets posted on JamfNation and GitHub
  * Uses the `IAQuitInsteadOfReboot` preference [documented](https://github.com/munki/munki/blob/master/code/client/munkilib/osinstaller.py) by Greg Neagle


## Features ##

  * In-place upgrades or clean installs available via selectable methods:
    * The main difference in these methods are the status prompts that are displayed to the user
      * Self Service
      * Forced Upgrade
        * The native install process requires a user to be logged into the device
      * Classroom
    * Create USB
      * Create a USB Installation Media on an external device
  * Specify the macOS version to upgrade too
  * Self Service 'download' icons [have been uploaded](https://github.com/MLBZ521/install_macOS/tree/master/images/) for each macOS version
  * The Extension Attribute `Latest OS Supported` is available that reports compatibility for 10.11 and newer OS Versions (checks supported hardware models, 2GB RAM, and 20GB free space)
  * Will display status messages as the script runs, informing the user of the progress (using `Jamf Helper`)
  * Check to see if the installation files are already present on the machine, if they are, it will not download them from the JPS
  * Requires AC Power before beginning the installation phase
  * If the machine is FileVaulted and supports performing an Authenticated Reboot, it will perform one (only works if the JPS has the FileVault Key); if not, it will schedule a reboot in one minute
  * **Will** upgrade the firmware (which is required for APFS conversion in High Sierra) -- the process mimics the native install process and will upgrade the firmware
  * All script verbosity should be recorded into the Policy Logs in the JPS
  * Modern Features
    * 10.13.x:
      * Allows for the FileSystem type to be selected (--convertToAPFS)
        * default (i.e.  SSD is converted to APFS, HDD is not converted -- APFS is not supported on Fusion drives, as of 10.13)
        * convert to APFS
        * do not convert to APFS
    * 10.13.x+:
      * Allows for the installation of a package post upgrade (--installpackage)
        * In this script, this switch is configured to only be used after an erase install performed, to re-enroll a device that is **NOT** currently DEP enrolled
    * 10.13.4+:
      * Allows for an erase install to be performed (--eraseinstall)
      * Allows for a specific Volume Name to be specified in the script and used when the erase install flag is used (--newvolumename)
    * 10.14.x:
      * Allows for the option to preserve other volumes within the APFS container if an erase install used (--preservecontainer)

## Troubleshooting ##

If the script fails, the exit codes should be logged to the JPS for review; exit codes are:
  * Exit 1 - Current FileSystem and OS Version does not support the --eraseinstall and --newvolumename switches
  * Exit 2 - On a non-Self Service Method, if the system is not on AC Power
  * Exit 3 - User canceled the process during the Power Adapter check phase
  * Exit 4 - Could not locate the installation package during the install phase
  * Exit 5 - Unexpected exit code from the installation phase
  * Exit 6 - The OS Version and/or the Method Type was not supplied in the script parameters
  * Exit 7 - Preserve Container is only supported on macOS 10.14 Mojave and newer


## Setup ##

Setup required by the Full Jamf Admin:
  * Add `install_macOS.sh` to JPS; edit as needed:
    * [OS Icon URLs](https://github.com/MLBZ521/install_macOS/tree/master/images/)
    * Custom Triggers Used
  * Upload macOS Version Icons
  * Create and upload packages for each OS Version to JPS
  * Create Policies:
    * For each OS Version, each with a custom -trigger specific to the OS Version (i.e. `macOSUpgrade_HighSierra`)
    * A Policy that performs an Authenticated Reboot (scoped to compatible machines)


## Usage ##

How a Full/Site Admin will use the script:
  * Create a Policy using the `install_macOS.sh` script
  * Set the OS version, via the Script Parameter, they want to make available; options are:
    * `Mojave` or `10.14`
    * `High Sierra` or `10.13`
    * `Sierra` or `10.12`
    * `El Capitan` or `10.11`
  * Set the Method Type:
    * `Self Service`
    * `Forced`
    * `Classroom`
    * `Create USB`
      * No other settings are needed if using `Create USB`
  * High Sierra Features:
    * Set File System Type (Convert to APFS?)
      * `Yes`
      * `No`
      * Nothing (Or Default)
    * High Sierra 10.13.4 + Features:
      * Erase Disk
        * `Yes`
        * `No`

## Logic ##

  * Checks which macOS Version was supplied via Script Parameters and defines variables based on this
  * Checks if the `Install macOS <Version>.app` bundle already exists in the expect locations:
    * /Applications
    * /tmp
  * If it doesn't exist
    * Displays a Jamf Helper window stating download is in progress
    * Calls the macOS Version download trigger
    * Once download is complete, displays a Jamf Helper window stating download has completed
  * Checks for AC Power
    * If **not** on AC Power
      * Displays a Jamf Helper window stating AC Power Required
      * After clicking ok, delays three seconds for user to plug in AC Power
      * Until loop, waiting for AC Power
  * Installs process begins and displays a full screen Jamf Helper window stating Install in progress
  * Verifies Exit Code was expected (not an error)
  * Verifies if machine is FileVault Enabled
    * If FileVault Disabled:
      * Performs a scheduled reboot in one minute
    * If FileVault Enabled:
      * Verifies if machine supports Authenticated Reboots; if it does
        * Attempts running the Authenticated Reboot trigger; if it fails
          * Performs a scheduled reboot in one minute 


**All icons and logos are property of [Apple](http://www.apple.com).**