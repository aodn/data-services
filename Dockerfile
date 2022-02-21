FROM ubuntu:20.04

ARG BUILDER_UID=9999
ARG DEBIAN_FRONTEND=noninteractive

ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8
ENV PATH /home/builder/.local/bin:$PATH
ENV DEBIAN_FRONTEND noninteractive
ENV DOCKER_TESTING true

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    gawk \
    git \
    libblas-dev \
    libfreetype6-dev \
    liblapack-dev \
    libnetcdf-dev \
    libpng-dev \
    libudunits2-dev \
    nco \
    netcdf-bin \
    pkg-config \
    postfix \
    python3-dev \
    python3-pip \
    shunit2 \
    unzip \
    wget \
    zip \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 10

RUN pip install \
    Cython==0.29 \
    numpy==1.22.2 \
    tabulate==0.8.9

RUN useradd --create-home --no-log-init --shell /bin/bash --uid $BUILDER_UID builder
USER builder
WORKDIR /home/builder
