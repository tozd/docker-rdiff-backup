#!/bin/bash -e

. /dev/shm/cron-environment

DOCKER_ROOT_DIR=$(docker info --format '{{.DockerRootDir}}')
DOCKER_CONTAINER_ID=$(basename "$(cat /proc/1/cpuset)")
BACKUP_VOLUME_DIR=$(docker inspect --format='{{range .Mounts}}{{if eq .Destination "/backup"}}{{.Source}}{{end}}{{end}}' "$DOCKER_CONTAINER_ID")

RANDOM_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
RANDOM_PATH="/tmp/$RANDOM_KEY"

function cleanup {
  rm -f "$RANDOM_PATH"
}
trap cleanup EXIT

ln -s /source/host "$RANDOM_PATH"

/usr/bin/find "$RANDOM_PATH/" \
 -path "$RANDOM_PATH/dev" -prune -or \
 -path "$RANDOM_PATH/proc" -prune -or \
 -path "$RANDOM_PATH/sys" -prune -or \
 -path "$RANDOM_PATH$DOCKER_ROOT_DIR" -prune -or \
 -path "$RANDOM_PATH$BACKUP_VOLUME_DIR" -prune -or \
 -ls 2>/dev/null | sed "s|$RANDOM_PATH||g" > /source/data/allfiles.list

rm -f "$RANDOM_PATH"

# Run any other script which should output data to be backed up to /source/data/.
run-parts --exit-on-error /etc/backup.d

# One should mount a file with configuration /source/backup.list to configure precisely what to backup.
if [ ! -e /source/backup.list ]; then
  touch /source/backup.list
fi

# If it looks like a backup already exists, remove old backups.
if [ -d /backup/rdiff-backup-data ]; then
  /usr/bin/rdiff-backup --force --remove-older-than "${RDIFF_BACKUP_EXPIRE:-12M}" /backup
fi

/usr/bin/rdiff-backup --preserve-numerical-ids --exclude "/source/host$DOCKER_ROOT_DIR" --exclude "/source/host$BACKUP_VOLUME_DIR" --include-globbing-filelist /source/backup.list /source /backup 2>&1 | grep -v UpdateError
