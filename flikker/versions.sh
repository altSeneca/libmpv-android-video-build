#!/bin/bash
# Flikker V1 pins. Every source is fetched by fetch.sh and checked against
# the SHA-256 or commit below.

v_ndk=r30
v_ndk_sha256=753611f410d002cfcd3f3dc2ef49aad532089d3180b436c060a90bf0fcb64df2
v_api=21

# FFmpeg: release/9.0 branch head on 2026-11-11 (n9.0.2 plus 57 backports).
v_ffmpeg_commit=d838f9f9aeb0e09b4d068e2af20a46a12640696f
# = n9.0.2 + 57 commits (the embedded version string shows the short hash d838f9f)
v_mpv=v0.42.0
v_mpv_commit=b0841e8c4d156b8403dc1876c4cbd9011eb583f3
v_libplacebo=v7.387.0
v_mbedtls=3.6.7
v_mbedtls_sha256=a7e8bcbec0e6f761b4af24f25677626b35f762f68eef79c08677a363212d11f6

# Only for the iptv-safe config (text subtitles through libass).
v_libass=0.17.5
v_libass_sha256=2dca25c0e0c837ddf00b52011b3f82cac1e4ddd3ad018227806b0c2288864acc
v_freetype=2.15.0
v_freetype_sha256=93cd47eb719c325107f2d3cf087d06299e944c3b48a40b55537302304dea1dd5
v_harfbuzz=15.1.0
v_harfbuzz_sha256=0fc7c565443a5f4be7da65ac5ee5bd737d9b158dc908708b7689a0a5796b0c8d
v_fribidi=1.0.18
v_fribidi_sha256=1de5e8073d035388b71d0b2d452b1da1f8caeea8a7702997b401fe1b6250727f

# Optional AV1 software decoding (WITH_DAV1D=1).
v_dav1d=1.5.4
v_dav1d_sha256=686616b7c69eb88d44459391ab25cac13b6647a3b288835c5784e71c1514a5c5
v_libplacebo_commit=275f7dea27924cdd34ab2e6c20e448b6bc4fab65
