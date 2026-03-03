#!/bin/bash

set -e

# ==============================
# CONFIG (МЕНЯЙ ТОЛЬКО ЭТО)
# ==============================

LOKI_SERVER="192.168.1.50"
LOKI_PORT="3100"

# ==============================

echo "===== Installing Promtail ====="

HOSTNAME=$(hostname)

echo "Server hostname detected: $HOSTNAME"

cd /tmp

echo "Downloading promtail..."
wget -q https://github.com/grafana/loki/releases/latest/download/promtail-linux-amd64.zip

apt update -y
apt install unzip -y

unzip -o promtail-linux-amd64.zip

mv promtail-linux-amd64 /usr/local/bin/promtail
chmod +x /usr/local/bin/promtail

echo "Creating promtail user..."
useradd --system --no-create-home --shell /bin/false promtail 2>/dev/null || true

mkdir -p /etc/promtail
mkdir -p /var/lib/promtail

echo "Creating config..."

cat <<EOF > /etc/promtail/config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://${LOKI_SERVER}:${LOKI_PORT}/loki/api/v1/push

scrape_configs:

- job_name: syslog
  static_configs:
  - targets:
      - localhost
    labels:
      job: syslog
      host: ${HOSTNAME}
      __path__: /var/log/syslog

- job_name: auth
  static_configs:
  - targets:
      - localhost
    labels:
      job: auth
      host: ${HOSTNAME}
      __path__: /var/log/auth.log

- job_name: nginx
  static_configs:
  - targets:
      - localhost
    labels:
      job: nginx
      host: ${HOSTNAME}
      __path__: /var/log/nginx/*.log
EOF

echo "Creating systemd service..."

cat <<EOF > /etc/systemd/system/promtail.service
[Unit]
Description=Promtail service
After=network.target

[Service]
User=promtail
Group=promtail
Type=simple
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Setting permissions..."
usermod -aG adm promtail || true
usermod -aG systemd-journal promtail || true

systemctl daemon-reload
systemctl enable promtail
systemctl restart promtail

echo ""
echo "===== Installation Completed ====="
echo ""
systemctl status promtail --no-pager

echo ""
echo "Test Loki connection:"
echo "curl http://${LOKI_SERVER}:${LOKI_PORT}/ready"
echo ""
echo "Check logs:"
echo "journalctl -u promtail -f"
