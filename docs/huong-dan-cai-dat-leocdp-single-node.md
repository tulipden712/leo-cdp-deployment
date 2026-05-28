# Hướng dẫn cài đặt LEO CDP Single Node

Tài liệu này dành cho IT manager, DevOps hoặc developer cần triển khai LEO CDP Free Edition trên một máy chủ Linux duy nhất.

Single Node nghĩa là cùng một server sẽ chạy đầy đủ các thành phần:

- Admin Dashboard
- Data Observer / Data Hub
- Scheduler / Data Connector Jobs
- Redis
- ArangoDB
- Nginx reverse proxy

## 1. Tổng quan triển khai

### 1.1. Mô hình hệ thống

```text
User / Browser
      |
      v
Nginx :80 / :443
      |
      +--> LEO CDP Admin service
      +--> LEO CDP Observer service
      +--> LEO Bot endpoint

LEO CDP services
      |
      +--> Redis :6379
      +--> ArangoDB
      +--> Local queue hoặc Kafka nếu cấu hình thêm
```

### 1.2. User chạy service

Script đang dùng user mặc định:

```text
cdpsysuser
```

User này được tạo bởi `setup-system-user.sh` và được dùng để chạy các service Java. Không nên chạy các service CDP bằng user `root`.

### 1.3. Thư mục cài đặt chuẩn

Script đang dùng thư mục:

```text
/build/cdp-instance
```

Tất cả JAR, script, config, metadata và log runtime nên nằm trong thư mục này.

## 2. Yêu cầu trước khi cài đặt

### 2.1. Server

Khuyến nghị tối thiểu cho môi trường dev/UAT nhỏ:

| Hạng mục | Khuyến nghị |
| --- | --- |
| OS | Ubuntu Server 22.04 hoặc 24.04 |
| CPU | 4 vCPU trở lên |
| RAM | 8 GB trở lên |
| Disk | 100 GB SSD trở lên |
| Network | Có quyền truy cập internet để tải package |
| Quyền hệ thống | Có quyền `sudo` hoặc root |

Khuyến nghị cho production nhỏ:

| Hạng mục | Khuyến nghị |
| --- | --- |
| CPU | 8 vCPU trở lên |
| RAM | 16 GB trở lên |
| Disk | 200 GB SSD trở lên, có backup |
| Network | IP tĩnh, DNS domain rõ ràng |
| Firewall | Chỉ mở các port cần thiết |

### 2.2. Package hệ thống được script cài

Các script trong `script-new-installation/` sẽ cài:

| Script | Thành phần |
| --- | --- |
| `install-java.sh` | Amazon Corretto JDK 11 |
| `install-redis.sh` | Redis 8.x từ packages.redis.io |
| `install-database.sh` | ArangoDB 3.11.14 Community |
| `install-nginx.sh` | Nginx stable từ nginx.org |

### 2.3. Domain cần chuẩn bị

Nên chuẩn bị các domain hoặc subdomain trước khi chạy metadata setup:

| Mục đích | Ví dụ |
| --- | --- |
| Admin Dashboard | `admin-cdp.example.com` |
| WebSocket | `ws-cdp.example.com` |
| Data Observer | `data-cdp.example.com` |
| LEO Bot | `bot-cdp.example.com` |

Nếu chỉ cài nội bộ/dev, có thể dùng IP server hoặc domain nội bộ.

### 2.4. Thông tin SMTP

Chuẩn bị trước:

- SMTP host
- SMTP port, thường là `587`
- SMTP username
- SMTP password
- Email gửi đi, ví dụ `no-reply@example.com`

Nếu chưa có SMTP, vẫn có thể để trống trong môi trường dev, nhưng production nên cấu hình đầy đủ.

## 3. Checklist trước khi chạy script

Trước khi cài đặt, IT/dev nên kiểm tra:

- Server là Ubuntu 22.04/24.04.
- User đang thao tác có quyền `sudo`.
- Server truy cập được internet.
- DNS đã trỏ về server nếu dùng domain thật.
- Port `80`, `443`, `6379`, port ArangoDB và các port service CDP không bị chiếm.
- Repo LEO CDP đã có đủ các file JAR:
  - `leo-main-starter-v_0.9.0.jar`
  - `leo-observer-starter-v_0.9.0.jar`
  - `leo-scheduler-starter-v_0.9.0.jar`
  - `leo-data-processing-starter-v_0.9.0.jar`
