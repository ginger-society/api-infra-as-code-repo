#!/bin/bash
# kind-disk-reaper.sh
#
# Periodic sweep for orphaned per-cluster disk images left behind by
# delete-cluster.sh when an umount/losetup -d failed mid-teardown (see that
# script's comments — on failure it deliberately leaves the .meta file in
# place rather than deleting it, specifically so this reaper has something
# to find and retry later instead of the leak vanishing silently).
#
# Safe to run as a cron/systemd-timer job (e.g. every 15-30 min). Runs as
# root — same context as create/delete-cluster.sh, so no $HOME ambiguity.
#
# A .meta file is considered orphaned if EITHER:
#   (a) its cluster no longer appears in `kind get clusters`, or
#   (b) the mount is already gone (someone/something cleaned up the mount
#       but the .meta + image file never got removed)
# Either case means it's safe to finish tearing down.
#
# A .meta file whose cluster IS still running is left completely alone —
# this script only ever touches disks for clusters that are already gone.

set -u

LOOP_IMAGE_DIR="/var/kind-disks"
LOG_PREFIX="[kind-disk-reaper]"

if [ ! -d "$LOOP_IMAGE_DIR" ]; then
  echo "${LOG_PREFIX} nothing to do — ${LOOP_IMAGE_DIR} doesn't exist"
  exit 0
fi

shopt -s nullglob
META_FILES=("${LOOP_IMAGE_DIR}"/*.meta)
shopt -u nullglob

if [ ${#META_FILES[@]} -eq 0 ]; then
  echo "${LOG_PREFIX} no .meta files found — nothing to reap"
  exit 0
fi

# Snapshot once rather than shelling out to `kind get clusters` per-file.
LIVE_CLUSTERS=$(kind get clusters 2>/dev/null)

REAPED=0
SKIPPED_LIVE=0
FAILED=0

for META_FILE in "${META_FILES[@]}"; do
  # Reset per-iteration vars — meta files source LOOP_DEV/LOOP_IMAGE/MOUNT_POINT
  # into the shell, and a stale value leaking from a previous iteration would
  # be a nasty silent bug (e.g. unmounting the wrong path).
  unset LOOP_DEV LOOP_IMAGE MOUNT_POINT
  # shellcheck disable=SC1090
  source "$META_FILE"

  CLUSTER_NAME=$(basename "$META_FILE" .meta)

  if [ -z "${MOUNT_POINT:-}" ] || [ -z "${LOOP_DEV:-}" ] || [ -z "${LOOP_IMAGE:-}" ]; then
    echo "${LOG_PREFIX} ⚠️  ${META_FILE} is malformed (missing fields) — skipping, needs manual inspection"
    FAILED=$((FAILED + 1))
    continue
  fi

  if echo "$LIVE_CLUSTERS" | grep -q "^${CLUSTER_NAME}$"; then
    # Cluster is still alive — this .meta file is legitimate and current,
    # not orphaned. Never touch disks for running clusters.
    SKIPPED_LIVE=$((SKIPPED_LIVE + 1))
    continue
  fi

  echo "${LOG_PREFIX} found orphaned disk for absent cluster '${CLUSTER_NAME}' — reaping"

  UMOUNT_OK=1
  LOSETUP_OK=1

  if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    umount "$MOUNT_POINT" 2>/dev/null
    if [ $? -ne 0 ]; then
      echo "${LOG_PREFIX} ⚠️  still can't unmount ${MOUNT_POINT} for '${CLUSTER_NAME}' — leaving for next sweep"
      UMOUNT_OK=0
    fi
  fi

  if [ "$UMOUNT_OK" -eq 1 ]; then
    # losetup -d on a device that's already detached just errors harmlessly —
    # check first so we don't misreport a no-op as a failure.
    if losetup "$LOOP_DEV" &>/dev/null; then
      losetup -d "$LOOP_DEV" 2>/dev/null
      if [ $? -ne 0 ]; then
        echo "${LOG_PREFIX} ⚠️  still can't detach ${LOOP_DEV} for '${CLUSTER_NAME}' — leaving for next sweep"
        LOSETUP_OK=0
      fi
    fi
  fi

  if [ "$UMOUNT_OK" -eq 1 ] && [ "$LOSETUP_OK" -eq 1 ]; then
    rm -f "$LOOP_IMAGE" "$META_FILE"
    rmdir "$MOUNT_POINT" 2>/dev/null || true
    sed -i "\|${MOUNT_POINT}|d" /etc/fstab
    echo "${LOG_PREFIX} ✅ reaped disk for '${CLUSTER_NAME}' (freed $(du -h "$LOOP_IMAGE" 2>/dev/null | cut -f1 || echo 'unknown'))"
    REAPED=$((REAPED + 1))
  else
    echo "${LOG_PREFIX} ⚠️  '${CLUSTER_NAME}' still not fully cleaned up — will retry next sweep"
    FAILED=$((FAILED + 1))
  fi
done

echo "${LOG_PREFIX} sweep complete — reaped: ${REAPED}, still-live (skipped): ${SKIPPED_LIVE}, still-failing: ${FAILED}"

# Non-zero exit if anything is still stuck, so a cron/systemd wrapper can
# alert on repeated failures rather than this failing silently forever.
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0