# 🧭 LEO CDP – Service Load Balancing (HAProxy → NGINX → Java Workers)

### Overview

This document describes how to configure **NGINX** as an internal load balancer for the **LEO CDP Admin Dashboard** services and  **LEO CDP Data Hub** services
Traffic from the public internet first enters **HAProxy**, which handles SSL termination and high-availability routing.
HAProxy then forwards internal HTTP traffic to NGINX, which distributes requests to multiple Java-based worker instances using **round-robin** load balancing.

#### LEO CDP Admin Dashboard
```
Internet
   │
[ HAProxy :80 / :443 ]
   │  (internal forwarding)
   ▼
[ NGINX :9070 ]
   │
   ├── [ leocdp_admin1 :9071 ]
   ├── [ leocdp_admin2 :9072 ]
   └── [ leocdp_admin3 :9073 ]
```

#### LEO CDP Data Hub
```
Internet
   │
[ HAProxy :80 / :443 ]
   │  (internal forwarding)
   ▼
[ NGINX :9070 ]
   │
   ├── [ leocdp_datahub1 :9081 ]
   ├── [ leocdp_datahub2 :9082 ]
   └── [ leocdp_datahub3 :9083 ]
```


---

### Component Roles

| Component         | Port     | Description                                                                        |
| ----------------- | -------- | ---------------------------------------------------------------------------------- |
| **HAProxy**       | 80 / 443 | Public-facing load balancer. Handles SSL termination and routes requests to NGINX. |
| **NGINX**         | **9070** | Internal reverse proxy. Balances load across multiple Java worker nodes.           |
| **leocdp_admin1** | 9071     | Main Admin Dashboard worker (primary).                                             |
| **leocdp_admin2** | 9072     | Backup worker 1.                                                                   |
| **leocdp_admin3** | 9073     | Backup worker 2.                                                                   |

---

### NGINX Configuration

#### leocdp_admin.conf

Create or update `/etc/nginx/conf.d/leocdp_admin.conf` with the following content:

```nginx
# ==========================================
# LEO CDP Admin – Internal Load Balancer
# ==========================================

upstream leocdp_admin_upstream {
    # Round-robin load balancing across 3 workers
    server cdpsys.admin:9071 max_fails=3 fail_timeout=10s;
    server cdpsys.admin:9072 max_fails=3 fail_timeout=10s;
    server cdpsys.admin:9073 max_fails=3 fail_timeout=10s;

    # Maintain keepalive connections for efficiency
    keepalive 32;
}

server {
    # NGINX listens internally on port 9070
    listen 9070;
    server_name leocdp.admin cdpsys.admin;

    # Optional: restrict access to internal network only
    # allow 10.0.0.0/8;
    # deny all;

    location / {
        proxy_pass http://leocdp_admin_upstream;

        # Preserve client and protocol info from HAProxy
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Enable WebSocket / SockJS compatibility
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Connection and timeout settings
        proxy_connect_timeout 5s;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
        send_timeout 60s;
    }

    # Local health endpoint (used by HAProxy)
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    access_log /var/log/nginx/leocdp_admin_access.log;
    error_log  /var/log/nginx/leocdp_admin_error.log;
}
```

#### leocdp_datahub.conf

Create or update `/etc/nginx/conf.d/leocdp_datahub.conf` with the following content:

```nginx

# ==========================================
# LEO CDP DataHub – Internal Load Balancer
# ==========================================

# === UPSTREAM GROUP: Round-robin load balancing for 3 DataHub workers ===
upstream leocdp_datahub_upstream {
    server cdpsys.datahub:9081 max_fails=3 fail_timeout=10s;
    server cdpsys.datahub:9082 max_fails=3 fail_timeout=10s;
    server cdpsys.datahub:9083 max_fails=3 fail_timeout=10s;

    # Maintain persistent TCP connections between NGINX and workers
    keepalive 32;
}

# === SERVER BLOCK: NGINX entry point for DataHub traffic ===
server {
    # HAProxy forwards traffic here
    listen 9080;
    server_name leocdp.datahub cdpsys.datahub;

    # Optional: restrict to internal network if HAProxy is the only client
    # allow 10.0.0.0/8;
    # deny all;

    # ==========================
    # MAIN ROUTE
    # ==========================
    location / {
        proxy_pass http://leocdp_datahub_upstream;

        # Preserve client context (for logging, tracing, etc.)
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # ObserverHttpRouter doesn’t use SockJS/WebSocket, so upgrade headers optional
        proxy_http_version 1.1;
        proxy_set_header Connection "";

        # Connection timeouts
        proxy_connect_timeout 5s;
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
        send_timeout 60s;
    }

    # ==========================
    # HEALTH CHECK
    # ==========================
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    # ==========================
    # LOGGING
    # ==========================
    access_log /var/log/nginx/leocdp_datahub_access.log;
    error_log  /var/log/nginx/leocdp_datahub_error.log;
}
```

---

### Deployment Steps

1. **Copy the configuration for leocdp admin**

   ```bash
   sudo nano /etc/nginx/conf.d/leocdp_admin.conf
   ```

   Paste the block above and save.

2. **Copy the configuration for leocdp datahub**

   ```bash
   sudo nano sudo nano /etc/nginx/conf.d/leocdp_datahub.conf
   ```

   Paste the block above and save.

3. **Test configuration**

   ```bash
   sudo nginx -t
   ```

4. **Reload NGINX**

   ```bash
   sudo systemctl reload nginx
   ```

5. **Verify NGINX is listening**

   ```bash
   sudo ss -tulnp | grep nginx
   ```

   Expected output:

   ```
   tcp   LISTEN  0 128 0.0.0.0:9070  ...  nginx
   ```

5. **Health check**
   Test locally:

   Admin 
   ```bash
   curl http://localhost:9070/health
   ```

   Data Hub
   ```bash
   curl http://localhost:9080/health
   ```

   Response:

   ```
   OK
   ```

---

### Operational Notes

* **Load Balancing Method**: Round-robin (default)
* **Failover Handling**: Any worker that fails 3 times within 10 seconds is temporarily removed from rotation.
* **WebSocket Compatibility**: Fully supported via the `Upgrade` and `Connection` headers.
* **Keepalive Optimization**: NGINX maintains persistent TCP connections to each backend to reduce latency.
* **Log Files**:

  * Access log → `/var/log/nginx/leocdp_admin_access.log`
  * Error log → `/var/log/nginx/leocdp_admin_error.log`

---

### Example HAProxy Backend (for reference)

HAProxy forwards all `leocdp.admin` traffic to NGINX port 9070:

```haproxy
backend leocdp_admin_backend
    mode http
    balance roundrobin
    option httpchk GET /health
    server nginx-lb 127.0.0.1:9070 check inter 5s rise 2 fall 3
```

---

### Summary

This setup provides:

* Multi-instance scalability for LEO CDP Admin workers
* Smooth failover and round-robin balancing
* Layered HA design (HAProxy + NGINX)
* Compatibility with WebSockets and reactive handlers in Vert.x

Result: a high-availability, low-latency admin interface ready for production.
