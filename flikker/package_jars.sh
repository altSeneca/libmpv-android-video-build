#!/bin/bash
[[ "${_NAMED:-}" ]] || { export _NAMED=1; exec -a "claude:flikker-libmpv-jars" /bin/bash "$0" "$@"; }
# Packages the built libmpv.so files into the jar layout
# media_kit_libs_android_video expects (host side, after build.sh):
#   default-<abi>.jar = lib/<abi>/libmediakitandroidhelper.so (unchanged
#   bytes from upstream v1.1.7, checked by the MD5 the package pins)
#                     + lib/<abi>/libmpv.so (this build)
# Reproducible: fixed timestamps, no extra attributes, no directory entries,
# fixed entry order. Run from the work dir (the folder with out/ and pkg/):
#   upstream/flikker/package_jars.sh [config] [tag]   (default iptv-safe v2)
set -euo pipefail
config=${1:-iptv-safe}; tag=${2:-v2}
W=$PWD
src=$W/out/$tag/$config
jars=$W/out/$tag/jars
up=$W/pkg/upstream-v1.1.7
REL=https://github.com/media-kit/libmpv-android-video-build/releases/download/v1.1.7
md5_of() { if command -v md5 >/dev/null; then md5 -q "$1"; else md5sum "$1" | cut -d' ' -f1; fi; }
sha_of() { shasum -a 256 "$1" | cut -d' ' -f1; }
pin() { case $1 in arm64-v8a) echo 83df25b61193af8fa815e373143ac9af ;; armeabi-v7a) echo 22e21526fefc0a2b8f17adbec9f57590 ;; x86_64) echo 6fa26bf0459b11f1c0b0dbc29e5b940d ;; esac; }

mkdir -p $up $jars
rm -f $jars/default-*.jar $jars/JAR-SHA256SUMS $jars/CONTENTS-SHA256SUMS
for abi in arm64-v8a armeabi-v7a x86_64; do
  [ -f $src/$abi/libmpv.so ] || { echo "skip $abi: not built"; continue; }
  ( cd $src/$abi && shasum -a 256 -c SHA256SUMS >/dev/null )
  j=$up/default-$abi.jar
  [ -f $j ] || curl -fsSL -o $j $REL/default-$abi.jar
  [ "$(md5_of $j)" = "$(pin $abi)" ] || { echo "upstream jar MD5 mismatch: $abi" >&2; exit 1; }
  st=$(mktemp -d)
  mkdir -p $st/lib/$abi
  unzip -q -o $j lib/$abi/libmediakitandroidhelper.so -d $st
  cp $src/$abi/libmpv.so $st/lib/$abi/libmpv.so
  TZ=UTC touch -t 198001010000 $st/lib/$abi/*.so
  ( cd $st && TZ=UTC zip -X -D -q $jars/default-$abi.jar lib/$abi/libmediakitandroidhelper.so lib/$abi/libmpv.so )
  ( cd $st && shasum -a 256 lib/$abi/libmediakitandroidhelper.so lib/$abi/libmpv.so ) >> $jars/CONTENTS-SHA256SUMS
  rm -rf $st
done
( cd $jars && shasum -a 256 default-*.jar > JAR-SHA256SUMS && cat JAR-SHA256SUMS )
