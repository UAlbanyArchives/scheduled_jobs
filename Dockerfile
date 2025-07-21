FROM python:3.11-slim-bookworm
MAINTAINER Gregory Wiedeman gwiedeman@albany.edu

ENV TZ=America/New_York

RUN apt update && apt install -y rsync git curl

COPY . /app
WORKDIR /app

RUN chmod +x /app/scripts/cleanup.sh
RUN chmod +x /app/scripts/track_disk_usage.sh
RUN chmod +x /app/scripts/SPE_DAO-backup.sh

RUN pip install --upgrade pip
RUN pip install -r /app/requirements.txt

RUN git clone https://github.com/UAlbanyArchives/description_harvester_plugins.git
