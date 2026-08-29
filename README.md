# Apache APISIX

Apache APISIX is a cloud-native microservices API gateway. This template deploys APISIX in standalone mode on Railway with no etcd dependency — a single container that loads routes from a local YAML file.

## Features

- **Standalone mode** — no etcd required, routes loaded from `apisix.yaml`
- **Single container** — lower memory usage, faster deploys, higher health score
- **Declarative routing** — edit `apisix.yaml` and redeploy to change routes
- **Pay-per-call ready** — integrate with x402 for monetized API access

## Deploy

[![Deploy to Railway](https://railway.app/button.svg)](https://railway.com/deploy/apisix)

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Port APISIX listens on | `9080` |

## Usage

After deploy, the gateway answers on every path:

```bash
curl https://xxx.up.railway.app/
# ok

curl https://xxx.up.railway.app/health
# ok
```

### Adding routes

Edit `apisix.yaml` in this repo and redeploy. For example, to proxy `/api` to a backend service:

```yaml
routes:
  - uri: /api/*
    upstream:
      type: roundrobin
      nodes:
        "httpbin.org:80": 1
```

## License

Apache License 2.0