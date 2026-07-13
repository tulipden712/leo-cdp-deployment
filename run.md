# Chạy LEO CDP bằng Docker Compose

## 1. Chuẩn bị

```bash
cp .env.example .env
# Sửa ARANGO_ROOT_PASSWORD nếu cần — phải khớp password trong configs/PRO-database-configs.json
```

Configs Docker đã sẵn trong repo:

| File | Giá trị quan trọng |
|------|-------------------|
| `configs/PRO-database-configs.json` | `host=arangodb`, `port=8529`, password khớp `.env` |
| `configs/redis-configs.json` | `host=redis`, `port=6379` |
| `configs/http-routing-configs.json` | `host=0.0.0.0`, admin `9071`, observer `9081` |

## 2. Metadata (bắt buộc)

```bash
cp leocdp-metadata.properties.example leocdp-metadata.properties
# Sửa domain / email / SMTP cho đúng môi trường của bạn
```

File này được mount vào `/app/leocdp-metadata.properties`. Giữ `mainDatabaseConfig=cdpDbConfigs` và `systemDatabaseConfig=cdpDbConfigs`.

## 3. Build & chạy

```bash
docker compose build
docker compose up -d
docker compose ps
docker compose logs -f leocdp-admin
```

Port trên host (OpenResty proxy vào đây):

| Service | Host | Container |
|---------|------|-----------|
| Admin | `127.0.0.1:8600` | `9071` |
| Observer | `127.0.0.1:8601` | `9081` |

## 4. Setup database lần đầu (sau khi ArangoDB healthy)

```bash
# Chạy setup trong container admin (hoặc máy có Java 11 + cùng configs)
docker compose exec leocdp-admin java -jar /app/app.jar setup-system-with-password 'YOUR_SUPERADMIN_PASSWORD'
```

## 5. OpenResty

Thêm `openresty-leocdp.conf` vào config OpenResty trên host, sửa domain, rồi reload.

## Lưu ý

- `HTTP_ROUTER_KEY` / `HTTP_ROUTER_KEY1` phải là key thật trong `http-routing-configs.json` (`leocdp_admin1`, `datahub1`).
- Redis chạy nội bộ **không password** (app config không hỗ trợ auth).
- Khi có JAR mới: thay file `leo-*-starter-v_0.9.0.jar` ở root rồi `docker compose build --no-cache`.
- Scheduler / data-connector không có HTTP healthcheck.
