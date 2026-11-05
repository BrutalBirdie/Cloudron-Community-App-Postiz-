# Postiz for Cloudron

[Postiz](https://postiz.com) packaged for Cloudron as a community app. Schedule posts to X, LinkedIn, Bluesky, Mastodon, Instagram and many more from one calendar.

* Sign in with Cloudron
* Email (account activation, notifications) is sent through the Cloudron mail server
* Posts are scheduled by a Temporal server bundled in the app, its state is stored in `/app/data/temporal` and included in backups
* Uploaded media is stored in `/app/data/uploads`

## Install

In Cloudron, open 'Add custom app' and enter `https://raw.githubusercontent.com/BrutalBirdie/Cloudron-Postiz-App/main/CloudronVersions.json`.

## First login

The first account can be created with email and password on the login page. It gets an activation email. After that, password sign-up is closed and only Cloudron users can sign up through "Sign in with Cloudron". To allow anyone to sign up, set `DISABLE_REGISTRATION=false` in `/app/data/env`.

## Configuration

Settings live in `/app/data/env`. Edit it with the File manager and restart the app. All options are listed in the upstream [.env.example](https://github.com/gitroomhq/postiz-app/blob/main/.env.example) and the [configuration reference](https://docs.postiz.com/configuration/reference).

Variables set by the package (URLs, database, Redis, mail, Cloudron login, upload paths) are written after `/app/data/env` and cannot be changed there.

### Social media providers

Every provider needs its own developer app. Create it at the provider, set the redirect URL shown in the [provider docs](https://docs.postiz.com/providers/overview), and put the keys into `/app/data/env`, for example:

```
LINKEDIN_CLIENT_ID="..."
LINKEDIN_CLIENT_SECRET="..."
```

Some providers (Meta, TikTok) review apps before they can post for other accounts.

### External Temporal

To use Temporal Cloud or your own Temporal server instead of the bundled one, set in `/app/data/env`:

```
TEMPORAL_ADDRESS="<namespace>.<account>.tmprl.cloud:7233"
TEMPORAL_NAMESPACE="<namespace>.<account>"
TEMPORAL_TLS="true"
TEMPORAL_API_KEY="..."
```

The bundled server then stays off.

## Limitations

* The bundled Temporal is the single-process development server with SQLite storage. It is enough for one Postiz instance, but it is not highly available.
* Cloudron backs up the Temporal database while the app runs. If a restored copy is incomplete, posts whose time has passed are queued again by Postiz within an hour (they go out late, not lost). The Temporal web UI is not exposed.
* The app needs about 1.5 GB of memory when idle. The default limit is 3 GB.
