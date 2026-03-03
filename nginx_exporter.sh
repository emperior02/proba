# КАК ИСПОЛЗОВАТЬ
# chmod +x nginx_exporter.sh
# sudo ./nginx_exporter.sh
# ==============================
#!/bin/bash

set -e

EXPORTER_PORT="9113"
NGINX_STATUS_PORT="8080"

echo "===== Installing Nginx Prometheus Exporter ====="

apt update -y
apt install -y curl wget tar

# Получаем последнюю версию
VERSION=$(curl -s https://api.github.com/repos/nginx/nginx-prometheus-exporter/releases/latest | grep tag_name | cut -d '"' -f 4)

if [ -z "$VERSION" ]; then
  echo "Failed to get latest version"
  exit 1
fi

echo "Latest version: $VERSION"

FILE="nginx-prometheus-exporter_${VERSION#v}_linux_amd64.tar.gz"

cd /tmp

echo "Downloading $FILE ..."
wget https://github.com/nginx/nginx-prometheus-exporter/releases/download/$VERSION/$FILE

tar -xzf $FILE
mv nginx-prometheus-exporter /usr/local/bin/
chmod +x /usr/local/bin/nginx-prometheus-exporter

# Создаем stub_status если нет
cat <<EOF > /etc/nginx/conf.d/stub_status.conf
server {
    listen ${NGINX_STATUS_PORT};
    server_name localhost;

    location /nginx_status {
        stub_status;
        allow 127.0.0.1;
        deny all;
    }
}
EOF

nginx -t
systemctl reload nginx

# Создаем пользователя
useradd --system --no-create-home --shell /bin/false nginx_exporter 2>/dev/null || true

# Systemd сервис
cat <<EOF > /etc/systemd/system/nginx-exporter.service
[Unit]
Description=Nginx Prometheus Exporter
After=network.target

[Service]
User=nginx_exporter
Group=nginx_exporter
ExecStart=/usr/local/bin/nginx-prometheus-exporter \
  --nginx.scrape-uri=http://127.0.0.1:${NGINX_STATUS_PORT}/nginx_status \
  --web.listen-address=:${EXPORTER_PORT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable nginx-exporter
systemctl restart nginx-exporter

echo ""
echo "===== Installation Completed ====="
systemctl status nginx-exporter --no-pager
echo ""
echo "Test:"
echo "curl http://127.0.0.1:${EXPORTER_PORT}/metrics"
