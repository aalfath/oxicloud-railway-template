# Deploy and Host OxiCloud on Railway

OxiCloud is an open-source, self-hosted cloud written in Rust: a web app for your files, photos, music, calendars and contacts, with WebDAV, CalDAV and CardDAV so desktop and phone apps can sync. It is a lightweight alternative to Nextcloud that runs comfortably in a few hundred megabytes of RAM.

## About Hosting OxiCloud

Hosting OxiCloud means running its server next to a PostgreSQL database and keeping uploaded files on persistent storage. This template deploys the official `diocrafts/oxicloud` 0.10.1 image (pinned by digest) from a public GitHub repo, plus Railway PostgreSQL, wired over the private network. Files, thumbnails, the search index and the signing key live on a volume at `/app/storage`. On the first boot the template creates the admin account from generated variables, so nobody can claim your instance through the setup page, and public sign-up stays off. Database migrations run automatically on start, and a crash exits non-zero so Railway restarts the service.

## Common Use Cases

* Private Google Drive or Dropbox replacement for a person, family or small team
* Calendar and contact sync (CalDAV/CardDAV) for phones and desktop clients
* Photo and music library with thumbnails, sharing links and a trash bin

## Dependencies for OxiCloud Hosting

* PostgreSQL (Railway PostgreSQL, included)
* A Railway volume for file storage (included, mounted at `/app/storage`)

### Deployment Dependencies

* OxiCloud: https://github.com/AtalayaLabs/OxiCloud
* Template source: https://github.com/aalfath/oxicloud-railway-template
* Official image: https://hub.docker.com/r/diocrafts/oxicloud

### Implementation Details

Services in this template:

* **OxiCloud**: the web app and the WebDAV/CalDAV/CardDAV server, built from the template repo, public on port 8086, health check `/ready` (checks the database), data on a volume at `/app/storage`.
* **Postgres**: Railway PostgreSQL with its own volume; OxiCloud reaches it through `${{Postgres.DATABASE_URL}}`.

After deploy:

1. Open the OxiCloud service's public URL.
2. Sign in as `admin` with the password in the OxiCloud service's `OXICLOUD_ADMIN_PASSWORD` variable.
3. Change the admin email from `admin@example.com` in your profile, then create users for other people in the admin panel (public sign-up is off; set `OXICLOUD_DISABLE_REGISTRATION=false` to turn it on).

Sync clients: WebDAV is at `https://YOUR-DOMAIN/webdav/`, CalDAV at `https://YOUR-DOMAIN/caldav/` and CardDAV at `https://YOUR-DOMAIN/carddav/`. Create an app password in your profile for each client.

Sizing: tested with a 0.5 GB / 1 vCPU limit (Railway Free plan). The app uses about 60–120 MB of RAM and had no out-of-memory kills while uploading and thumbnailing a 24-megapixel photo and 1080p and 4K videos (video thumbnails go through a low-memory ffmpeg wrapper). Thread and connection pools are sized for a small service; raise `OXICLOUD_WORKER_THREADS` on larger plans. Optional settings (SMTP, OpenID Connect, S3 storage, Collabora/OnlyOffice) are standard OxiCloud environment variables you can add later.

Updates: the OxiCloud service builds from a GitHub repo, so Railway shows "update available" when the template moves to a new OxiCloud release. Read the repo's CHANGELOG.md before applying it.

## Why Deploy OxiCloud on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying OxiCloud on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
