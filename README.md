# Apache APISIX

Apache APISIX is a cloud-native microservices API gateway. This template deploys APISIX in standalone mode on Railway with no etcd dependency — a single container that loads routes from a local YAML file.

## Features

- **Standalone mode** — no etcd required, routes loaded from apisix.yaml
- **Single container** — lower memory usage, faster deploys, higher health score
- **Admin API** — manage routes, plugins, and upstreams via REST API
- **Pay-per-call ready** — integrate with x402 for monetized API access

## Deploy

[![Deploy to Railway](https://railway.app/button.svg)](https://railway.com/deploy/apisix)

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `APIXIX_ADMIN_KEY` | Admin API key for route management | `edd1c9f034335f136f87ad84b625c8f1` |
| `PORT` | Port APISIX listens on | `9080` |

## Usage

After deploy, access the demo route:

```bash
curl https://xxx.up.railway.app/get
```

Add a new route via the admin API:

```bash
curl https://xxx.up.railway.app/apisix/admin/routes \
  -H "X-API-KEY: $APIXIX_ADMIN_KEY" \
  -X POST \
  -d '{
    "uri": "/hello",
    "upstream": {
      "type": "roundrobin",
      "nodes": {"httpbin.org:80": 1}
    }
  }'
```

## License

Apache License 2.0
