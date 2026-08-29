# Apache APISIX — Railway Deployment Template

> **Cloud-native microservices API gateway.** Standalone mode on Railway — no etcd dependency, single container, routes loaded from a local YAML file.

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/deploy/hCgTos)

[![GitHub Repo](https://img.shields.io/badge/GitHub-INAPP--Mobile%2Frailway--apisix-181717?style=flat-square&logo=github)](https://github.com/INAPP-Mobile/railway-apisix)
[![APISIX](https://img.shields.io/badge/APISIX-Apache-2.0-blue?style=flat-square)](https://github.com/apache/apisix)
[![License](https://img.shields.io/badge/License-Apache%202.0-green?style=flat-square)](https://github.com/apache/apisix/blob/master/LICENSE)

---

# Deploy and Host

Deploy Apache APISIX on Railway in one click. This template provisions a single container running the APISIX gateway in standalone mode (`data_plane` + `config_provider: yaml`) — routes are declared in `apisix.yaml`, no etcd cluster required. SSL is handled automatically by Railway.

## About Hosting

This template runs APISIX v3.18.0 inside a single Railway container:

- **APISIX Gateway** listens on port 9080 and serves routes declared in `apisix.yaml`
- **Standalone mode** — routes load from the local YAML file at boot; edit and redeploy to change routing
- **No etcd** — no external dependency, lower memory usage, faster deploys
- **Health endpoint** — `/health` returns 200 for Railway healthchecks

## Why Deploy

APISIX is a top-tier open-source API gateway (CNCF project) used by companies like Verizon, Robinhood, and Wipro. Self-hosting gives you full control over your routing, plugins, and rate limits — with a single-container footprint on Railway and no infrastructure to manage.

## Common Use Cases

- **API gateway** — route, rate-limit, and authenticate traffic to your microservices
- **Reverse proxy** — expose internal services with path-based routing
- **Plugin playground** — key-auth, JWT, rate limiting, CORS, and 80+ plugins
- **Pay-per-call API** — pair with x402 for monetized API access

---

## Dependencies for APISIX

### Runtime

| Dependency | Version/Type | Purpose                              |
|------------|--------------|--------------------------------------|
| APISIX     | 3.18.0       | API gateway (OpenResty-based)        |
| OpenResty  | bundled      | Nginx runtime for APISIX             |
| LuaJIT     | bundled      | Plugin execution engine              |

### Deployment Dependencies

| Tool              | Purpose                                |
|-------------------|----------------------------------------|
| Docker            | Container runtime (managed by Railway) |
| Railway           | Hosting platform                       |

---

## ✨ Features

- **Standalone mode** — no etcd required, routes loaded from `apisix.yaml`
- **Single container** — lower memory usage, faster deploys, higher health score
- **Declarative routing** — edit `apisix.yaml` and redeploy to change routes
- **Pay-per-call ready** — integrate with x402 for monetized API access

---

## 🚀 Quick Start

### One-click Deploy

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/deploy/hCgTos)

### Manual Deploy

```bash
git clone https://github.com/INAPP-Mobile/railway-apisix.git
cd apisix
railway up
```

---

## ⚙️ Environment Variables

| Variable | Required | Description                          |
|----------|----------|--------------------------------------|
| `PORT`   | ✅ Yes   | Port APISIX listens on (default `9080`) |

---

## 📡 Usage

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

---

## License

Apache License 2.0