#!/bin/sh

set -e

cleanup_docker=0
cleanup() {
  set +e

  if [ "$cleanup_docker" -ne 0 ]; then
    echo "Logs"
    docker logs test

    echo "Stopping Docker image"
    docker stop test
    docker rm -f test
  fi
}

trap cleanup EXIT

echo "Running Docker image"
docker run -d --name test -e LOG_TO_STDOUT=1 -v /:/source/host -v "$(pwd)/test/backup.list:/source/backup.list" -v /var/run/docker.sock:/var/run/docker.sock "${CI_REGISTRY_IMAGE}:${TAG}"
cleanup_docker=1

echo "Testing"
docker exec test /etc/cron.daily/backup
for file in /backup/backup.list /backup/data/allfiles.list /backup/host/etc /backup/rdiff-backup-data ; do
  docker exec test bash -c "[ -e '$file' ] || echo '$file is missing'"
done
