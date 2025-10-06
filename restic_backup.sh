#!/bin/bash

# ==== Configuration ====
loc="/usr/local/var/restic"
source "$loc/.restic_env"
LOGFILE="/usr/local/var/log/restic-backup.log"
RESTIC_BIN="/usr/local/bin/restic"  # adjust if different
PID_FILE="$loc/.restic_backup.pid"
TIMESTAMP_FILE="$loc/.restic_backup_timestamp"
get_date(){
    date '+%Y-%m-%d %H:%M:%S'
}
# ==== Logging ====
exec >> "$LOGFILE" 2>&1


# ==== Check: Power ====
if [[ $(pmset -g ps | head -1) =~ "Battery" ]]; then
  echo $(get_date) "Computer is not connected to the power source. Skipping Backup"
exit 4
fi
# ==== Check: Already running ====
if [ -f "$PID_FILE" ]; then
  if ps -p $(cat $PID_FILE) > /dev/null; then
    echo $(get_date) "File $PID_FILE exist. Probably backup is already in progress."
    exit 1
  else
    echo $(get_date) "File $PID_FILE exist but process " $(cat $PID_FILE) " not found. Removing PID file."
    rm $PID_FILE
  fi
fi
# ==== PID File ===
echo $$ > "$PID_FILE"
trap "rm -f $PID_FILE" EXIT
# ==== Check: Timestamp ====
if [ -f "$TIMESTAMP_FILE" ]; then
  time_run=$(cat "$TIMESTAMP_FILE")
  current_time=$(date +"%s")

  if [ "$current_time" -lt "$time_run" ]; then
    echo "[$(get_date)] running under 1 hour from last backup. Skipping backup."
    exit 2
  fi
fi

# === check network ====
if ! ping -q -c 1 -W 3 nas.blueflame47 > /dev/null; then
  echo "[$(get_date)] No network. Skipping backup."
  exit 2
fi
max_attempts=3
attempt=1
while [ $attempt -le $max_attempts ]; do
  #check nas mount and folder access
  if [[ ! -d $RESTIC_REPOSITORY ]]; then
    echo "$(get_date) nas backup folder unreachable, try mount nas."
    if [ $attempt -lt $max_attempts ]; then
      echo "$(get_date) Retrying in 5 minutes..."
      sleep 300
    fi
    if [ $attempt -eq $max_attempts ]; then
      exit 3
    fi
  else
    break
  fi
  attempt=$((attempt+1))
done

echo "[$(get_date)] === Backup started ==="

# ==== Unlock incomplete backups ====
echo "[$(get_date)] Unlocking stale locks..."
$RESTIC_BIN unlock
$RESTIC_BIN check
CHECK_EXIT_CODE=$?
if [ $CHECK_EXIT_CODE -eq 0 ]; 
then
  echo "[$(get_date)] Check successful, contiuning Backup."
else
  echo "[$(get_date)] Check FAILED with exit code $CHECK_EXIT_CODE."
  exit 1
fi
perform_backup() {
  # ==== Run the backup ====
  echo "[$(get_date)] Running restic backup..."
  $RESTIC_BIN backup --skip-if-unchanged \
                      --exclude-caches \
                      --one-file-system \
                      "${BACKUP_PATHS[@]}" \
                      "${EXCLUDES[@]}" \
                      "$EXCLUDE_FILE"
  BACKUP_EXIT_CODE=$?

  if [ $BACKUP_EXIT_CODE -eq 0 ]; 
  then
    echo "[$(get_date)] Backup completed successfully."
  else
    echo "[$(get_date)] Backup FAILED with exit code $BACKUP_EXIT_CODE."
    exit 1
  fi
}

# Run the backup for services defined in the config
perform_backup
backup_status=$?

# If the backup process completes successfully, run the forget step
if [ $backup_status -eq 0 ]; then
    echo "[$(get_date)] Running forget command..."

    # Execute restic forget with defined retention policy and show output
    $RESTIC_BIN forget --prune \
                      --keep-hourly 7 \
                      --keep-daily 10 \
                      --keep-weekly 8 \
                      --keep-monthly 11 \
                      --keep-yearly 1
    forget_status=$?
    # If forget fails, send failure status and log the failure
    if [ $forget_status -ne 0 ]; 
    then
        echo "[$(get_date)] restic forget FAILED, refer to logs"
        exit 1
    else
        echo "[$(get_date)] restic forget completed successfully."
        $RESTIC_BIN check 
        $RESTIC_BIN prune 
    fi
else
    # If the backup itself fails, report.
    echo "[$(get_date)] restic backup FAILED, refer to logs"
    exit 1
fi
# ==== update timestamp file ===
echo $(( $(date +"%s") + 3600 )) > "$TIMESTAMP_FILE"
echo "[$(get_date)] === Backup finished ==="

