# Helm Charts

A collection of Helm charts for self-hosted applications.

## Available charts

| Chart | Description | App |
|-------|-------------|-----|
| [affine](charts/affine) | Self-hosted [AFFiNE](https://affine.pro) workspace with bundled PostgreSQL (pgvector) and Redis | `ghcr.io/toeverything/affine` |

## Usage

```bash
helm repo add 0xfad https://<owner>.github.io/helm-charts
helm repo update
helm install affine 0xfad/affine \
  --set affine.serverExternalUrl=https://affine.example.com \
  --set postgresql.auth.password=<strong-password>
```

See each chart's own README for the full list of values
(e.g. [charts/affine/README.md](charts/affine/README.md)).

### Install from a local checkout

```bash
git clone https://github.com/<owner>/helm-charts.git
helm install affine ./charts/affine
```

## Releasing a new version

1. Bump `version` in the chart's `Chart.yaml`
2. Push to `main` — the [release workflow](.github/workflows/release.yml) packages
   the chart, creates a GitHub Release with the `.tgz` as asset, and updates
   `index.yaml` on the `gh-pages` branch automatically

Pull requests only lint; nothing is published until merged to `main`.

## First-time setup

Enable GitHub Pages on the repository pointing to the `gh-pages` branch
(Settings → Pages → Branch: `gh-pages` / `root`). The branch is created
automatically on the first release.

## Development

```bash
helm lint --strict charts/affine
helm template test charts/affine | less
```

## License

MIT
