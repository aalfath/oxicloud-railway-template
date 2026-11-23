# Changelog

## 0.10.1-railway.1 (2026-11-23)

Breaking changes: none (first release).

- OxiCloud 0.10.1, official image `diocrafts/oxicloud:0.10.1@sha256:e51843bdb8967ca825bc9b14dd3a35519591b52d4f9beadedd86646129077cf6`.
- Railway wrapper: binds `0.0.0.0:$PORT`, first-boot admin from generated variables, public sign-up off, pools sized for 0.5 GB, non-zero exit on crash.
- Work around the 0.10.1 video-thumbnail bug (missing `<storage>/.thumbnails` temp folder).
- Low-memory ffmpeg front for video thumbnails so they fit a 0.5 GB service.
- Deploy on Railway button for the published template `oxicloud-1`.
