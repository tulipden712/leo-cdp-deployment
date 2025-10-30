#!/usr/bin/env bash
set -euo pipefail

KAFKA_VERSION="3.9.1"
KAFKA_CONTAINER_NAME="leocdp-kafka"
KAFKA_IMAGE="apache/kafka:${KAFKA_VERSION}"
KAFKA_BOOTSTRAP="localhost:9092"

TOPIC_EVENT="LeoCdpEvent"
TOPIC_PROFILE="LeoCdpProfile"
PARTITIONS=2

echo "----------------------------------------------------------"
echo "[INFO] Setting up Apache Kafka ${KAFKA_VERSION} for LEO CDP..."
echo "----------------------------------------------------------"

# --- Check Docker availability ---
if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] Docker not found. Please install Docker first."
  exit 1
fi

# --- Pull Kafka image ---
echo "[STEP] Pulling Apache Kafka Docker image (${KAFKA_IMAGE})..."
docker pull "${KAFKA_IMAGE}"

# --- Stop existing container if running ---
if docker ps -a --format '{{.Names}}' | grep -q "^${KAFKA_CONTAINER_NAME}$"; then
  echo "[STEP] Removing existing Kafka container '${KAFKA_CONTAINER_NAME}'..."
  docker rm -f "${KAFKA_CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

# --- Run Kafka in KRaft mode ---
echo "[STEP] Starting Kafka container '${KAFKA_CONTAINER_NAME}'..."
docker run -d \
  --name "${KAFKA_CONTAINER_NAME}" \
  -p 9092:9092 \
  -e KAFKA_ENABLE_KRAFT=yes \
  -e KAFKA_CFG_NODE_ID=1 \
  -e KAFKA_CFG_PROCESS_ROLES=broker,controller \
  -e KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 \
  -e KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://${KAFKA_BOOTSTRAP} \
  -e KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT \
  -e KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@localhost:9093 \
  -e KAFKA_CFG_LOG_DIRS=/tmp/kraft-combined-logs \
  -e KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=false \
  "${KAFKA_IMAGE}" >/dev/null

echo "[WAIT] Waiting for Kafka to start (10s)..."
sleep 10

# --- Check container health ---
if ! docker ps --format '{{.Names}}' | grep -q "${KAFKA_CONTAINER_NAME}"; then
  echo "[ERROR] Kafka container failed to start."
  docker logs "${KAFKA_CONTAINER_NAME}" || true
  exit 1
fi

echo "[SUCCESS] Kafka is running at ${KAFKA_BOOTSTRAP}"

# --- Create required topics ---
create_topic() {
  local topic_name="$1"
  local partitions="$2"

  echo "[STEP] Creating topic '${topic_name}' with ${partitions} partitions..."
  docker exec "${KAFKA_CONTAINER_NAME}" kafka-topics.sh \
    --create \
    --topic "${topic_name}" \
    --bootstrap-server "${KAFKA_BOOTSTRAP}" \
    --partitions "${partitions}" \
    --replication-factor 1 || {
      echo "[WARN] Topic '${topic_name}' may already exist."
    }
}

create_topic "${TOPIC_EVENT}" "${PARTITIONS}"
create_topic "${TOPIC_PROFILE}" "${PARTITIONS}"

echo "----------------------------------------------------------"
echo "[INFO] ✅ Kafka setup complete."
echo "[INFO] Broker: ${KAFKA_BOOTSTRAP}"
echo "[INFO] Topics:"
echo "       - ${TOPIC_EVENT} (${PARTITIONS} partitions)"
echo "       - ${TOPIC_PROFILE} (${PARTITIONS} partitions)"
echo "----------------------------------------------------------"

# --- Show topics summary ---
docker exec "${KAFKA_CONTAINER_NAME}" kafka-topics.sh \
  --list --bootstrap-server "${KAFKA_BOOTSTRAP}"
