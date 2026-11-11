#!/bin/bash
# Fetches every pinned source into <workdir>/dl and <workdir>/src (no
# source code is executed here; checksums are verified by build.sh).
#   fetch.sh <workdir>
# Then: docker build --platform linux/amd64 -t flikker-libmpv-build:v1 flikker
#       docker volume create flikker-libmpv-v1-scratch
#       docker run --rm --platform linux/amd64 --cpus 4 -v <workdir>:/work \
#         -v flikker-libmpv-v1-scratch:/scratch flikker-libmpv-build:v1 \
#         bash /work/upstream/flikker/build.sh arm64 iptv-safe
# (<workdir>/upstream is this repository.)
set -euo pipefail
. "$(dirname "$0")/versions.sh"
W=$1; mkdir -p $W/dl $W/src; cd $W/dl
get() { [ -f "$(basename $1)" ] || curl -fsSLO "$1"; }
get https://dl.google.com/android/repository/android-ndk-$v_ndk-linux.zip
get https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-$v_mbedtls/mbedtls-$v_mbedtls.tar.bz2
get https://github.com/libass/libass/releases/download/$v_libass/libass-$v_libass.tar.xz
get https://download.savannah.gnu.org/releases/freetype/freetype-$v_freetype.tar.xz
get https://github.com/harfbuzz/harfbuzz/releases/download/$v_harfbuzz/harfbuzz-$v_harfbuzz.tar.xz
get https://github.com/fribidi/fribidi/releases/download/v$v_fribidi/fribidi-$v_fribidi.tar.xz
get https://downloads.videolan.org/pub/videolan/dav1d/$v_dav1d/dav1d-$v_dav1d.tar.xz
cd $W/src
[ -d ffmpeg ] || { git init -q ffmpeg && git -C ffmpeg fetch -q --depth 1 https://github.com/FFmpeg/FFmpeg.git $v_ffmpeg_commit && git -C ffmpeg checkout -q FETCH_HEAD; }
[ -d mpv ] || git clone -q --depth 1 -b $v_mpv https://github.com/mpv-player/mpv.git mpv
[ -d libplacebo ] || git clone -q --depth 1 -b $v_libplacebo --recurse-submodules --shallow-submodules https://github.com/haasn/libplacebo.git libplacebo
echo "fetched; build.sh checks every SHA-256 and commit"
