FROM python:3.11.2-slim-buster
MAINTAINER Gregory Wiedeman gwiedeman@albany.edu

ENV TZ=America/New_York

RUN apt update && apt install -y rsync

COPY . /app
WORKDIR /app

RUN chmod +x /app/scripts/cleanup.sh
RUN chmod +x /app/scripts/track_disk_usage.sh
RUN chmod +x /app/scripts/SPE_DAO-backup.sh

RUN pip install -r /app/requirements.txt
