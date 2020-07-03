# tozd/rdiff-backup

<https://gitlab.com/tozd/docker/rdiff-backup>

Docker image providing backups with [rdiff-backup](http://www.nongnu.org/rdiff-backup/).
The main purpose is to backup host with all data volumes stored outside containers, with
optionally database dumps and other custom data, but it can also be used to backup
just a particular directory. Using rdiff-backup gives you direct access to the latest version
with past versions possible to be reconstructed using rdiff-backup. Past changes are stored
using reverse increments. Backup runs daily.

For remote backup instead of local host backup, consider
[tozd/rdiff-backup-remote Docker image](https://gitlab.com/tozd/docker/rdiff-backup-remote).

You have to mount `/var/run/docker.sock` from host into `/var/run/docker.sock` for this image
to work.

Mount a directory (often host's `/`) you want to backup to `/source/host` volume.
And mount a directory to where you want to store the backup to `/backup`. That directory
will be ignored during backup automatically (to not backup the backup).

If you want to configure only parts of `/source/host` volume to be backed up, you can provide
a `/source/backup.list` file which is passed as `include-globbing-filelist` to rdiff-backup.
Example:

```
+ /source/host/etc
+ /source/host/home
+ /source/host/root
+ /source/host/var/backups
+ /source/host/var/log
+ /source/host/usr/local/bin
+ /source/host/usr/local/etc
+ /source/host/usr/local/sbin
- /source/host
```

This file configures that `/etc`, `/home`, `/root` and parts of `/var` are backed up, while the
rest of the `/source/host` (and host's files) is ignored.
Notice the prefix `/source/host` you have to use for all paths.

You can provide this file by mounting it into the container.
Consult section *file selection* of [rdiff-backup man page](http://www.nongnu.org/rdiff-backup/rdiff-backup.1.html)
for more information on the format of this file.

Used environment variables:
 * `RDIFF_BACKUP_EXPIRE` – how long to keep past versions, provided as a string according to
   *time formats* section of [rdiff-backup man page](http://www.nongnu.org/rdiff-backup/rdiff-backup.1.html);
   default: `12M` for 12 months

Every time backup runs it can also collect additional data to backup and stores it under
`/source/data` in the container, so that it is backed up together with the rest (whole `/source`
directory is backed up). By default, a list of all files which exist `/source/host` is made
and stored under `/source/data/allfiles.list`, but you can also add custom scripts to this step
by adding them to `/etc/backup.d` directory in the container (probably by mounting a directory to `/etc/backup.d`
volume and then adding the scripts to that directory).
For example, you can dump databases running inside other Docker containers.

For [tozd/postgresql](https://gitlab.com/tozd/docker/postgresql) image, you can create a script `/etc/backup.d/pgsql` like:

```bash
#!/bin/bash -e
docker exec pgsql pg_dumpall -U postgres > /source/data/pgsql.sql
```

And for [tozd/mysql](https://gitlab.com/tozd/docker/mysql) image, you can create `/etc/backup.d/mysql`:

```bash
#!/bin/bash -e
PASSWORD=$(docker exec mysql grep password /etc/mysql/debian.cnf | awk '{print $3}' | head -1)
echo "$PASSWORD" | docker exec mysql mysqldump --user=debian-sys-maint --password="$PASSWORD" --all-databases > /source/data/mysql.sql
```
