#!/bin/bash

set -e

echo "Installing Promtail..."

cd /tmp
wget -q https://github.com/grafana/loki/releases/latest/download/promtail-linux-amd64.zip

apt install unzip -y
unzip -o promtail-linux-amd64.zip

mv promtail-linux-amd64 /usr/local/bin/promtail
chmod +x /usr/local/bin/promtail

useradd --system --no-create-home --shell /bin/false promtail || true

mkdir -p /etc/promtail
mkdir -p /var/lib/promtail

cp config/config.yml /etc/promtail/
cp promtail.service /etc/systemd/system/

usermod -aG adm promtail

systemctl daemon-reload
systemctl enable promtail
systemctl restart promtail

echo "Promtail installed successfully"
