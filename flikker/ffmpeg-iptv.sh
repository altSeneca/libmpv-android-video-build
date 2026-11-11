#!/bin/bash
# FFmpeg component allow-lists for the Flikker IPTV builds. Everything not
# named here is compiled out (--disable-everything). configure adds the
# parsers and bitstream filters each enabled decoder selects.

ff_common=(
  --disable-everything
  --disable-autodetect
  --disable-programs --disable-doc --disable-avdevice
  --disable-debug --disable-stripping
  --enable-small --enable-optimizations --enable-runtime-cpudetect
  --enable-zlib --enable-network --enable-mbedtls --enable-jni --enable-mediacodec
  --enable-version3 --disable-gpl --disable-nonfree

  # Video. Software decoders stay as the fallback when MediaCodec refuses
  # a stream (and for the second multiview tile); *_mediacodec are the
  # hardware paths mpv's hwdec=mediacodec(-copy) uses.
  --enable-decoder=h264,hevc,mpeg2video
  --enable-decoder=h264_mediacodec,hevc_mediacodec,mpeg2_mediacodec,av1_mediacodec
  # Audio: the IPTV set. mp2 is common on DVB restreams; aac_latm on some
  # DVB-T/T2 services.
  --enable-decoder=aac,aac_latm,ac3,eac3,mp3,mp3float,mp2,mp2float,opus

  --enable-demuxer=hls,mpegts,mov,matroska,aac,ac3,eac3,mp3,loas
  --enable-parser=h264,hevc,av1,mpegvideo,aac,aac_latm,ac3,mpegaudio,opus

  # http(s) over mbedTLS, AES-128 HLS segments (crypto). No file, data,
  # udp, rtp, rtmp, rtsp, srt, ftp: a playlist cannot reach local files.
  --enable-protocol=http,https,tcp,tls,crypto

  # lavfi plumbing mpv needs (buffer/abuffer src+sink are always built), plus Flikker's dialogue boost (equalizer).
  --enable-filter=aformat,format,anull,null,aresample,equalizer
)

# iptv-safe only: text subtitle decoders/demuxers feeding libass (SRT,
# WebVTT in HLS, ASS/SSA and mov_text in MKV/MP4) and DVB bitmap subs.
ff_subs=(
  --enable-decoder=subrip,srt,webvtt,ass,ssa,movtext,text,dvbsub
  --enable-demuxer=webvtt,srt,ass
  --enable-parser=dvbsub
)

# WITH_DAV1D=1: AV1 in software where the device has no AV1 decoder.
ff_dav1d=(--enable-libdav1d --enable-decoder=libdav1d)
