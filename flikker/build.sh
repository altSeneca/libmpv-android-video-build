#!/bin/bash
# Flikker libmpv build, run inside the flikker/Dockerfile image:
#   build.sh <arm64|armv7l|x86_64> <iptv-min|iptv-safe>
# Layout: /work (bind mount): dl/ tarballs + NDK zip, src/ git checkouts
# (ffmpeg, mpv, libplacebo), out/ results. /scratch (a Docker volume, so
# case-sensitive: the NDK has headers differing only by case): NDK,
# build trees, install prefixes.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/versions.sh"
. "$HERE/ffmpeg-iptv.sh"

arch=$1; config=$2
JOBS=${JOBS:-4}
WITH_DAV1D=${WITH_DAV1D:-0}
W=/work
OUT=$W/out/${OUT_TAG:-v2}
S=/scratch
LOG=$W/logs/steps-$1-$2.log; mkdir -p $W/logs; : > $LOG
trap 'echo "FAILED at line $LINENO"; tail -40 $LOG' ERR

case $arch in
  arm64)  triple=aarch64-linux-android;   abi=arm64-v8a;   cpu=armv8-a; cpu_family=aarch64 ;;
  armv7l) triple=armv7a-linux-androideabi; abi=armeabi-v7a; cpu=armv7-a; cpu_family=arm ;;
  x86_64) triple=x86_64-linux-android;    abi=x86_64;      cpu=generic; cpu_family=x86_64 ;;
  *) echo "bad arch"; exit 1 ;;
esac
case $config in iptv-min|iptv-safe) ;; *) echo "bad config"; exit 1 ;; esac

# --- NDK -------------------------------------------------------------
NDK=$S/ndk/android-ndk-$v_ndk
if [ ! -d "$NDK" ]; then
  z=$W/dl/android-ndk-$v_ndk-linux.zip
  if [ ! -f $z ]; then  # download into the volume, not the host
    z=$S/android-ndk-$v_ndk-linux.zip
    curl -fsSL -o $z https://dl.google.com/android/repository/android-ndk-$v_ndk-linux.zip
  fi
  echo "$v_ndk_sha256  $z" | sha256sum -c -
  mkdir -p $S/ndk && unzip -q $z -d $S/ndk
  [ $z = $S/android-ndk-$v_ndk-linux.zip ] && rm -f $z
fi
TC=$NDK/toolchains/llvm/prebuilt/linux-x86_64
export PATH=$TC/bin:$PATH
export CC=$triple$v_api-clang CXX=$triple$v_api-clang++ AR=llvm-ar RANLIB=llvm-ranlib NM=llvm-nm STRIP=llvm-strip
# 16 KB pages; (v2) a GNU build ID (a hash of the content, so reproducible
# builds stay reproducible) and no exports from the static archives
# (FFmpeg, mbedTLS, libplacebo, libass stack, libc++): only mpv's own
# objects export, which carries the mpv_* client API and
# mpv_lavc_set_java_vm.
export LDFLAGS="-Wl,-O1,--icf=safe -Wl,-z,max-page-size=16384 -Wl,--build-id=sha1 -Wl,--exclude-libs,ALL"
ffarch=${triple%%-*}; [ $ffarch = armv7a ] && ffarch=arm

B=$S/build/$abi
base=$S/prefix/$abi/base-$config$([ $WITH_DAV1D = 1 ] && echo -dav1d || true)
ass=$S/prefix/$abi/ass
mkdir -p $B $base $ass $OUT

crossfile() { # $1 = prefix
  cat > $B/cross-$(basename $1).txt <<CF
[built-in options]
buildtype = 'release'
default_library = 'static'
wrap_mode = 'nodownload'
[binaries]
c = '$CC'
cpp = '$CXX'
ar = 'llvm-ar'
nm = 'llvm-nm'
strip = 'llvm-strip'
pkg-config = 'pkg-config'
[host_machine]
system = 'android'
cpu_family = '$cpu_family'
cpu = '$cpu'
endian = 'little'
CF
  echo $B/cross-$(basename $1).txt
}
untar() { # name version sha ext
  local f=$W/dl/$1-$2.$4 d=$B/$1
  echo "$3  $f" | sha256sum -c - >>$LOG 2>&1
  rm -rf $d && mkdir -p $d && tar -xf $f -C $d --strip-components=1
}
srccopy() { # git checkout (with submodules) -> fresh build copy at a pinned commit
  rm -rf $B/$1 && cp -a $W/src/$1 $B/$1
  git -C $B/$1 -c advice.detachedHead=false checkout -q -f $2
  [ "$(git -C $B/$1 rev-parse HEAD)" = "$2" ]
}
pc() { export PKG_CONFIG_LIBDIR="$*"; unset PKG_CONFIG_PATH; }

