# Build environment for the Flikker libmpv (linux/amd64: the NDK host
# toolchain is x86_64 only). Sources and the NDK are bind-mounted at /work.
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      autoconf automake libtool pkg-config nasm make unzip xz-utils bzip2 \
      python3 python3-pip python3-setuptools ninja-build git file ca-certificates \
    && pip3 install --no-cache-dir meson==1.6.1 jinja2==3.1.4 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /work
