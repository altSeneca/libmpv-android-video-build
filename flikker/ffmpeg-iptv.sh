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
  # (v2) mpeg4 (MPEG-4 ASP VOD, measured in AVI) and vp9 (Jellyfin's
  # direct-play profile) are back, as in the shipped library.
  --enable-decoder=h264,hevc,mpeg2video,mpeg4,vp9
  --enable-decoder=h264_mediacodec,hevc_mediacodec,mpeg2_mediacodec,av1_mediacodec
  --enable-decoder=mpeg4_mediacodec,vp9_mediacodec
  # Audio: the IPTV set. mp2 is common on DVB restreams; aac_latm on some
  # DVB-T/T2 services. (v2) dca (DTS, 3 percent of surveyed VOD), flac and
  # vorbis (Jellyfin profile, Ogg/MKV files) and every pcm_* decoder are back,
  # as in the shipped library; pcm_bluray carries LPCM in MPEG-TS (stream
  # type 0x80 with the HDMV registration) for the Rust audio stage.
  --enable-decoder=aac,aac_latm,ac3,eac3,mp3,mp3float,mp2,mp2float,opus
  --enable-decoder=dca,flac,vorbis
  --enable-decoder='pcm_*'
  # (v2) Platform audio decoders through MediaCodec, IN ADDITION to the
  # software decoders above (fallback for devices without one). FFmpeg
  # lists them after the native decoders, so mpv keeps choosing software
  # unless the app sets ad=aac_mediacodec,mp3_mediacodec (see README-v2).
  # ac3/eac3_mediacodec come from flikker/patches/ffmpeg/0001.
  --enable-decoder=aac_mediacodec,mp3_mediacodec,ac3_mediacodec,eac3_mediacodec

  # (v2) avi and flv: the app's address check accepts .avi and .flv VOD,
  # and the survey measured MPEG-4 ASP in AVI. flac, ogg, wav, dts: raw
  # audio files and Ogg (Vorbis, Opus, FLAC). webm plays through matroska.
  --enable-demuxer=hls,mpegts,mov,matroska,aac,ac3,eac3,mp3,loas
  --enable-demuxer=avi,flv,flac,ogg,wav,dts
  --enable-parser=h264,hevc,av1,mpegvideo,aac,aac_latm,ac3,mpegaudio,opus
  --enable-parser=mpeg4video,vp9,flac,vorbis,dca

  # (v2) spdif muxer: mpv's --audio-spdif (AC-3, E-AC-3, DTS passthrough
  # over HDMI). Not used unless the app sets audio-spdif.
  --enable-muxer=spdif

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
  # (v2) dvdsub (shipped today) and pgssub (Blu-ray PGS, new, for the
  # bitmap subtitle work): decoded only when a bitmap track is selected.
  --enable-decoder=dvdsub,pgssub
  --enable-demuxer=webvtt,srt,ass
  --enable-parser=dvbsub,dvdsub
)

# WITH_DAV1D=1: AV1 in software where the device has no AV1 decoder.
ff_dav1d=(--enable-libdav1d --enable-decoder=libdav1d)
