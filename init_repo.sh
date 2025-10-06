#!/bin/bash
# ==== Configuration ====
loc="/usr/local/var/restic"
source "\$loc/.restic_env"
LOGFILE="/usr/local/var/log/restic-backup.log"
RESTIC_BIN="$restic_bin"  # adjust if different
DATE="\$(date '+%Y-%m-%d %H:%M:%S')"
PID_FILE=\$loc/.restic_backup.pid
TIMESTAMP_FILE=\$loc/.restic_backup_timestamp


# ==== Run the backup ====
echo "[\$DATE] Running restic init..."
\$RESTIC_BIN init 