- Đã thống nhất email super admin.
- Đã thống nhất nơi lưu backup database.

## 4. Luồng cài đặt tự động hiện tại

File chính:

```bash
setup-leocdp-single-node.sh
```

Script này đang làm các bước:

1. Kiểm tra script được chạy bằng root.
2. Tạo system user bằng `setup-system-user.sh`.
3. Cài Java, Redis, ArangoDB và Nginx.
4. Tạo thư mục `/build/cdp-instance`.
5. Chuyển quyền `/build` cho `cdpsysuser`.
6. Chạy metadata setup và database setup bằng user `cdpsysuser`.
7. Start Admin, Observer và Data Connector Jobs.

Lệnh chạy dự kiến:

```bash
sudo bash setup-leocdp-single-node.sh
```

## 5. Cài đặt từng bước khuyến nghị

Phần này là quy trình dễ kiểm soát hơn cho IT/dev. Nên dùng quy trình này khi cài production hoặc UAT.

### Bước 1: Đăng nhập server

```bash
ssh ubuntu@your-server-ip
```

Chuyển vào thư mục chứa source/release package:

```bash
cd /path/to/leo-cdp-free-edition
```

Nếu release package cần đặt tại `/build/cdp-instance`, tạo thư mục:

```bash
sudo mkdir -p /build/cdp-instance
```

Copy nội dung release vào thư mục chuẩn:

```bash
sudo rsync -a /path/to/leo-cdp-free-edition/ /build/cdp-instance/
```

> Lưu ý: bước copy này rất quan trọng. Các script start service đang hard-code `LEO_CDP_FOLDER="/build/cdp-instance"`.

### Bước 2: Tạo system user

Chạy:

```bash
cd /build/cdp-instance
sudo bash setup-system-user.sh
```

Kết quả mong đợi:

- User `cdpsysuser` được tạo nếu chưa tồn tại.
- Home directory là `/home/cdpsysuser`.
- User được thêm vào group `sudo`.
- File sudoers `/etc/sudoers.d/cdpsysuser` được tạo.

Kiểm tra:

```bash
id cdpsysuser
sudo -u cdpsysuser whoami
```

### Bước 3: Cấp quyền thư mục build

```bash
sudo chown -R cdpsysuser:cdpsysuser /build
sudo chmod -R 755 /build/cdp-instance
```

Kiểm tra:

```bash
ls -ld /build /build/cdp-instance
```

### Bước 4: Cài Java 11

```bash
cd /build/cdp-instance
sudo bash script-new-installation/install-java.sh
```

Kiểm tra:

```bash
java -version
javac -version
```

Kết quả cần thấy Java version 11.

### Bước 5: Cài Redis

```bash
sudo bash script-new-installation/install-redis.sh
```

Kiểm tra:

```bash
redis-cli ping
systemctl status redis-server --no-pager
```

Kết quả mong đợi:

```text
PONG
```

### Bước 6: Cài ArangoDB

```bash
sudo bash script-new-installation/install-database.sh
```

Khi script hỏi:

```text
Is this server intended for the LEO CDP database? (y/n):
```

Nhập:

```text
y
```

Kiểm tra:

```bash
arangod --version
systemctl status arangodb3 --no-pager
```

### Bước 7: Cài Nginx

```bash
sudo bash script-new-installation/install-nginx.sh
```

Kiểm tra:

```bash
nginx -v
systemctl status nginx --no-pager
```

### Bước 8: Chuyển sang user chạy CDP

```bash
sudo su - cdpsysuser
cd /build/cdp-instance
```

Kiểm tra các file quan trọng:

```bash
ls -1 setup-leocdp-metadata.sh setup-leocdp-database.sh start-admin.sh start-observer.sh start-data-connector-jobs.sh
ls -1 leo-main-starter-v_0.9.0.jar leo-observer-starter-v_0.9.0.jar leo-scheduler-starter-v_0.9.0.jar
```

### Bước 9: Tạo metadata cấu hình hệ thống

Chạy:

```bash
bash setup-leocdp-metadata.sh
```

Script sẽ hỏi các thông tin:

