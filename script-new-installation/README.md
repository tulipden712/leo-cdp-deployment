
# 🧩 HƯỚNG DẪN CÀI ĐẶT LEO CDP (Triển khai 3 Node + Tùy chọn Kafka)

* **Phiên bản:** v0.9.1
* **Cập nhật:** Tháng 10 / 2025
* **Người duy trì:** Trieu — [trieu@leocdp.com](mailto:trieu@leocdp.com)
* **Môi trường:** Ubuntu Server 22.04 LTS

---

## I. TỔNG QUAN

**LEO CDP (Customer Data Platform)** là hệ thống quản lý và phân tích dữ liệu khách hàng được triển khai theo mô hình **phân tán (distributed architecture)** gồm **3 node chính**.
Ngoài ra, có thể mở rộng thêm **Apache Kafka** như một **lớp scale tùy chọn (optional scaling layer)** để xử lý **event streaming** và **real-time data pipeline**.

| Node Name                   | Vai trò          | Mô tả hoạt động chính                                         |
| --------------------------- | ---------------- | ------------------------------------------------------------- |
| **cdp-database**            | Database Node    | Chạy **ArangoDB** và các **data connector jobs**              |
| **cdp-datahub**             | DataHub Node     | Chạy **LEO Observer** và tùy chọn **Kafka event queue**       |
| **cdp-admin**               | Admin Node       | Chạy **Admin Dashboard** và **API Services**                  |
| **kafka-node** *(optional)* | Kafka Event Node | Server riêng chạy **Apache Kafka** khi hệ thống cần scale lớn |

---

## II. YÊU CẦU HỆ THỐNG

| Thành phần (Component) | Phiên bản (Version) | Cài đặt trên (Node)         |
| ---------------------- | ------------------- | --------------------------- |
| Ubuntu Server          | 22.04 LTS           | Tất cả nodes                |
| Java                   | 11                  | Tất cả nodes                |
| Redis                  | 6+                  | Tất cả nodes                |
| ArangoDB               | 3.11.14             | cdp-database                |
| Apache Kafka           | 3.9.1               | cdp-datahub hoặc kafka-node |
| Git                    | latest              | Tất cả nodes                |

---

## III. CẤU HÌNH MẠNG & HOSTNAME

Tất cả server nodes cần được khai báo trong file `/etc/hosts` để đảm bảo việc gọi nội bộ giữa các service.

Chạy lệnh sau trên **tất cả các node** (cdp-database, cdp-datahub, cdp-admin):

```bash
sudo bash script-new-installation/install-cdp-hostnames.sh

```

Kiểm tra lại:

```bash
ping -c 2 cdp-database
ping -c 2 cdp-datahub
ping -c 2 cdp-admin
```

Nếu các IP phản hồi ổn định, hệ thống mạng nội bộ đã sẵn sàng cho LEO CDP.

---

## IV. KIẾN TRÚC TRIỂN KHAI

```
          ┌──────────────────┐
          │   cdp-admin      │
          │ Admin Dashboard  │
          └────────┬─────────┘
                   │
                   │
          ┌────────▼────────┐
          │  cdp-datahub    │
          │ Observer + Kafka│
          └────────┬────────┘
                   │
                   │
          ┌────────▼────────┐
          │  cdp-database   │
          │ ArangoDB + Jobs │
          └─────────────────┘
```

*(Tùy chọn)* Khi cần mở rộng quy mô hoặc tách tải, Kafka có thể chạy trên node riêng biệt:

```
          ┌──────────────────┐
          │   kafka-node     │
          │ Kafka Broker(s)  │
          └──────────────────┘
```

---

## V. CHUẨN BỊ TRIỂN KHAI (CHO TẤT CẢ CÁC NODE)

### Bước 1: Clone mã nguồn triển khai

```bash
sudo mkdir -p /build
cd /build
sudo git clone https://github.com/trieu/leo-cdp-deployment cdp-instance
cd cdp-instance
```

### Bước 2: Tạo system user cho CDP

```bash
sudo bash setup-cdp-system-user.sh
```

Tạo user:

```
User: cdpsysuser
Home: /home/cdpsysuser
```

### Bước 3: Cấp quyền thư mục

```bash
sudo chown -R cdpsysuser:cdpsysuser /build/cdp-instance
sudo chmod -R 755 /build/cdp-instance
```

### Bước 4: Cài đặt các dependency chung

```bash
sudo bash script-new-installation/install-java.sh
sudo bash script-new-installation/install-redis.sh
```

---

## VI. CÀI ĐẶT NODE DATABASE (cdp-database)

SSH vào server database:

```bash
ssh ubuntu@cdp-database
cd /build/cdp-instance
sudo bash setup-leocdp.sh
```

Chọn **Option 1: Database Server (ArangoDB)**.

### Thực hiện:

