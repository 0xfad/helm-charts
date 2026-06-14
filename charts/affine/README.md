# AFFiNE Helm Chart

Deploys a self-hosted [AFFiNE](https://affine.pro) instance on Kubernetes, modeled
after the official `docker-compose.yml`. Bundles PostgreSQL (`pgvector`) and Redis
by default, with the option to use external services instead.

## TL;DR

```bash
helm install affine ./charts/affine \
  --set affine.serverExternalUrl=https://affine.example.com \
  --set postgresql.auth.password=<strong-password>
```

Then open the URL (or `kubectl port-forward`) and complete the onboarding to create
the first admin account.

## What gets deployed

| Component   | Image                                   | Notes                                  |
|-------------|-----------------------------------------|----------------------------------------|
| AFFiNE      | `ghcr.io/toeverything/affine:stable`    | Server, port 3010                      |
| Migration   | same image                              | Helm hook Job (post-install, post-upgrade) |
| PostgreSQL  | `pgvector/pgvector:pg16`                | Bundled, optional (`postgresql.enabled`) |
| Redis       | `redis:7-alpine`                        | Bundled, optional (`redis.enabled`)    |

The migration runs as a Helm hook Job after all resources are deployed, exactly
once per install/upgrade regardless of `replicaCount`. Each AFFiNE pod waits
for PostgreSQL and Redis to be reachable via a `wait-for-deps` init container;
on first install pods may briefly crash-loop until the migration Job completes.

## Persistence

Two PVCs are created for the AFFiNE container:

- `storage` → `/root/.affine/storage` (uploaded blobs/attachments)
- `config`  → `/root/.affine/config`

PostgreSQL data persists via a `volumeClaimTemplate`.

## Using external PostgreSQL / Redis

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: my-postgres
  username: affine
  password: secret      # or use existingSecret
  database: affine

redis:
  enabled: false
externalRedis:
  host: my-redis
  port: 6379
```

## Key values

See [values.yaml](values.yaml) for the full list. Most relevant:

- `affine.serverExternalUrl` — public URL (required for invites/OAuth/email); also sets `AFFINE_SERVER_HTTPS` automatically
- `affine.privateKey.existingSecret` — bring your own secret for `AFFINE_PRIVATE_KEY`; if unset the chart auto-generates and persists the key across upgrades
- `affine.indexerEnabled` — enable the full-text/AI indexer (needs pgvector)
- `affine.extraEnv` / `affine.extraEnvFrom` — additional environment variables
- `postgresql.auth.password` / `postgresql.auth.existingSecret`
- `ingress.*` / `httpRoute.*` — exposure
- `persistence.storage.*` / `persistence.config.*`
- `migration.enabled` — set to `false` to skip the post-install/post-upgrade migration Job

> **Note:** the database password is injected into `DATABASE_URL` via Kubernetes
> `$(VAR)` expansion, so it is never rendered in plaintext into the manifests when
> an `existingSecret` is used. Passwords with URL-reserved characters are not
> URL-encoded — prefer alphanumeric passwords or an external object/DB setup.
