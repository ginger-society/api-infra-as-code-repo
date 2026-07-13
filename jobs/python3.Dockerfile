FROM python:3.11-slim-bullseye

RUN apt update
RUN apt install postgresql-client libssl-dev libpq-dev pkg-config curl -y
RUN apt install -y curl nano make gcc wget build-essential procps
