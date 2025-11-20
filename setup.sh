#!/bin/bash
SSD_PATH=$(find /dev/ | grep google-local-nvme-ssd)
SSD_COUNT=$(find /dev/ | grep google-local-nvme-ssd | wc -l)
SSD_NAME=$(basename "$SSD_PATH")
BUCKET_NAME=vaani-tts-master
BUCKET_MOUNT_POINT=/mnt/gcs
FAST_STORAGE_MOUNT_POINT=/mnt/ssd
sudo mkdir -p $BUCKET_MOUNT_POINT
sudo mkdir -p $FAST_STORAGE_MOUNT_POINT
sudo chmod -R 777 $BUCKET_MOUNT_POINT
sudo chmod -R 777 $FAST_STORAGE_MOUNT_POINT
echo "$SSD_NAME"

setup() {
  sudo mkdir -p $BUCKET_MOUNT_POINT
  sudo mkdir -p $FAST_STORAGE_MOUNT_POINT
  sudo chmod -R 777 $BUCKET_MOUNT_POINT
  sudo chmod -R 777 $FAST_STORAGE_MOUNT_POINT
}

mount_ssd() {
  sudo apt update
  sudo apt install -y mdadm --no-install-recommends
  sudo mdadm --create /dev/md0 --level=0 --raid-devices=$SSD_COUNT --force $SSD_PATH
  sudo mkfs.ext4 -F /dev/md0
  sudo mount /dev/md0 $FAST_STORAGE_MOUNT_POINT
  sudo chmod a+w $FAST_STORAGE_MOUNT_POINT
}
mount_gcs() {
  gcsfuse --metadata-cache-ttl-secs=-1 \
    --stat-cache-max-size-mb=-1 \
    --type-cache-max-size-mb=-1 \
    $BUCKET_NAME $BUCKET_MOUNT_POINT
}
umount_all() {
  sudo umount $FAST_STORAGE_MOUNT_POINT
  sudo rm -r $FAST_STORAGE_MOUNT_POINT
  sudo umount $BUCKET_MOUNT_POINT
  sudo rm -r $BUCKET_MOUNT_POINT
}
install_uv() {
  sudo apt update
  sudo apt install -y --no-install-recommends curl
  curl -LsSf https://astral.sh/uv/install.sh | sh
  source $HOME/.bashrc
}
install_gcsfuse() {
  sudo apt-get update
  sudo apt-get install -y curl lsb-release
  export GCSFUSE_REPO=gcsfuse-$(lsb_release -c -s)
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.asc] https://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo tee /usr/share/keyrings/cloud.google.asc
  sudo apt-get update
  sudo apt-get install gcsfuse
}
symlink_drives() {
  ln -s $FAST_STORAGE_MOUNT_POINT $HOME/space
  ln -s $BUCKET_MOUNT_POINT $HOME/gcs
}

tatadada() {
  install_gcsfuse
  install_uv
  mount_ssd
  mount_gcs
  symlink_drives
}