1. **Cài đặt ArangoDB**

   ```bash
   sudo bash script-new-installation/install-database.sh
   ```

2. **Khởi tạo Database**

   ```bash
   sudo bash setup-leocdp-database.sh
   ```

   Sinh ra file metadata:

   ```
   leocdp-metadata.properties
   ```

3. **Copy metadata sang các node khác**

   ```bash
   scp /build/cdp-instance/leocdp-metadata.properties ubuntu@cdp-datahub:/build/cdp-instance/
   scp /build/cdp-instance/leocdp-metadata.properties ubuntu@cdp-admin:/build/cdp-instance/
   ```

4. **Khởi chạy Data Connector Jobs**

   ```bash
   sudo -u cdpsysuser nohup bash start-data-connector-jobs.sh >/var/log/leocdp-datajob.log 2>&1 &
   ```

---

## VII. CÀI ĐẶT NODE DATAHUB (cdp-datahub)

SSH vào server datahub:

```bash
ssh ubuntu@cdp-datahub
cd /build/cdp-instance
sudo bash setup-leocdp.sh
```

Chọn **Option 2: DataHub Server (Observer)**.

### Bước 1: Kiểm tra metadata

Đảm bảo file sau tồn tại:

```
/build/cdp-instance/leocdp-metadata.properties
```

### Bước 2 (Tùy chọn): Cài đặt Apache Kafka

Kafka có thể chạy ngay tại DataHub hoặc tách ra Kafka Node riêng.

**Cài tại DataHub Node:**

```bash
sudo bash script-new-installation/install-kafka.sh
```

**Hoặc tại Kafka Node riêng:**

```bash
ssh ubuntu@kafka-node
cd /build/cdp-instance
sudo bash script-new-installation/install-kafka.sh
```

Script này sẽ:

* Cài **Apache Kafka 3.9.1** bằng **Docker** (image chính thức từ Apache)
* Tạo các **Kafka topics** mặc định:

  ```
  kafkaTopicEvent=LeoCdpEvent
  kafkaTopicProfile=LeoCdpProfile
  ```
* Mỗi topic có mặc định **2 partitions**

**Cấu hình Kafka cho LEO CDP:**
`leocdp-metadata.properties`

Ví dụ:

```properties
kafkaBootstrapServer=localhost:9092
kafkaTopicEvent=LeoCdpEvent
kafkaTopicEventPartitions=2
kafkaTopicProfile=LeoCdpProfile
kafkaTopicProfilePartitions=2
```

### Bước 3: Khởi động LEO Observer Service

```bash
sudo -u cdpsysuser nohup bash start-observer.sh >/var/log/leocdp-observer.log 2>&1 &
```

Khi Kafka hoạt động, **Observer** sẽ tự động gửi và nhận **event stream** thông qua Kafka topics.

---

## VIII. CÀI ĐẶT NODE ADMIN (cdp-admin)

SSH vào server admin:

```bash
ssh ubuntu@cdp-admin
cd /build/cdp-instance
sudo bash setup-leocdp.sh
```

Chọn **Option 3: Admin Server (Dashboard)**.

### Bước 1: Kiểm tra metadata

```
/build/cdp-instance/leocdp-metadata.properties
```

### Bước 2: Khởi chạy Admin Service

```bash
sudo -u cdpsysuser nohup bash start-admin.sh >/var/log/leocdp-admin.log 2>&1 &
```

---

## IX. KIỂM TRA & LOG

| Node         | Log File Path                  | Nội dung chính                    |
| ------------ | ------------------------------ | --------------------------------- |
| cdp-database | `/var/log/leocdp-datajob.log`  | Data connector jobs               |
| cdp-datahub  | `/var/log/leocdp-observer.log` | Observer service & Kafka consumer |
| kafka-node   | `/var/log/leocdp-kafka.log`    | Kafka setup / broker logs         |
| cdp-admin    | `/var/log/leocdp-admin.log`    | Admin dashboard & API services    |

Kiểm tra tiến trình:

```bash
ps aux | grep leo
docker ps | grep kafka
```

---


## X. XỬ LÝ SỰ CỐ (TROUBLESHOOTING)

