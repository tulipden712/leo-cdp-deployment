# LEO CDP Deployment

**LEO Customer Data Platform (CDP)** — *Free Edition for on-premise or cloud environments.*

## Overview

![cdp-admin-screenshot](docs/cdp-admin-screenshot.png "cdp-admin-screenshot")

LEO CDP Free Edition provides a complete environment to manage customer data, including:

* Admin Dashboard for system management
* Data Hub for observer access
* LEO Bot for FAQs and content creation
* Database backup and retention management
* Messaging through Kafka or local queues
* Pre-packaged JAR files for core services and jobs

---

## 📁 Repository Structure


```
.
├── airflow-dags/                     # Example Airflow DAGs for data pipelines
├── chrome-ext/                       # Chrome extensions for tracking and event testing
├── configs/                          # Configuration of LEO CDP services
├── data/                             # Local or exported data files
├── deps/                             # Library dependencies
├── devops-script/                    # Scripts for maintenance and automation
├── docs/                             # Documentation and diagrams
├── public/                           # Static resources for Admin UI
├── resources/                        # Additional assets or sample files
├── script-new-installation/          # Main installation scripts for system setup
│   ├── install-certbot.sh            # Install Let's Encrypt SSL certs
│   ├── install-database.sh           # Install ArangoDB 3.11+
│   ├── install-java.sh               # Install Amazon Corretto / OpenJDK 11
│   ├── install-nginx.sh              # Install stable Nginx reverse proxy
│   └── install-redis.sh              # Install Redis for caching and job state
├── static-data/                      # Example static data sets
│
├── leo-data-processing-starter-v_0.9.0.jar
├── leo-main-starter-v_0.9.0.jar
├── leo-observer-starter-v_0.9.0.jar
├── leo-scheduler-starter-v_0.9.0.jar
│
├── leocdp-metadata.properties        # Active runtime metadata config
├── leocdp-metadata-tpl.properties    # Template metadata configuration
│
├── run-database-backup-restore.sh    # Backup and restore ArangoDB
├── run-database-upgrade.sh           # Schema upgrade utility
│
├── setup-leocdp-database.sh          # Initialize CDP database
├── setup-leocdp-metadata.sh          # Generate metadata configuration file
│
├── start-admin.sh                    # Start Admin service
├── start-observer.sh                 # Start Data Hub / Observer service
├── start-data-connector-jobs.sh      # Start background ETL/sync jobs
├── stop-server.sh                    # Stop all running CDP services
│
└── README.md
```

---

## ⚙️ System Requirements

| Component     | Requirement                              |
| ------------- | ---------------------------------------- |
| OS            | Ubuntu 22.04 LTS or higher               |
| Java          | Amazon Corretto 11 *(required)*         |
| Redis         | Redis 6+ *(required)*                    |
| Database      | ArangoDB 3.11+                           |
| Reverse Proxy | Nginx (latest stable)                    |
| Shell         | Bash 5.0+                                |
| Access        | Dedicated non-root user for all services |

---

## 🧩 Installation Workflow

All installation scripts are located in:
`script-new-installation/`

Run **each step in order** depending on the deployment context (fresh install vs existing environment).

---

### 1️⃣ Create Dedicated System User

All LEO CDP services must run under a **non-root user** for security and process isolation.

```bash
sudo useradd cdpsysuser -s /bin/bash -p '*'
sudo passwd -d cdpsysuser
sudo usermod -aG sudo cdpsysuser
echo 'cdpsysuser ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers >/dev/null
```

---

### 2️⃣ Configure SSH Access for the User

```bash
sudo su cdpsysuser
sudo mkdir -p /home/cdpsysuser
cd /home/cdpsysuser
sudo chown -R cdpsysuser:cdpsysuser /home/cdpsysuser
mkdir .ssh
nano .ssh/authorized_keys
```

> Paste your **SSH public key** here to enable passwordless access.
> This user will be used for deployment, upgrades, and service management.

---

### 3️⃣ Install Core Services and Dependencies

All commands should be executed as **root** or with `sudo`, before switching to `cdpsysuser`.

```bash
cd script-new-installation
sudo bash install-java.sh        # Install Java (required)
sudo bash install-redis.sh       # Install Redis (required)
sudo bash install-database.sh    # Install ArangoDB
sudo bash install-nginx.sh       # Install Nginx (reverse proxy)
sudo bash install-certbot.sh     # Install Let's Encrypt SSL (optional)
```

---

### 4️⃣ Switch to the CDP System User

```bash
sudo su - cdpsysuser
cd /path/to/LEO-CDP-FREE-EDITION
```

Generate configuration metadata:

```bash
bash setup-leocdp-metadata.sh
```

Initialize the database:

```bash
bash setup-leocdp-database.sh
```

---

### 5️⃣ Start CDP Services

Run the services in sequence under `cdpsysuser`:

```bash
bash start-admin.sh
bash start-observer.sh
bash start-data-connector-jobs.sh
```

To stop all services:

```bash
bash stop-server.sh
```

---

## 🧰 Maintenance Operations

**Backup / Restore Database**

```bash
bash run-database-backup-restore.sh
```

**Upgrade Database Schema**

```bash
bash run-database-upgrade.sh
```

**Logs**

* All upgrade logs → `upgrade-leocdp.log`
* Individual service logs are created per JAR when started

---

## 🔐 Security & Hardening

* Never run CDP JARs as `root`
* Use `ufw` or a cloud firewall to restrict open ports
* Ensure SSL termination (Certbot or reverse proxy)
* Keep Redis and ArangoDB access limited to internal network
* Rotate SSH keys and database passwords periodically

---

## 🌐 References

* **Framework:** [https://github.com/trieu/leo-cdp-framework](https://github.com/trieu/leo-cdp-framework)
* **LEO Bot (AI Assistant):** [https://github.com/trieu/leo-bot](https://github.com/trieu/leo-bot)

---

## ✅ Quick Deployment Summary

For a **fresh Ubuntu 22.04** server:

```bash
# 1. Create dedicated system user
sudo useradd cdpsysuser -s /bin/bash -p '*'
sudo passwd -d cdpsysuser
sudo usermod -aG sudo cdpsysuser
echo 'cdpsysuser ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers >/dev/null

# 2. Install dependencies
cd script-new-installation
sudo bash install-java.sh
sudo bash install-redis.sh
sudo bash install-database.sh
sudo bash install-nginx.sh

# 3. Switch to CDP user and configure
sudo su - cdpsysuser
cd /path/to/LEO-CDP-FREE-EDITION
bash setup-leocdp-metadata.sh
bash setup-leocdp-database.sh

# 4. Start services
bash start-admin.sh
bash start-observer.sh
bash start-data-connector-jobs.sh
```

Access the **Admin Dashboard** at the configured domain.
