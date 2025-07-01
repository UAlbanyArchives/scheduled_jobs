#!/bin/bash
set -euo pipefail

# Log start time
echo "Cleanup started at $(date)"

### === 1. Clean /patron directory ===

# Move files and folders older than 10 days to /expired
echo "Moving /patron files and directories older than 10 days to /expired"
find /media/Library/SPEwww/patron/ -mindepth 1 -mtime +10 ! -path "/media/Library/SPEwww/patron/expired/*" \
  -exec mv {} /media/Library/SPEwww/patron/expired/ \;

# Remove files and folders in /expired older than 20 days
echo "Removing /patron/expired files and directories older than 20 days"
find /media/Library/SPEwww/patron/expired/ -mindepth 1 -mtime +20 -exec rm -rf {} \;

### === 2. Clean /SPE_Uploads directory ===

# Move non-expired files older than 7 days to /expired
echo "Moving /SPE_Uploads files older than 7 days to /expired"
find "/media/Library/SPE_Uploads" -mindepth 1 -maxdepth 1 -mtime +7 ! -name expired -exec mv {} "/media/Library/SPE_Uploads/expired/" \;

# Remove files in /expired older than 14 days
echo "Removing /SPE_Uploads/expired files older than 14 days"
find /media/Library/SPE_Uploads/expired/ -type f -mtime +14 -exec rm {} \;


### === 3. Clean /Bookeye Scans directory ===

# Move non-expired files older than 7 days to /expired
echo "Moving /Bookeye Scans files older than 7 days to /expired"
find "/media/Library/Bookeye Scans" -mindepth 1 -maxdepth 1 -mtime +7 ! -name expired -exec mv {} "/media/Library/Bookeye Scans/expired/" \;

# Remove files in /expired older than 14 days
echo "Removing /Bookeye Scans/expired files older than 14 days"
find "/media/Library/Bookeye Scans/expired/" -type f -mtime +14 -exec rm {} \;

echo "Cleanup finished at $(date)"