| Sự cố                                                    | Nguyên nhân khả dĩ                                                                                   | Cách khắc phục chi tiết                                                                                                                                                                                                                                                                                                                                                                                                                                                 |                                                                                                                                    |
| -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **Kafka không khởi chạy**                                | Port `9092` bị chiếm hoặc container Kafka gặp lỗi                                                    | Kiểm tra Kafka container bằng `docker ps -a`. Nếu container dừng, chạy `sudo docker restart kafka`. Nếu lỗi “port already in use”, kiểm tra tiến trình bằng `sudo lsof -i:9092` và dừng service chiếm port.                                                                                                                                                                                                                                                             |                                                                                                                                    |
| **Observer không đọc event từ Kafka**                    | Sai cấu hình Kafka hoặc Kafka Broker không hoạt động                                                 | Mở file `leocdp-metadata.properties` kiểm tra `kafkaBootstrapServer`. Đảm bảo có thể `telnet <Kafka-IP> 9092`. Nếu không kết nối được, kiểm tra firewall hoặc security group.                                                                                                                                                                                                                                                                                      |                                                                                                                                    |
| **Metadata file bị thiếu**                               | Chưa copy từ `cdp-database` sang các node khác                                                       | Chạy lệnh copy lại: <br>`scp /build/cdp-instance/leocdp-metadata.properties ubuntu@cdp-datahub:/build/cdp-instance/`<br>`scp /build/cdp-instance/leocdp-metadata.properties ubuntu@cdp-admin:/build/cdp-instance/`                                                                                                                                                                                                                                              |                                                                                                                                    |
| **Redis không kết nối được**                             | Redis service bị stop hoặc chưa enable                                                               | Kiểm tra trạng thái: `sudo systemctl status redis`. Nếu không chạy, khởi động lại: `sudo systemctl restart redis`. Đảm bảo port `6379` mở.                                                                                                                                                                                                                                                                                                                              |                                                                                                                                    |
| **ArangoDB không connect**                               | Sai cấu hình giữa `configs/PRO-database-configs.json` và file hệ thống `/etc/arangodb3/arangod.conf` | Mở cả hai file để đối chiếu: <br>• Trong `arangod.conf`, kiểm tra dòng `endpoint = tcp://0.0.0.0:8529` (cho phép kết nối từ các IP khác). <br>• Trong `PRO-database-configs.json`, đảm bảo trường `"database_url"` hoặc `"arangodb_url"` trỏ đúng IP:Port (ví dụ `"tcp://cdp-database:8529"`). <br>• Dùng `nc -zv cdp-database 8529` để kiểm tra kết nối từ các node khác.                                                                                              |                                                                                                                                    |
| **cdp-database đầy disk (disk full)**                    | Dữ liệu ArangoDB hoặc log chiếm toàn bộ dung lượng ổ đĩa                                             | **Tùy chọn khắc phục:**<br>1. **Tăng dung lượng ổ đĩa:** nếu là cloud VM → mở rộng volume rồi `resize2fs /dev/<disk>`. <br>2. **Gắn thêm ổ mới:** mount vào `/var/lib/arangodb3` hoặc `/data`. Cập nhật `arangod.conf` để ArangoDB lưu dữ liệu sang ổ mới. <br>3. **Xóa log cũ:** xóa các file log không cần thiết trong `/var/log/` hoặc `/build/cdp-instance/logs/`. <br>4. **Tạm dừng jobs ghi dữ liệu lớn:** dừng `start-data-connector-jobs.sh` trước khi dọn dẹp. |                                                                                                                                    |
| **Admin Dashboard không truy cập được (HTTP 502 / 504)** | Service không khởi động hoặc lỗi cấu hình reverse proxy                                              | Kiểm tra tiến trình: `ps aux                                                                                                                                                                                                                                                                                                                                                                                                                                            | grep admin`. Nếu không có, khởi động lại: `sudo -u cdpsysuser nohup bash start-admin.sh &`. Kiểm tra port (thường 8080 hoặc 8000). |
| **Không SSH được giữa các node**                         | Thiếu khai báo hostname trong `/etc/hosts`                                                           | Kiểm tra lại `/etc/hosts` trên tất cả các server. Đảm bảo có đoạn: <br>`\n# BEGIN CDP hosts\n172.20.172.36 cdp-database\n172.20.172.35 cdp-datahub\n172.20.172.37 cdp-admin cdp-redis\n# END CDP hosts\n`                                                                                                                                                                                                                                                               |                                                                                                                                    |


---

## XI. TỔNG KẾT TRIỂN KHAI

| Node         | Dịch vụ chính               | Lệnh khởi chạy                           |
| ------------ | --------------------------- | ---------------------------------------- |
| cdp-database | ArangoDB + Data Jobs        | `start-data-connector-jobs.sh`           |
| cdp-datahub  | Observer (+ Kafka optional) | `start-observer.sh` + `install-kafka.sh` |
| cdp-admin    | Admin Dashboard             | `start-admin.sh`                         |
| kafka-node   | Kafka Broker (optional)     | `install-kafka.sh`                       |

Tất cả các node dùng chung metadata file:

```
/build/cdp-instance/leocdp-metadata.properties
```

---

## XII. BẢO TRÌ HỆ THỐNG (MAINTENANCE)

**Dừng toàn bộ services:**

```bash
sudo bash stop-server.sh
```

**Cập nhật code mới nhất:**

```bash
cd /build/cdp-instance
sudo git pull origin main
```

**Khởi động lại Kafka (nếu có):**

```bash
sudo docker restart kafka
```

