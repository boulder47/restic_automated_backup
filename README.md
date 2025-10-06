# restic_automated_backup
A script for automatic restic backups.

We wrote this script to replace timemachine with a backup solution via restic.
Restic didn't have any automation built in so I found some scripts on Github and modified for better scenarios that included network and power and accessability (for laptop users).
This is written for MacOS but can be modified for Linux, etc.
We run via Launchd plist file.


This script runs the following:

backup hourly.

check backups before backing up.

runs forget and prune after each backup.

logs all content to a log.

checks for power,

checks for network,

checks for backup location readability

checks for already running backup.

keeps snapshots for:
--keep-hourly 7 \
--keep-daily 10 \
--keep-weekly 8 \
--keep-monthly 11 \
--keep-yearly 1


files included:
restic_backup.sh ( the script file ) place in /usr/local/bin/

.restic_env ( the enviroment variables for restic ) place in /usr/local/var/restic/ (or change location in main script)

backup_exclude.txt (places not to backup list) place in /usr/local/var/restic/ 

restic_backup.plist (launchd plist file) place in /Users/=macusername=/Library/LaunchAgents/ 


actions:

install restic: 
brew install restic

add exceutable to script:
chmod +x restic_backup.sh

add password to keychain:
security add-generic-password -s restic -a restic_pwd -w the_secret_password_to_secure_my_backups
(this must match the service and account in the .restic_env to retreve the correct info)

put files in proper place.

add permissions in macos
Privacy and Security > Full Disk Access > Restic binary = /usr/local/bin/restic
if encountering more errors add Bask = /bin/bash

Apple Silicon notes:
homebrew location change for Arm64
/opt/homebrew/bin/restic (change in main script)

load launchd plist:
launchctl load /Users/=macusername=/Library/LaunchAgents/restic_backup.plist

Initilize repo and test password with init_repo.sh script. (check restic binary path)

Files created from scripts:

Log file: /usr/local/var/log/restic-backup.log

pid file: /usr/local/var/restic/.restic_backup.pid

timestamp file: /usr/local/var/restic/.restic_backup_timestamp

(we also wrote a installer script (zero-touch deployment script) that we might add here too.
