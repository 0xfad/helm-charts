# Helm Charts

A collection of Helm charts for self-hosted applications, packaged to be served as
a Helm repository over GitHub Pages.

## Available charts

| Chart | Description | App |
|-------|-------------|-----|
| [affine](charts/affine) | Self-hosted [AFFiNE](https://affine.pro) workspace with bundled PostgreSQL (pgvector) and Redis | `ghcr.io/toeverything/affine` |

## Usage

Add the repository (replace the URL with your published GitHub Pages URL):

```bash
helm repo add 0xfad https://<your-github-user>.github.io/helm-charts
helm repo update
```

Install a chart, e.g. AFFiNE:

```bash
helm install affine 0xfad/affine \
  --set affine.serverExternalUrl=https://affine.example.com \
  --set postgresql.auth.password=<strong-password>
```

See each chart's own README for the full set of configuration values
(e.g. [charts/affine/README.md](charts/affine/README.md)).

### Install straight from a checkout

You don't need the published repo to try a chart locally:

```bash
git clone https://github.com/<your-github-user>/helm-charts.git
cd helm-charts
helm install affine ./charts/affine
```

## Publishing (GitHub Pages)

This repo is laid out so it can be served as a Helm chart repository. The typical
flow is:

1. Package the charts and (re)generate the index:

   ```bash
   helm package charts/* --destination .
   helm repo index . --url https://<your-github-user>.github.io/helm-charts
   ```

2. Commit the generated `*.tgz` packages and `index.yaml`, then enable **GitHub
   Pages** for the repository (Settings → Pages → deploy from the `main` branch).

3. Consumers can then `helm repo add` the Pages URL as shown above.

> Tip: for an automated release pipeline, consider the
> [`helm/chart-releaser-action`](https://github.com/helm/chart-releaser-action)
> GitHub Action, which packages charts and publishes them to GitHub Releases +
> Pages on every push to `main`.

## Development

Lint and render a chart before committing:

```bash
helm lint charts/affine
helm template test charts/affine | less
```

## License

MIT
