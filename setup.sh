#!/bin/bash
SSD_PATH=$(find /dev/ | grep google-local-nvme-ssd)
SSD_COUNT=$(find /dev/ | grep google-local-nvme-ssd | wc -l)
SSD_NAME=$(basename "$SSD_PATH")
BUCKET_NAME=vaani-tts-master
BUCKET_MOUNT_POINT=$HOME/gcs
FAST_STORAGE_MOUNT_POINT=/mnt/ssd
echo "$SSD_NAME"

setup() {
  # Unmount and remove existing mount points
  if [ -d "$BUCKET_MOUNT_POINT" ]; then
    read -p "Warning: This will unmount and remove $BUCKET_MOUNT_POINT. Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      sudo umount $BUCKET_MOUNT_POINT
      sudo rm -r $BUCKET_MOUNT_POINT
    else
      echo "Skipping unmount of $BUCKET_MOUNT_POINT"
    fi
  fi
  if [ -d "$FAST_STORAGE_MOUNT_POINT" ]; then
    read -p "Warning: This will unmount and remove $FAST_STORAGE_MOUNT_POINT. Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      sudo umount $FAST_STORAGE_MOUNT_POINT
      sudo rm -r $FAST_STORAGE_MOUNT_POINT
    else
      echo "Skipping unmount of $FAST_STORAGE_MOUNT_POINT"
    fi
  fi
  # Create and set permissions for mount points
  if [ ! -d "$FAST_STORAGE_MOUNT_POINT" ]; then
    sudo mkdir -p $FAST_STORAGE_MOUNT_POINT
    sudo chmod -R 777 $FAST_STORAGE_MOUNT_POINT
  fi
}

mount_ssd() {
  # Install mdadm and create RAID array
  sudo apt update
  sudo apt install -y mdadm --no-install-recommends
  sudo mdadm --create /dev/md0 --level=0 --raid-devices=$SSD_COUNT --force $SSD_PATH
  # Format and mount the RAID array
  sudo mkfs.ext4 -F /dev/md0
  # Mount the RAID array
  sudo mount /dev/md0 $FAST_STORAGE_MOUNT_POINT
  # Set permissions for the mount point
  sudo chmod a+w $FAST_STORAGE_MOUNT_POINT
}

mount_gcs() {
  # Mount the GCS bucket
  gcsfuse --metadata-cache-ttl-secs=-1 \
    --stat-cache-max-size-mb=-1 \
    --type-cache-max-size-mb=-1 \
    $BUCKET_NAME $BUCKET_MOUNT_POINT
}

umount_all() {
  # Unmount and remove existing mount points
  sudo umount $FAST_STORAGE_MOUNT_POINT
  sudo rm -r $FAST_STORAGE_MOUNT_POINT
  sudo umount $BUCKET_MOUNT_POINT
  sudo rm -r $BUCKET_MOUNT_POINT
}

install_uv() {
  # Install uv
  sudo apt update
  sudo apt install -y --no-install-recommends curl
  curl -LsSf https://astral.sh/uv/install.sh | sh
  source $HOME/.bashrc
}

install_gcsfuse() {
  # Install gcsfuse
  sudo apt-get update
  sudo apt-get install -y curl lsb-release
  export GCSFUSE_REPO=gcsfuse-$(lsb_release -c -s)
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.asc] https://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo tee /usr/share/keyrings/cloud.google.asc
  sudo apt-get update
  sudo apt-get install gcsfuse
}
symlink_drives() {
  # Symlink the mount points
  if [ ! -d "$HOME/space" ]; then
    ln -s $FAST_STORAGE_MOUNT_POINT $HOME/space
  else
    echo "Space directory already exists"
    # Remove the symlink
    rm $HOME/space
    ln -s $FAST_STORAGE_MOUNT_POINT $HOME/space
  fi

}

first_time_setup() {
  install_gcsfuse
  install_uv
  mount_ssd
  mount_gcs
  symlink_drives
}

resume_setup() {
  mount_ssd
  mount_gcs
  symlink_drives
}

setup_other_user() {
  mount_gcs
  symlink_drives
}
