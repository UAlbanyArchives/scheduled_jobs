# scheduled_jobs
Scheduled or overnight automated tasks

## Building

```
docker build -t jobs .
```

## Instructions

Schedule a script. `--rm` removes the Docker container after it runs.

```
0 2 * * * docker-compose run --rm job ./run_job.sh args
```

## About jobs

### image_a_day

This downloads the Bing background image each day and uses it as the Find-It background. Both for fun and as proof that things are working as expected since its very visible.

```
0 5 * * * docker-compose run --rm jobs python image_a_day.py >> /logs/indexing-logs/image_a_day.log 2>&1
```

### SPE_DAO backup

This creates weekly backups and keeps one weekly snapshot and one monthly snapshot

```
0 3 * * 1 docker-compose run --rm job ./SPE_DAO-backup.sh >> /logs/backup_logs/SPE_DAO-backup.log 2>&1
```
