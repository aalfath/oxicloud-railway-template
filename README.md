[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/oxicloud-1?utm_medium=integration&utm_source=button&utm_campaign=oxicloud)

# OxiCloud on Railway

One-click [Railway](https://railway.com) template for [OxiCloud](https://github.com/AtalayaLabs/OxiCloud), the self-hosted cloud written in Rust: files, photos, music, calendars and contacts, with WebDAV, CalDAV and CardDAV.

**Version:** OxiCloud 0.10.1, official image `diocrafts/oxicloud:0.10.1@sha256:e51843bdb8967ca825bc9b14dd3a35519591b52d4f9beadedd86646129077cf6`.

## What it deploys

| Service | Source | What it does |
|---|---|---|
| **OxiCloud** | this repo (`Dockerfile` + `start.sh`) | Web app and WebDAV/CalDAV/CardDAV server on port 8086, public domain, health check `/ready`, volume at `/app/storage` |
| **Postgres** | Railway PostgreSQL | Metadata, users, calendars and contacts, on its own volume |

The wrapper (`start.sh`) only:

- sets Railway defaults: listens on `0.0.0.0:$PORT`, public URL from `RAILWAY_PUBLIC_DOMAIN`, public sign-up off, small thread and database pools that fit a 0.5 GB service;
- waits for PostgreSQL, then runs the upstream entrypoint (fixes volume ownership, drops to the `oxicloud` user, runs migrations);
- creates the admin account on the very first boot from the variables below, so nobody can claim a fresh instance through the setup page;
- works around an OxiCloud 0.10.1 bug where video thumbnails fail on new installs (missing `.thumbnails` temp folder);
- exits non-zero if OxiCloud stops unexpectedly, so Railway's restart policy brings it back.

## Variables (OxiCloud service)

| Variable | Default | Notes |
|---|---|---|
| `OXICLOUD_ADMIN_PASSWORD` | `${{secret(24)}}` | First admin's password. Used only on the first boot; change it in the app afterwards. |
| `OXICLOUD_ADMIN_USERNAME` | `admin` | First admin's username (lowercase letters, digits, `-_.`). |
| `OXICLOUD_ADMIN_EMAIL` | `admin@example.com` | First admin's email; change it in your profile later. |
| `OXICLOUD_DB_CONNECTION_STRING` | `${{Postgres.DATABASE_URL}}` | Database URL over the private network. |
| `OXICLOUD_BASE_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL used in share links. Change it if you add a custom domain. |
| `PORT` | `8086` | Port the app listens on. |

No prompts at deploy time. Any other [OxiCloud setting](https://github.com/AtalayaLabs/OxiCloud/blob/v0.10.1/docs/config/env.md) (SMTP, OpenID Connect, S3, Collabora/OnlyOffice) can be added as a variable later.

## After deploy

1. Open the OxiCloud service's public URL.
2. Sign in as `admin` with the value of `OXICLOUD_ADMIN_PASSWORD` (OxiCloud service → Variables).
3. Change the admin email in your profile and add users in the admin panel.
4. For sync clients, create an app password in **Profile → App Passwords**. WebDAV: `https://YOUR-DOMAIN/webdav/`, CalDAV: `https://YOUR-DOMAIN/caldav/`, CardDAV: `https://YOUR-DOMAIN/carddav/`.

## Resources

Tested with a 0.5 GB / 1 vCPU limit (Railway Free plan): idle about 60–100 MB, peak under 150 MB while thumbnailing a 24-megapixel photo and a 1080p video. Raise `OXICLOUD_WORKER_THREADS` (default 2 here) on bigger plans.

## Updates

The OxiCloud service builds from this repo. When we move the template to a new OxiCloud release (a new pinned tag and digest in the `Dockerfile`), Railway shows deployers an "update available" notice; you choose when to apply it. Read [CHANGELOG.md](CHANGELOG.md) first: breaking changes are listed at the top of each entry. Database migrations run automatically on start. Your files and database stay on their volumes.

## Licence

OxiCloud is MIT-licensed by AtalayaLabs. This wrapper is provided as-is under the same licence.
