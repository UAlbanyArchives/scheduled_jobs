# scheduled_jobs
Scheduled or overnight automated tasks

## Building

```
docker build -t jobs .
```

## Instructions

Schedule a script

```
0 2 * * * docker run --rm jobs ./run_job.sh args
```

## About jobs

### SPE_DAO backup

This creates weekly backups and keeps one weekly snapshot and one monthly snapshot

```
0 3 * * 1 docker run --rm jobs ./SPE_DAO-backup.sh >> log/SPE_DAO-backup.log 2>&1
```
