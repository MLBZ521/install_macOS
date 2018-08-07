# upgrade_macOS

![upgrade_macOS](https://github.com/MLBZ521/upgrade_macOS/blob/master/images/upgrade_macOS.png "upgrade_macOS icon")

The overall scope of this project is to:
  * Allow Full JSS Admins to provide a way for Site Admins to easily make in-place upgrades of macOS available without having to do more than create a policy.

Essentially, this is a script that can be used to initiate an upgrade of macOS via Self Service (or force an upgrade on clients).  The script is added to a policy and will call pre-configured policies that complete the upgrade task.

I'm using the `startosinstall` binary which supports the following:
  * Upgrading to macOS 10.13, 10.12, and 10.11
  * Upgrading from macOS 10.10 and newer


**Features that I may add in the future**
  * ~~Support for 10.12 and possibly 10.11~~ - Added!
  * ~~A 'forced' upgrade option (currently this is configured for Self Service Only)~~ - Added!
  * ~~APFS conversion option (i.e. do or do not convert to APFS)~~ - Added!


**Inspired by**
  * Numerous discussions on JamfNation on the subject
  * Several scripts and code snippets posted on JamfNation and GitHub
  * Uses the `IAQuitInsteadOfReboot` preference [documented](https://github.com/munki/munki/blob/master/code/client/munkilib/osinstaller.py) by Greg Neagle


## Features ##

  * In-place upgrades available via Self Service, Force Upgrade, or for a "Classroom" Upgrade
  * Self Service 'download' icons [have been uploaded](https://github.com/MLBZ521/upgrade_macOS/tree/master/images/) for each macOS version
  * The Extension Attribute `Latest OS Supported` is available that reports compatibility for 10.11 and newer OS Versions; checks supported hardware models, 4GB RAM, and 20GB free space)
  * Will display status messages as the script runs, informing the user of the progress (using `Jamf Helper`)
  * Check to see if the installation files are already present on the machine, if they are, it will not download them from the JSS
  * Requires AC Power before beginning the installation phase
  * **Will** upgrade the firmware (which is required for APFS conversion in High Sierra)
  * Allows for the FileSystem type to be selected:
    * default (i.e.  SSD is converted to APFS, HDD is not converted -- APFS is not supported on Fusion drives, as of 10.13)
    * convert to APFS
    * do not convert to APFS
  * Allows for the option to wipe the drive and reload fresh (10.13.4+ features)
  * If the machine is FileVaulted and supports performing an Authenticated Reboot, it will perform one (only works if the JSS has the FileVault Key); if not, it will schedule a reboot in one minute
  * If the script fails, the exit codes should be logged to the JSS for review; exit codes are:
    * Exit 1 - Current FileSystem and OS Version does not support the --eraseinstall and --newvolumename switches
    * Exit 2 - On a non-Self Service Method, if the system is not on AC Power
    * Exit 3 - User canceled the process during the Power Adapter check phase
    * Exit 4 - Could not locate the installation package during the install phase
    * Exit 5 - Unexpected exit code from the installation phase


## Setup ##

Setup required by the Full JSS Admin:
  * Add `upgrade_macOS.sh` to JSS; edit as needed:
    * [OS Icon URLs](https://github.com/MLBZ521/upgrade_macOS/tree/master/images/)
    * Custom Triggers Used
  * Upload macOS Version Icons
  * Create and upload packages for each OS Version to JSS
  * Create Policies:
    * For each OS Version, each with a custom -trigger specific to the OS Version (i.e. `macOSUpgrade_HighSierra`)
    * A Policy that performs an Authenticated Reboot (scoped to compatible machines)


## Usage ##

How a Site Admin will use the script:
  * Create a Policy using the `upgrade_macOS.sh` script
  * Set the OS version, via the Script Parameter, they want to make available; options are:
    * "`High Sierra`" or "`10.13`"
    * "`Sierra`" or "`10.12`"
    * "`El Capitan`" or "`10.11`"
  * Set the Method Type:
    * "`Self Service`"
    * "`Forced`"
    * "`Classroom`"
  * High Sierra Features:
    * Set File System Type (Convert to APFS?)
      * "`Yes`"
      * "`No`"
      * Nothing (Or Default)
    * High Sierra 10.13.4 + Features:
      * Erase Disk
        * "`Yes`"
        * "`No`"

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

Logs each step to `system.log`


**All icons and logos are property of [Apple](http://www.apple.com).**