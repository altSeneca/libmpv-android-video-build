# Flikker libmpv v2 (branch flikker-v2)

The libmpv rebuild bundle of Plan 27 (rank 6 of the short list). Same flow
and pins as flikker-v1 (FFmpeg release/9.0 @ d838f9f9ae, mpv 0.42.0,
libplacebo 7.387.0, mbedTLS 3.6.7, libass 0.17.5, FreeType 2.15.0, HarfBuzz
15.1.0, FriBidi 1.0.18, NDK r30, API 21). Only the `iptv-safe` configuration
is meant for the app.

## What changed from v1

1. FFmpeg components (`ffmpeg-iptv.sh`), so nothing the app or the measured
   provider uses is lost against the shipped v1.1.7 library:
   - `pcm_bluray`, `pcm_dvd` and every other `pcm_*` decoder (LPCM in
     MPEG-TS for the Rust audio stage; WAV, MOV and MKV PCM).
   - `dca` (DTS), `flac`, `vorbis`; `mpeg4` (+ `mpeg4_mediacodec`), `vp9`
     (+ `vp9_mediacodec`); `dvdsub`, `pgssub`.
   - Demuxers `avi`, `flv`, `flac`, `ogg`, `wav`, `dts`; parsers
     `mpeg4video`, `vp9`, `flac`, `vorbis`, `dca`, `dvdsub`.
   - `aac_mediacodec`, `mp3_mediacodec` and (patch below) `ac3_mediacodec`,
     `eac3_mediacodec`, in addition to the software decoders.
   - `spdif` muxer (mpv `--audio-spdif`; off unless the app sets it).
2. `patches/ffmpeg/0001-mediacodec-audio-codec-name-ac3-eac3.patch`:
   - AVOptions `aac_codec_name`, `mp3_codec_name`, `ac3_codec_name`,
     `eac3_codec_name` on the MediaCodec audio decoders. Stock FFmpeg
     always calls `MediaCodec.createDecoderByType(mime)`, which takes the
     first decoder Android ranks for the type: on the Pixel 9 Pro XL
     (Android 17) that is the in-process `c2.android.inproc.aac.decoder`
     (from `dumpsys media.player`; not yet observed in a decode). With the option set, the wrapper calls
     `MediaCodec.createByCodecName(name)`; a name the device lacks falls back to the
     default for the type (logged at info level).
   - `ac3_mediacodec` (`audio/ac3`) and `eac3_mediacodec` (`audio/eac3`),
     for devices with a vendor Dolby decoder.
   - The wrappers stay in FFmpeg's "external" section of `allcodecs.c`,
     after the native decoders, so default selection is unchanged.
3. Link flags (`build.sh`): `-Wl,--build-id=sha1` and
   `-Wl,--exclude-libs,ALL` next to the 16 KB page size.
4. Output under `out/v2/<config>/<abi>/` with `readelf-n.txt` (build ID)
   and `readelf-l.txt` (LOAD alignment) added to the evidence files.
5. `package_jars.sh`: the jar layout media_kit_libs_android_video expects.

## How mpv picks the decoders (mpv 0.42.0 source)

- mpv's audio decoder list is every libavcodec decoder in
  `av_codec_iterate()` order (`common/av_common.c` `add_codecs`, no
  filtering of wrappers). FFmpeg lists `aac` before `aac_mediacodec`, so by
  default mpv opens the software decoder: this build changes nothing until
  the app asks.
- `ad=aac_mediacodec,mp3_mediacodec` puts those first for their codec and
  keeps every other decoder after them (`common/codecs.c`
  `mp_select_decoders`; only a `-` entry would drop the fallbacks).
  `filters/f_decoder_wrapper.c` tries the list in order, so a device
  without the platform decoder, or one that refuses the format at
  `configure()`, falls back to FFmpeg's software decoder. A failure after
  the decoder started is not retried with another decoder.
- `ad-lavc-o=aac_codec_name=c2.android.aac.decoder,mp3_codec_name=c2.android.mp3.decoder`
  names the out-of-process Codec2 decoders. mpv applies `ad-lavc-o` to
  every audio decoder; decoders without these options log
  `AVOption 'aac_codec_name' not found.` and open normally.
- MP2, AAC LATM, Opus, AC-3, E-AC-3, DTS and LPCM are not affected unless
  named in `ad`.

## Build

```
docker build --platform linux/amd64 -t flikker-libmpv-build:v2 upstream/flikker
docker volume create flikker-libmpv-v2-scratch
docker run --rm --platform linux/amd64 --cpus 4 -v $PWD:/work \
  -v flikker-libmpv-v2-scratch:/scratch flikker-libmpv-build:v2 \
  bash /work/upstream/flikker/build.sh arm64 iptv-safe     # armv7l, x86_64
upstream/flikker/package_jars.sh iptv-safe v2              # host, after the builds
```
