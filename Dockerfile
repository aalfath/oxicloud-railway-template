# OxiCloud for Railway: official image, pinned by version and digest.
# Bump the tag and the digest together; see CHANGELOG.md.
FROM diocrafts/oxicloud:0.10.1@sha256:e51843bdb8967ca825bc9b14dd3a35519591b52d4f9beadedd86646129077cf6

# Railway wrapper: Railway defaults, first-boot admin, non-zero exit on crash.
COPY --chmod=755 start.sh /usr/local/bin/railway-start.sh
# Low-memory ffmpeg front for video thumbnails (ffprobe is looked up next to it).
COPY --chmod=755 ffmpeg-lowmem.sh /opt/railway/bin/ffmpeg
RUN ln -s /usr/bin/ffprobe /opt/railway/bin/ffprobe

# Data lives in /app/storage: attach a Railway volume there (no VOLUME line,
# Railway rejects it at build time).
WORKDIR /app
EXPOSE 8086
ENTRYPOINT ["/usr/local/bin/railway-start.sh"]
