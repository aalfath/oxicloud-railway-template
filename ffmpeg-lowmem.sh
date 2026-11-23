#!/bin/sh
# Low-memory ffmpeg front for OxiCloud's video thumbnails (Railway wrapper).
# OxiCloud 0.10.1 runs: ffmpeg ... -i FILE -vf "thumbnail,scale=..." ...
# The "thumbnail" filter buffers 100 full-resolution frames and ffmpeg starts
# one decoder thread per visible CPU (32 on Railway hosts), which gets the
# whole service OOM-killed at 0.5 GB on a 1080p video. Here we cap threads
# and scale each frame down *before* the thumbnail filter picks the best one.
threads="${OXICLOUD_FFMPEG_THREADS:-2}"
first=1
for a in "$@"; do
  if [ "$first" = 1 ]; then set --; first=0; fi
  case "$a" in
    thumbnail,scale=*)
      a="${a#thumbnail,},thumbnail=n=${OXICLOUD_FFMPEG_THUMBNAIL_FRAMES:-50}" ;;
    -i)
      set -- "$@" -threads "$threads" -filter_threads 1 ;;
  esac
  set -- "$@" "$a"
done
exec /usr/bin/ffmpeg "$@"
