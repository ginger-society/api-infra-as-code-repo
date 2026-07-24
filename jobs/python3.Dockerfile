FROM python:3.11-slim-bullseye

RUN apt update
RUN apt install -y \
    postgresql-client \
    libssl-dev \
    libpq-dev \
    pkg-config \
    curl \
    default-libmysqlclient-dev \
    default-mysql-client
RUN apt install -y curl nano make gcc wget build-essential procps

# Copy setup script
COPY mount-pypi-credentials.sh /usr/local/bin/mount-pypi-credentials.sh
RUN chmod +x /usr/local/bin/mount-pypi-credentials.sh