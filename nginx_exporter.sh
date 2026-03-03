# КАК ИСПОЛЗОВАТЬ
# chmod +x nginx_exporter.sh
# sudo ./nginx_exporter.sh
# ==============================
#!/bin/bash

set -e

# ==============================
# CONFIG (МЕНЯЙ ТОЛЬКО ЭТО)
# ==============================

NGINX_STATUS_PORT="8080"
EXPORTER_PORT="9113"

# ==============================

echo "===== Installing Nginx Prometheus Exporter ====="

echo "Checking nginx..."

if ! command -v nginx >/dev/null 2>&1; then
    echo "ERROR: nginx not installed"
    exit 1
fi

echo "Creating nginx stub_status config..."

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

echo "Downloading exporter..."

cd /tmp
wget -q https://github.com/nginxinc/nginx-prometheus-exporter/releases/latest/download/nginx-prometheus-exporter_1.1.0_linux_amd64.tar.gz

tar -xzf nginx-prometheus-exporter_1.1.0_linux_amd64.tar.gz
mv nginx-prometheus-exporter /usr/local/bin/
chmod +x /usr/local/bin/nginx-prometheus-exporter

echo "Creating exporter user..."
useradd --system --no-create-home --shell /bin/false nginx_exporter 2>/dev/null || true

echo "Creating systemd service..."

cat <<EOF > /etc/systemd/system/nginx-exporter.service
[Unit]
Description=Nginx Prometheus Exporter
After=network.target

[Service]
User=nginx_exporter
Group=nginx_exporter
Type=simple
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
echo ""

echo "Checking exporter status..."
systemctl status nginx-exporter --no-pager

echo ""
echo "Test locally:"
echo "curl http://127.0.0.1:${EXPORTER_PORT}/metrics"
echo ""
