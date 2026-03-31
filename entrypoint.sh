#!/bin/bash

# Function to handle cleanup
cleanup() {
  echo "Received SIGTERM, cleaning up..."

  # Unmount bind mounts in reverse order
  if [ -n "$SUBFOLDERS" ]; then
    IFS=',' read -ra SUBFOLDER_ARRAY <<< "$SUBFOLDERS"
    # Iterate backwards to unmount nested structures safely
    for (( i=${#SUBFOLDER_ARRAY[@]}-1; i>=0; i-- )); do
      SUBFOLDER="${SUBFOLDER_ARRAY[$i]}"
      echo "Unmounting subfolder: $SUBFOLDER"
      umount "/decrypted/$SUBFOLDER"
    done
  fi

  # Dismount the VeraCrypt volume
  echo "Dismounting VeraCrypt volume..."
  veracrypt --text --dismount
 
  exit 0
}

# Register the cleanup function for SIGTERM
trap 'cleanup' SIGTERM

# Mount the encrypted volume to the temporary mount point
veracrypt --text --non-interactive --verbose --password="$VERACRYPT_PASSWORD" --filesystem=none /encrypted-file

echo "Waiting for device mapper..."
MAX_RETRIES=5
COUNT=0
while [ ! -b "/dev/mapper/veracrypt1" ] && [ $COUNT -lt $MAX_RETRIES ]; do
    sleep 1
    ((COUNT++))
done

if [ -b "/dev/mapper/veracrypt1" ]; then
    echo "VeraCrypt volume is mapped and ready."
    mount -t $FILESYSTEM /dev/mapper/veracrypt1 /encrypted-mount
else
    echo "Error: /dev/mapper/veracrypt1 not found."
    exit 1
fi

# Check if the SUBFOLDERS environment variable is set
if [ -n "$SUBFOLDERS" ]; then
  # Split the SUBFOLDERS variable into an array using a comma as the delimiter
  IFS=',' read -ra SUBFOLDER_ARRAY <<< "$SUBFOLDERS"

  # Iterate over the subfolders and bind mount them
  for SUBFOLDER in "${SUBFOLDER_ARRAY[@]}"; do
    echo "Mounting subfolder: $SUBFOLDER"
    mkdir -p "/decrypted/$SUBFOLDER"
    mount --bind "/encrypted-mount/$SUBFOLDER" "/decrypted/$SUBFOLDER"
  done
else
  mount --bind "/encrypted-mount" "/decrypted/$SUBFOLDER"
fi

# Wait indefinitely in the background so the script can catch signals
# Keep the container running
tail -f /dev/null &
wait $!