# --- base: mbedTLS, (dav1d), FFmpeg, libplacebo ------------------------
if [ ! -f $base/.done ]; then
  pc $base/lib/pkgconfig
  untar mbedtls $v_mbedtls $v_mbedtls_sha256 tar.bz2
  ( cd $B/mbedtls
    [ $arch = x86_64 ] && python3 scripts/config.py set MBEDTLS_AESNI_C || python3 scripts/config.py unset MBEDTLS_AESNI_C
    python3 scripts/config.py set MBEDTLS_PLATFORM_DEV_RANDOM '"/dev/urandom"' || true
    make CFLAGS=-fPIC -j$JOBS lib >>$LOG 2>&1
    mkdir -p $base/include $base/lib
    cp -r include/mbedtls include/psa $base/include/
    cp library/libmbedtls.a library/libmbedx509.a library/libmbedcrypto.a $base/lib/ )
  extra=()
  if [ $WITH_DAV1D = 1 ]; then
    untar dav1d $v_dav1d $v_dav1d_sha256 tar.xz
    ( cd $B/dav1d && meson setup _b --cross-file $(crossfile $base) --prefix=$base -Denable_tests=false -Denable_tools=false -Db_lto=false -Dstack_alignment=16 >>$LOG 2>&1 && ninja -C _b -j$JOBS >>$LOG 2>&1 && ninja -C _b install >>$LOG 2>&1 )
    extra=("${ff_dav1d[@]}")
  fi
  srccopy ffmpeg $v_ffmpeg_commit
  for p in $HERE/patches/ffmpeg/*.patch; do [ -f "$p" ] && git -C $B/ffmpeg apply "$p"; done
  [ $config = iptv-safe ] && extra+=("${ff_subs[@]}")
  cpuflags=; [ $arch = armv7l ] && cpuflags="-mfpu=neon -mcpu=cortex-a8"
  ( mkdir -p $B/ffmpeg/_b && cd $B/ffmpeg/_b
    ../configure --prefix=$base --target-os=android --enable-cross-compile --cross-prefix=$triple- \
      --cc=$CC --cxx=$CXX --ar=$AR --nm=$NM --ranlib=$RANLIB --strip=$STRIP --pkg-config=pkg-config \
      --arch=$ffarch --cpu=$cpu --extra-cflags="-I$base/include -fPIC $cpuflags" --extra-ldflags="-L$base/lib" \
      --enable-static --disable-shared --pkg-config-flags=--static \
      "${ff_common[@]}" "${extra[@]}" > $OUT/ffmpeg-configure-$abi-$config.txt
    make -j$JOBS >>$LOG 2>&1
    make install >>$LOG 2>&1 )
  srccopy libplacebo $v_libplacebo_commit
  ( cd $B/libplacebo && meson setup _b --cross-file $(crossfile $base) --prefix=$base \
      -Dvulkan=disabled -Dopengl=enabled -Dglslang=disabled -Dshaderc=disabled -Dlcms=disabled \
      -Ddovi=disabled -Dlibdovi=disabled -Ddemos=false -Dtests=false -Dunwind=disabled -Dxxhash=disabled >>$LOG 2>&1 \
    && ninja -C _b -j$JOBS >>$LOG 2>&1 && ninja -C _b install >>$LOG 2>&1 )
  # Link the C++ runtime statically (no libc++_shared.so in the APK).
  sed -i '/^Libs:/ s|$| -l:libc++_static.a -l:libc++abi.a|' $base/lib/pkgconfig/libplacebo.pc
  rm -rf $B/mbedtls $B/dav1d $B/ffmpeg $B/libplacebo
  touch $base/.done
fi

# --- ass stack (iptv-safe) ---------------------------------------------
if [ $config = iptv-safe ] && [ ! -f $ass/.done ]; then
  pc $ass/lib/pkgconfig
  cf=$(crossfile $ass)
  untar freetype $v_freetype $v_freetype_sha256 tar.xz
  ( cd $B/freetype && meson setup _b --cross-file $cf --prefix=$ass -Dbrotli=disabled -Dbzip2=disabled -Dharfbuzz=disabled -Dpng=disabled -Dzlib=disabled -Dtests=disabled >>$LOG 2>&1 && ninja -C _b -j$JOBS >>$LOG 2>&1 && ninja -C _b install >>$LOG 2>&1 )
  untar fribidi $v_fribidi $v_fribidi_sha256 tar.xz
  ( cd $B/fribidi && meson setup _b --cross-file $cf --prefix=$ass -Ddocs=false -Dtests=false -Dbin=false >>$LOG 2>&1 && ninja -C _b -j$JOBS >>$LOG 2>&1 && ninja -C _b install >>$LOG 2>&1 )
  untar harfbuzz $v_harfbuzz $v_harfbuzz_sha256 tar.xz
  ( cd $B/harfbuzz && meson setup _b --cross-file $cf --prefix=$ass -Dtests=disabled -Ddocs=disabled -Dutilities=disabled -Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dicu=disabled -Dfreetype=enabled -Dwasm=disabled >>$LOG 2>&1 && ninja -C _b -j$JOBS >>$LOG 2>&1 && ninja -C _b install >>$LOG 2>&1 )
  untar libass $v_libass $v_libass_sha256 tar.xz
  ( cd $B/libass && mkdir -p _b && cd _b && ../configure --host=${triple/armv7a/arm} --prefix=$ass --with-pic --disable-asm \
      --enable-static --disable-shared --disable-require-system-font-provider --disable-fontconfig --disable-libunibreak >>$LOG 2>&1 \
    && make -j$JOBS >>$LOG 2>&1 && make install >>$LOG 2>&1 )
  rm -rf $B/freetype $B/fribidi $B/harfbuzz $B/libass
  touch $ass/.done
fi

# --- mpv ----------------------------------------------------------------
dest=$S/prefix/$abi/mpv-$config$([ $WITH_DAV1D = 1 ] && echo -dav1d || true)
rm -rf $dest
if [ $config = iptv-safe ]; then pc $base/lib/pkgconfig:$ass/lib/pkgconfig; libass=enabled; else pc $base/lib/pkgconfig; libass=disabled; fi
srccopy mpv $v_mpv_commit
git -C $B/mpv apply $HERE/patches/mpv/0001-mpv_lavc_set_java_vm.patch
git -C $B/mpv apply $HERE/patches/mpv/0002-optional-libass.patch
( cd $B/mpv && meson setup _b --cross-file $(crossfile $base) --prefix=$dest --prefer-static --default-library=shared \
    -Dlibmpv=true -Dcplayer=false -Dgpl=false -Dbuild-date=false -Dcplugins=disabled -Dlibass=$libass \
    -Dlua=disabled -Djavascript=disabled -Dlibcurl=disabled -Diconv=disabled -Duchardet=disabled \
    -Drubberband=disabled -Dlcms2=disabled -Dlibarchive=disabled -Dlibbluray=disabled -Ddvdnav=disabled \
    -Dcdda=disabled -Ddvbin=disabled -Dzimg=disabled -Djpeg=disabled -Dvulkan=disabled -Dshaderc=disabled \
    -Dspirv-cross=disabled -Dsubrandr=disabled -Dlibavdevice=disabled -Dvapoursynth=disabled \
    -Dopensles=enabled -Daaudio=enabled -Daudiotrack=enabled -Degl-android=enabled -Dgl=enabled \
    -Dmanpage-build=disabled -Dhtml-build=disabled -Dpdf-build=disabled \
  | tee $OUT/mpv-meson-$abi-$config.txt | tail -60 \
  && ninja -C _b -j$JOBS && ninja -C _b install >>$LOG 2>&1 )
o=$OUT/$config$([ $WITH_DAV1D = 1 ] && echo -dav1d || true)/$abi
mkdir -p $o
cp $dest/lib/libmpv.so $o/libmpv.unstripped.so
$STRIP --strip-all -o $o/libmpv.so $dest/lib/libmpv.so
# Evidence: versions from the libraries' own headers, dynamic deps, symbols.
{ echo "mpv $(cat $B/mpv/MPV_VERSION) commit $v_mpv_commit + flikker patches"
  grep -h '#define FFMPEG_VERSION' $base/include/libavutil/ffversion.h
  grep -h 'define MBEDTLS_VERSION_STRING ' $base/include/mbedtls/build_info.h
  grep -h 'define PL_VERSION\b\|define PL_MAJOR\|define PL_API_VER' $base/include/libplacebo/config.h || true
  [ -f $base/include/dav1d/version.h ] && grep -h 'define DAV1D_API_VERSION' $base/include/dav1d/version.h || echo "dav1d: not built"
  if [ $config = iptv-safe ]; then
    grep -h 'define LIBASS_VERSION' $ass/include/ass/ass.h
    grep -h 'define FREETYPE_\(MAJOR\|MINOR\|PATCH\)' $ass/include/freetype2/freetype/freetype.h
    grep -h 'define HB_VERSION_STRING' $ass/include/harfbuzz/hb-version.h
    grep -h 'define FRIBIDI_VERSION ' $ass/include/fribidi/fribidi-config.h
  else echo "libass/FreeType/HarfBuzz/FriBidi: not built"; fi
  echo "NDK $v_ndk API $v_api"
} > $o/versions.txt
llvm-readelf -d $o/libmpv.so > $o/readelf-d.txt
llvm-readelf -n $o/libmpv.so > $o/readelf-n.txt
llvm-readelf -lW $o/libmpv.so > $o/readelf-l.txt
llvm-nm -D --defined-only $o/libmpv.so > $o/nm-D-defined.txt
llvm-nm $o/libmpv.unstripped.so > $o/nm-all.txt || true
cp $OUT/ffmpeg-configure-$abi-$config.txt $o/ 2>>$LOG 2>&1 || true
sha256sum $o/libmpv.so $o/libmpv.unstripped.so > $o/SHA256SUMS
rm -rf $B/mpv
echo "DONE $o"; ls -l $o; cat $o/versions.txt
