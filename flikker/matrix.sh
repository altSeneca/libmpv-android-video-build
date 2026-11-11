#!/bin/bash
# Runs every ABI x config in sequence inside the build image.
set -e
for arch in arm64 armv7l x86_64; do
  for config in iptv-min iptv-safe; do
    bash "$(dirname "$0")/build.sh" $arch $config
  done
  rm -rf /scratch/prefix/*/base-* /scratch/prefix/*/ass /scratch/build/*
done
