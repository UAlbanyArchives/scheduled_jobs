# scheduled_jobs
Scheduled or overnight automated tasks

## Building

```
docker build -t jobs .
```

## Instructions

Schedule a script. `--rm` removes the Docker container after it runs.

```
0 2 * * * docker-compose run --rm job ./scripts/run_job.sh args
```

## About jobs

### image_a_day

This downloads the Bing background image each day and uses it as the Find-It background. Both for fun and as proof that things are working as expected since its very visible.

```
0 2 * * * docker-compose run --rm jobs python ./scripts/image_a_day.py >> /logs/indexing-logs/image_a_day.log 2>&1
```
### ArcLight index

This indexes the past day's collection updates into ArcLight. For now, we can continue doing this nightly.

Requires `description_harvester` which gets installed during the build.

This needs [description_harvester config set up](https://github.com/UAlbanyArchives/description_harvester#installation) which also needs [ArchivesSnake configured](https://github.com/archivesspace-labs/ArchivesSnake?tab=readme-ov-file#configuration) in the hosts home folder.

```
5 0 * * * docker-compose run --rm jobs harvest --today >> /logs/indexing-logs/harvest.log 2>&1
```

### ArchivesSpace overnight export

Nightly, ArchivesSpace exports all updated EAD and commits them to the [collections repo](https://github.com/UAlbanyArchives/collections). It also exports PDFs for all collections that are linked to from ArcLight.

The EAD export should be incorporated into the harvest command in the future.

For this to run, the host user needs to have permissions for `/media/Library/SPE_Automated/collections` and [UAlbanyRobot]
(https://github.com/UAlbanyRobot) git credentials need to be set.

```
0 1 * * * docker-compose run --rm jobs python ./scripts/exportEAD.py >> /logs/indexing-logs/export.log 2>&1
```

### New Online Content

This enables the SPE home page to present recently digitized items. It requests data from Solr and writes it to a new_online_content.json thats served publically. The website uses some .js to then populate this data in the page.

```
0 3 * * * docker-compose run --rm jobs python ./scripts/new_online_content.py >> /logs/new_online_content/new_online_content.log 2>&1
```

### Clean up commands

These clean up working directories so stuff doesn't pile up over time and create a mess.

```
0 1 * * * docker-compose run --rm job ./scripts/cleanup.sh >> /logs/cleanup.log 2>&1
```

### Disk space tracking

This tracks disk space usage over time.

```
0 1 * * * docker-compose run --rm job ./scripts/track_disk_usage.sh >> /logs/DiskSpace/track_disk_usage.log 2>&1
```

### SPE_DAO backup

This creates weekly backups and keeps one weekly snapshot and one monthly snapshot

```
0 3 * * 1 docker-compose run --rm job ./scripts/SPE_DAO-backup.sh >> /logs/backup_logs/SPE_DAO-backup.log 2>&1
```
