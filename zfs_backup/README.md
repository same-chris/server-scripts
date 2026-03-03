## ZFS backup: `poolNVME1` → `poolHDD2`

This folder contains the source for the host backup script `zfs-backup-poolNVME1.sh`.

### Where it lives on the host

- **Script path**: `/usr/local/sbin/zfs-backup-poolNVME1.sh`
- **Cron job**: `/etc/cron.d/zfs-backup`

### What it does

- **Source dataset**: `poolNVME1`
- **Destination dataset**: `poolHDD2/BACKUP/backup_poolNVME1`
- **Snapshots**: recursive snapshots on the source with prefix `backup_` (e.g. `backup_20260303_1530`)
- **Replication**:
  - **First run**: full `zfs send -R` of the snapshot to the destination
  - **Subsequent runs**: incremental `zfs send -R -i <last_common_snap> ...` when a common `backup_` snapshot exists on both sides
  - Receives with `zfs receive -u` (do not mount on receive)
- **Retention**: prunes `backup_*` snapshots older than **32 days** on **both** source and destination
- **Logging**: appends to `/var/log/zfs-backup-poolNVME1.log`

### Safety checks / guardrails

- **No overlap**: uses a lock file at `/var/lock/zfs-backup-poolNVME1.lock` (exits cleanly if already running)
- **Skips during maintenance**: exits without doing anything if a **scrub** or **resilver** is in progress
- **Pool health**: aborts if either source or destination pool is not `ONLINE`
- **Destination sanity**:
  - requires the destination parent dataset `poolHDD2/BACKUP` to exist
  - aborts if `poolHDD2/BACKUP` has less than **500 GiB** available
- **Bandwidth cap**: throttles the send stream via `pv -L 50m` (configurable in the script)

### Dependencies

The script expects these commands to exist on the host:

- `flock`
- `pv` (on Debian/Ubuntu: `apt install pv`)
- `comm`
- ZFS tools: `zfs`, `zpool`

### Install/update the script on the host

From the repo root:

```bash
sudo install -m 0755 zfs_backup/zfs-backup-poolNVME1.sh /usr/local/sbin/zfs-backup-poolNVME1.sh
```

Run once manually (optional):

```bash
sudo /usr/local/sbin/zfs-backup-poolNVME1.sh
```

Then check the log:

```bash
sudo tail -n 200 /var/log/zfs-backup-poolNVME1.log
```

### Scheduling

This backup is intended to be run via cron. The cron entry is managed at:

- `/etc/cron.d/zfs-backup`