| Câu hỏi | Ý nghĩa | Ví dụ |
| --- | --- | --- |
| HTTP Admin Domain | Domain Admin Dashboard | `admin-cdp.example.com` |
| WebSocket Domain | Domain WebSocket | `ws-cdp.example.com` |
| Data Observer Domain | Domain nhận event/data | `data-cdp.example.com` |
| LEO Bot Domain | Domain LEO Bot | `bot-cdp.example.com` |
| LEO Bot API Key | API key gọi LEO Bot | `your-secret-key` |
| Super Admin Email | Email admin đầu tiên | `admin@example.com` |
| Admin Logo URL | Logo trên Admin UI | Có thể bỏ trống để dùng mặc định |
| SMTP Host | Mail server | `smtp.gmail.com` |
| SMTP Port | Mail port | `587` |
| SMTP User | Mail user | `no-reply@example.com` |
| SMTP Password | Mail password/app password | `********` |
| SMTP From Address | Email gửi đi | `no-reply@example.com` |
| Database Backup Path | Thư mục backup | `/build/cdp-instance/backup_database` |
| Backup Period Hours | Chu kỳ backup | `24` |
| Backup Retention Days | Số ngày giữ backup | `7` |

Sau khi chạy xong, file sau sẽ được tạo:

```text
/build/cdp-instance/leocdp-metadata.properties
```

Kiểm tra nhanh:

```bash
head -n 40 leocdp-metadata.properties
```

### Bước 10: Kiểm tra metadata bắt buộc

Trước khi setup database, kiểm tra các key:

```bash
grep -E "^(superAdminEmail|mainDatabaseConfig|systemDatabaseConfig)=" leocdp-metadata.properties
```

Cần có đủ:

```properties
superAdminEmail=...
mainDatabaseConfig=cdpDbConfigs
systemDatabaseConfig=cdpDbConfigs
```

Nếu thiếu `systemDatabaseConfig`, cần bổ sung vào `leocdp-metadata.properties` trước khi chạy database setup:

```properties
systemDatabaseConfig=cdpDbConfigs
```

### Bước 11: Khởi tạo database CDP

Chạy bằng user `cdpsysuser`:

```bash
bash setup-leocdp-database.sh
```

Script sẽ hỏi mật khẩu super admin:

```text
Enter the superadmin password:
Confirm password:
```

Mật khẩu này sẽ dùng cho email super admin đã nhập trong metadata.

Kết quả mong đợi:

```text
LEO CDP Database setup completed successfully
```

### Bước 12: Start service

Chạy:

```bash
bash start-admin.sh
bash start-observer.sh
bash start-data-connector-jobs.sh
```

Admin script sẽ start 3 process theo router key:

```text
leocdp_admin1
leocdp_admin2
leocdp_admin3
```

Observer script sẽ start 3 process:

```text
datahub1
datahub2
datahub3
```

### Bước 13: Kiểm tra process

```bash
ps -ef | grep java | grep leo
```

Hoặc kiểm tra theo router:

```bash
pgrep -af "leocdp_admin|datahub|DataConnectorScheduler"
```

### Bước 14: Kiểm tra log

Log Admin và Observer nằm trong:

```text
/build/cdp-instance/logs
```

Xem log:

```bash
tail -f /build/cdp-instance/logs/admin-leocdp_admin1.log
tail -f /build/cdp-instance/logs/observer-datahub1.log
```

Data Connector Jobs hiện ghi log:

```text
/build/cdp-instance/DataConnectorScheduler.log
```

Xem log:

```bash
tail -f /build/cdp-instance/DataConnectorScheduler.log
```

## 6. Cấu hình reverse proxy Nginx

Các service CDP chạy nhiều process theo port trong `configs/http-routing-configs.json`.

Các port đang được khai báo:

| Service | Router key | Port |
| --- | --- | --- |
| Admin | `leocdp_admin1` | `9071` |
| Admin | `leocdp_admin2` | `9072` |
| Admin | `leocdp_admin3` | `9073` |
| Observer | `datahub1` | `9081` |
| Observer | `datahub2` | `9082` |
| Observer | `datahub3` | `9083` |

Ví dụ cấu hình Nginx đơn giản cho Admin:

```nginx
upstream leocdp_admin {
    server 127.0.0.1:9071;
    server 127.0.0.1:9072;
    server 127.0.0.1:9073;
}

server {
    listen 80;
    server_name admin-cdp.example.com;

    location / {
        proxy_pass http://leocdp_admin;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Ví dụ cấu hình Nginx cho Observer:

```nginx
upstream leocdp_observer {
    server 127.0.0.1:9081;
    server 127.0.0.1:9082;
    server 127.0.0.1:9083;
}

