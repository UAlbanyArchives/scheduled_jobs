FROM python:3.11.2-slim-buster
MAINTAINER Gregory Wiedeman gwiedeman@albany.edu

ENV TZ=America/New_York

RUN apt update && apt install -y rsync

COPY . /app
WORKDIR /app

RUN chmod +x /app/SPE_DAO-backup.sh

RUN pip install -r /app/requirements.txt
