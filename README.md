# Apache APISIX — Railway Deployment Template

> **Cloud-native microservices API gateway with admin dashboard.** APISIX + etcd companion on Railway — full Admin API and dashboard included.

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/deploy/apisix)

[![GitHub Repo](https://img.shields.io/badge/GitHub-INAPP--Mobile%2Frailway--apisix-181717?style=flat-square&logo=github)](https://github.com/INAPP-Mobile/railway-apisix)
[![APISIX](https://img.shields.io/badge/APISIX-Apache-2.0-blue?style=flat-square)](https://github.com/apache/apisix)
[![License](https://img.shields.io/badge/License-Apache%202.0-green?style=flat-square)](https://github.com/apache/apisix/blob/master/LICENSE)

---

# Deploy and Host

Deploy Apache APISIX on Railway in one click. This template provisions APISIX with an etcd companion service — the full Admin API and dashboard are available out of the box. SSL is handled automatically by Railway.

## About Hosting

This template runs two services:

- **APISIX Gateway** (port 9080) — routes, plugins, and rate limits
- **etcd** (port 2379, private network) — configuration store backing the Admin API
- **Admin API + Dashboard** (port 9180) — manage routes via REST API or the web UI at `/ui`
- **Health endpoint** — `/health` returns 200 for Railway healthchecks

## Why Deploy

APISIX is a top-tier open-source API gateway (CNCF project) used by companies like Verizon, Robinhood, and Wipro. Unlike the standalone variant, this template ships the full admin experience — create routes, manage plugins, and monitor traffic from the dashboard, with etcd as the durable config store.

## Common Use Cases

- **API gateway** — route, rate-limit, and authenticate traffic to your microservices
- **Admin dashboard** — manage routes and plugins from the web UI at `/ui`
- **Plugin playground** — key-auth, JWT, rate limiting, CORS, and 80+ plugins
- **Pay-per-call API** — pair with x402 for monetized API access

---

## Dependencies for APISIX

### Runtime

| Dependency | Version/Type | Purpose                              |
|------------|--------------|--------------------------------------|
| APISIX     | 3.18.0       | API gateway (OpenResty-based)        |
| etcd       | 3.5.11       | Configuration store for Admin API    |
| OpenResty  | bundled      | Nginx runtime for APISIX             |
| LuaJIT     | bundled      | Plugin execution engine              |

### Deployment Dependencies

| Tool              | Purpose                                |
|-------------------|----------------------------------------|
| Docker            | Container runtime (managed by Railway) |
| Railway           | Hosting platform                       |
| Railway Volume    | Persistent storage for etcd data       |

---

## ✨ Features

- **Admin API + Dashboard** — full route management at `/ui` and `/apisix/admin/*`
- **etcd companion** — durable config store, auto-provisioned
- **Declarative or dynamic routing** — create routes via API/dashboard, or preload in etcd
- **Pay-per-call ready** — integrate with x402 for monetized API access

---

## 🚀 Quick Start

### One-click Deploy

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/deploy/apisix)

### Manual Deploy

```bash
git clone https://github.com/INAPP-Mobile/railway-apisix.git
cd apisix
railway up
```

---

## ⚙️ Environment Variables

| Variable          | Required | Description                                        |
|-------------------|----------|----------------------------------------------------|
| `PORT`            | ✅ Yes   | Port APISIX listens on (default `9080`)            |
| `APISIX_ADMIN_KEY`| ✅ Yes   | Admin API key. Must match `config.yaml`.           |

---

## 📡 Usage

### Dashboard

Open `https://your-app.up.railway.app/ui` and sign in with the admin key.

### Admin API

```bash
# List routes
curl https://your-app.up.railway.app/apisix/admin/routes \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1"

# Create a route proxying to a backend
curl -X PUT https://your-app.up.railway.app/apisix/admin/routes/hello \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  -H "Content-Type: application/json" \
  -d '{
    "uri": "/hello",
    "upstream": {
      "type": "roundrobin",
      "nodes": {"httpbin.org:80": 1}
    }
  }'
```

### Gateway

```bash
curl https://your-app.up.railway.app/hello
```

---

## License

Apache License 2.0