server {
    listen 80;
    server_name data-cdp.example.com;

    location / {
        proxy_pass http://leocdp_observer;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Sau khi tạo config:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## 7. Firewall khuyến nghị

Nếu dùng UFW:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status
```

Không nên mở public các port sau nếu không có yêu cầu rõ ràng:

- Redis `6379`
- ArangoDB
- Admin backend port `9071-9073`
- Observer backend port `9081-9083`

Các port backend nên chỉ cho Nginx/local server truy cập.

## 8. Dừng, restart và vận hành

### 8.1. Dừng toàn bộ service

```bash
cd /build/cdp-instance
sudo -u cdpsysuser bash stop-server.sh
```

### 8.2. Start lại service

```bash
cd /build/cdp-instance
sudo -u cdpsysuser bash start-admin.sh
sudo -u cdpsysuser bash start-observer.sh
sudo -u cdpsysuser bash start-data-connector-jobs.sh
```

### 8.3. Restart Redis/Nginx/ArangoDB

```bash
sudo systemctl restart redis-server
sudo systemctl restart nginx
sudo systemctl restart arangodb3
```

## 9. Backup database

Metadata có các cấu hình:

```properties
databaseBackupPeriodHours=24
databaseBackupRetentionDays=7
databaseBackupPath=/build/cdp-instance/backup_database
```

Khuyến nghị:

- Dùng thư mục backup riêng, ví dụ `/build/cdp-instance/backup_database`.
- Mount disk backup riêng nếu là production.
- Copy backup ra object storage hoặc backup server.
- Kiểm tra restore định kỳ, không chỉ kiểm tra file backup tồn tại.

Nếu dùng script backup/restore:

```bash
cd /build/cdp-instance
sudo -u cdpsysuser bash run-database-backup-restore.sh
```

## 10. Kiểm tra sau cài đặt

IT/dev nên chạy checklist này:

```bash
java -version
redis-cli ping
arangod --version
nginx -v
pgrep -af "leocdp_admin|datahub|DataConnectorScheduler"
ls -lah /build/cdp-instance/logs
```

Kiểm tra HTTP local:

```bash
curl -I http://127.0.0.1:9071
curl -I http://127.0.0.1:9081
```

Kiểm tra qua domain:

```bash
curl -I http://admin-cdp.example.com
curl -I http://data-cdp.example.com
```

## 11. Troubleshooting nhanh

### 11.1. `setup-leocdp-metadata.sh not found`

Nguyên nhân thường gặp:

- Chưa copy release package vào `/build/cdp-instance`.
- Đang đứng sai thư mục.

Cách kiểm tra:

```bash
pwd
ls -lah /build/cdp-instance
```

### 11.2. Java version không đúng

`setup-leocdp-database.sh` yêu cầu Java 11.

Kiểm tra:

```bash
java -version
```

Nếu không phải Java 11, chạy lại:

```bash
sudo bash script-new-installation/install-java.sh
```

### 11.3. Thiếu `systemDatabaseConfig`

`setup-leocdp-database.sh` đang validate key này:

```text
systemDatabaseConfig
```

Nếu metadata template chưa sinh ra key này, thêm vào `leocdp-metadata.properties`:

```properties
systemDatabaseConfig=cdpDbConfigs
```

### 11.4. Data Connector Jobs không start

Kiểm tra file:

```bash
/build/cdp-instance/start-data-connector-jobs.sh
```

Kiểm tra log:

```bash
tail -f /build/cdp-instance/DataConnectorScheduler.log
```

Kiểm tra process:

```bash
pgrep -af DataConnectorScheduler
```

### 11.5. Nginx chạy nhưng domain không vào được

Kiểm tra:

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
dig admin-cdp.example.com
curl -I http://127.0.0.1:9071
```

Nếu local port trả lời nhưng domain không trả lời, kiểm tra DNS, firewall hoặc Nginx server block.

## 12. Review code hiện tại

Các điểm dưới đây nên được xử lý trước khi dùng `setup-leocdp-single-node.sh` cho production.

### 12.1. Thiếu bước copy release vào `/build/cdp-instance`

`setup-leocdp-single-node.sh` tạo thư mục:

```bash
mkdir -p "$BUILD_DIR"
```

Sau đó chạy:

```bash
cd $BUILD_DIR
bash setup-leocdp-metadata.sh
bash setup-leocdp-database.sh
```

Nhưng script chưa copy các file từ repo hiện tại sang `$BUILD_DIR`. Nếu `/build/cdp-instance` đang rỗng, bước metadata sẽ fail.

Khuyến nghị:

- Thêm bước `rsync` release package vào `$BUILD_DIR`; hoặc
- Yêu cầu người vận hành clone/copy repo vào `/build/cdp-instance` trước khi chạy.

### 12.2. Thông báo lỗi gọi sai tên script

Trong `setup-leocdp-single-node.sh`:

```bash
echo "Please run as root: sudo bash install-leo-cdp.sh"
```

Tên script thực tế là:

```bash
setup-leocdp-single-node.sh
```

Nên đổi thông báo thành:

```bash
sudo bash setup-leocdp-single-node.sh
```

### 12.3. Metadata template thiếu `systemDatabaseConfig`

`setup-leocdp-database.sh` kiểm tra:

```bash
required_keys=("superAdminEmail" "mainDatabaseConfig" "systemDatabaseConfig")
```

Nhưng `setup-leocdp-metadata-tpl.properties` hiện chỉ có:

```properties
mainDatabaseConfig=cdpDbConfigs
```

Nên bổ sung:

```properties
systemDatabaseConfig=cdpDbConfigs
```

### 12.4. Giá trị backup period/retention nhập vào chưa được dùng

`setup-leocdp-metadata.sh` có hỏi:

```bash
Backup Period Hours
Backup Retention Days
```

Nhưng template đang hard-code:

```properties
databaseBackupPeriodHours=24
databaseBackupRetentionDays=7
```

Nên đổi template thành:

```properties
databaseBackupPeriodHours={{databaseBackupPeriodHours}}
databaseBackupRetentionDays={{databaseBackupRetentionDays}}
```

### 12.5. `start-data-connector-jobs.sh` có thứ tự tham số Java sai

Hiện tại:

```bash
java -jar $JVM_PARAMS $JAR_MAIN $JOB_NAME >> $JOB_NAME.log 2>&1 &
```

Với Java, JVM params phải đứng trước `-jar`. Nên sửa thành:

```bash
java $JVM_PARAMS -jar "$JAR_MAIN" "$JOB_NAME" >> "$JOB_NAME.log" 2>&1 &
```

Ngoài ra lệnh kill hiện tại:

```bash
kill -15 $(pgrep -f "$JOB_NAME")
```

có thể báo lỗi nếu chưa có process. Nên dùng pattern an toàn:

```bash
PID=$(pgrep -f "$JOB_NAME" || true)
if [ -n "$PID" ]; then
  kill -15 "$PID"
fi
```

### 12.6. `setup-system-user.sh` cấp passwordless sudo toàn quyền

Script tạo:

```text
cdpsysuser ALL=(ALL) NOPASSWD:ALL
```

Điều này tiện cho vận hành nhưng rủi ro cao trong production. IT manager nên quyết định:

- Giữ cấu hình này cho dev/UAT; hoặc
- Giới hạn sudo theo command cần thiết; hoặc
- Quản lý service bằng systemd để user không cần sudo toàn quyền.

### 12.7. Nên chuyển service sang systemd cho production

Các script hiện start service bằng `nohup`. Cách này chạy được, nhưng production nên có unit systemd để:

- Auto start sau reboot.
- Restart khi service crash.
- Quản lý log bằng journald hoặc logrotate.
- Xem trạng thái bằng `systemctl status`.

## 13. Tóm tắt cho IT manager

Để triển khai ổn định, IT manager cần đảm bảo:

- Có một server Ubuntu 22.04/24.04 đủ tài nguyên.
- Source/release package được đặt đầy đủ tại `/build/cdp-instance`.
- Tất cả service Java chạy bằng `cdpsysuser`.
- Java 11, Redis, ArangoDB và Nginx được cài thành công.
- Metadata có đủ domain, SMTP, backup path và database config.
- Admin/Observer/Data Connector Jobs start thành công.
- Nginx reverse proxy chỉ expose port `80/443` ra ngoài.
- Redis, ArangoDB và các backend port không mở public.
- Backup database được kiểm tra định kỳ.
- Các issue trong phần review được xử lý trước khi production go-live.
