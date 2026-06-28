#!/bin/bash
# Hermes control plane — first-boot bootstrap (Chapter 9)
# Mounts hermes-models (/models) and hermes-data (/data) EBS volumes.
set -euxo pipefail
exec > /var/log/hermes-bootstrap.log 2>&1

HOSTNAME="hermes-controlplane-01"
MODELS_MOUNT="/models"
DATA_MOUNT="/data"

hostnamectl set-hostname "$HOSTNAME"
echo "127.0.1.1 $HOSTNAME" >> /etc/hosts

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
  curl \
  git \
  unzip \
  htop \
  jq \
  tree \
  nvme-cli \
  xfsprogs

mkdir -p "$MODELS_MOUNT" "$DATA_MOUNT"

mount_volume_by_size() {
  local size_g="$1"
  local mount_point="$2"
  local dev=""
  while read -r name size type; do
    [[ "$type" != "disk" ]] && continue
    [[ "$size" != "${size_g}G" ]] && continue
    candidate="/dev/${name}"
    if mount | grep -q "${candidate} "; then continue; fi
    if findmnt -rn -S "$mount_point" >/dev/null 2>&1; then return 0; fi
    dev="$candidate"
    break
  done < <(lsblk -dn -o NAME,SIZE,TYPE)
  if [[ -z "$dev" ]]; then
    echo "WARN: no ${size_g}G volume found for ${mount_point}" >> /var/log/hermes-bootstrap.log
    return 0
  fi
  if ! blkid "$dev" >/dev/null 2>&1; then mkfs.xfs "$dev"; fi
  uuid=$(blkid -s UUID -o value "$dev")
  if ! grep -q "$uuid" /etc/fstab; then
    echo "UUID=$uuid $mount_point xfs defaults,nofail 0 2" >> /etc/fstab
  fi
  mount -a
}

# hermes-models 300G, hermes-data 100G (Nitro: nvme1n1/nvme2n1 or sdf/sdg)
mount_volume_by_size 300 "$MODELS_MOUNT"
mount_volume_by_size 100 "$DATA_MOUNT"

mkdir -p \
  /opt/hermes /opt/config /opt/scripts /backups \
  "$MODELS_MOUNT"/{qwen,mistral,llama} \
  "$DATA_MOUNT"/{postgres,redis,vector}

chown -R ubuntu:ubuntu /opt/hermes /opt/config /opt/scripts /backups "$MODELS_MOUNT" "$DATA_MOUNT" 2>/dev/null || true

touch /var/lib/hermes-bootstrap-complete
echo "Hermes bootstrap finished $(date -Is)" >> /var/log/hermes-bootstrap.log
