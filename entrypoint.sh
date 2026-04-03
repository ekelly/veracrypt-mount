#!/bin/bash

# Function to handle cleanup
cleanup() {
  echo "Received SIGTERM, cleaning up..."

  # Unmount all bind mounts first
  # tac reverses the list to unmount nested structures before their parents
  grep "/decrypted/" /proc/mounts | awk '{print $2}' | tac | while read -r mount_point; do
    echo "Unmounting bind: $mount_point"
    umount "$mount_point"
  done

  # Dismount all VeraCrypt volumes
  echo "Dismounting all VeraCrypt volumes..."
  veracrypt --text --unmount

  # Verify the dismount
  echo "Verifying device mappers are cleared..."
  sleep 3

  if ls /dev/mapper/veracrypt* >/dev/null 2>&1; then
    echo "Warning: VeraCrypt devices still present. Attempting force dismount..."
    veracrypt --text --unmount --force

    # Dismount check
    sleep 1
    if ls /dev/mapper/veracrypt* >/dev/null 2>&1; then
      echo "Error: Could not clear all VeraCrypt devices."
      ls /dev/mapper/veracrypt*

      # Manual cleanup fallback for stuck mappers
      echo "Mappers still exist. Forcing removal via dmsetup..."
      for dev in /dev/mapper/veracrypt*; do
        NAME=$(basename "$dev")
        dmsetup remove --force "$NAME"
      done

      # Final check
      if ls /dev/mapper/veracrypt* >/dev/null 2>&1; then
        echo "Dismount failure. Mappers still exist"
	exit 0
      fi
    else
      echo "Force dismount successful."
    fi
  else
    echo "All VeraCrypt volumes dismounted successfully."
  fi

  exit 0
}

# Register the cleanup function for SIGTERM
trap 'cleanup' SIGTERM

# Loop through variables VOLUME_0, VOLUME_1, etc.
i=0
while true; do
  # Dynamically reference variables for index i
  FILE_VAR="VOLUME_${i}_FILE"
  PW_VAR="VOLUME_${i}_PW"
  FS_VAR="VOLUME_${i}_FS"
  SUB_VAR="VOLUME_${i}_SUBFOLDERS"

  # Check if the file variable for this index exists
  FILE_PATH="${!FILE_VAR}"
  if [ -z "$FILE_PATH" ]; then
    break
  fi

  PASSWORD="${!PW_VAR}"
  FILESYSTEM="${!FS_VAR:-ext4}" # Default to ext4 if not specified
  SUBFOLDERS="${!SUB_VAR}"

  # Internal mount point for the raw mapper device
  RAW_MOUNT="/mnt/veracrypt_raw_$i"
  mkdir -p "$RAW_MOUNT"

  echo "Mounting volume $i: $FILE_PATH"

  # Map the encrypted file to a device mapper
  veracrypt --text --non-interactive --password="$PASSWORD" --filesystem=none "$FILE_PATH"

  # VeraCrypt maps volumes sequentially to /dev/mapper/veracrypt1, 2, etc.
  MAPPER_DEV="/dev/mapper/veracrypt$((i+1))"

  echo "Waiting for $MAPPER_DEV..."
  COUNT=0
  while [ ! -b "$MAPPER_DEV" ] && [ $COUNT -lt 5 ]; do
      sleep 1
      ((COUNT++))
  done

  if [ -b "$MAPPER_DEV" ]; then
      mount -t "$FILESYSTEM" "$MAPPER_DEV" "$RAW_MOUNT"

      # Handle Subfolders or full volume bind
      if [ -n "$SUBFOLDERS" ]; then
        IFS=',' read -ra SUBFOLDER_ARRAY <<< "$SUBFOLDERS"
        for SUBFOLDER in "${SUBFOLDER_ARRAY[@]}"; do
          TARGET="/decrypted/vol${i}/$SUBFOLDER"
          echo "Binding $SUBFOLDER to $TARGET"
          mkdir -p "$TARGET"
          mount --bind "$RAW_MOUNT/$SUBFOLDER" "$TARGET"
        done
      else
        # If no subfolders specified, bind the entire volume root
        TARGET="/decrypted/vol${i}"
        echo "Binding entire volume to $TARGET"
        mkdir -p "$TARGET"
        mount --bind "$RAW_MOUNT" "$TARGET"
      fi
  else
      echo "Error: $MAPPER_DEV not found for $FILE_PATH"
      # exit 1
  fi

  ((i++))
done

if [ $i -eq 0 ]; then
    echo "No volumes configured (VOLUME_0_FILE not found). Exiting."
    exit 1
fi

# Wait indefinitely in the background so the script can catch signals
tail -f /dev/null &
wait $!

