# NGINX → Promtail → Loki → Grafana

## Централизованный сбор логов NGINX

Данное руководство описывает настройку централизованного сбора **access** и **error логов NGINX** с нескольких серверов с использованием:

* **Promtail** — агент сбора логов
* **Loki** — хранилище логов
* **Grafana** — визуализация и мониторинг

---

# ✅ Шаг 1 — Настройка log_format в NGINX

Открой конфигурацию nginx:

```bash
sudo nano /etc/nginx/nginx.conf
```

Внутри блока `http {}` добавь:

```nginx
log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                '$status $body_bytes_sent "$http_referer" '
                '"$http_user_agent" "$http_x_forwarded_for"';
```

---

## Настройка файлов логов

Убедись, что используется созданный формат:

```nginx
access_log /var/log/nginx/access.log main;
error_log  /var/log/nginx/error.log;
```

---

## Проверка конфигурации

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

# ✅ Шаг 2 — Проверка записи логов

Проверяем, что nginx пишет логи:

```bash
tail -f /var/log/nginx/access.log
```

Пример строки:

```
192.168.x.x - - [27/Feb/...]
```

Если логи появляются — продолжаем.

---

# ✅ Шаг 3 — Установка Promtail

Выполняется **на каждом сервере с NGINX**.

```bash
wget https://github.com/grafana/loki/releases/latest/download/promtail-linux-amd64.zip
unzip promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail
sudo chmod +x /usr/local/bin/promtail
```

---

# ✅ Шаг 4 — Создание директорий

```bash
sudo mkdir -p /etc/promtail
sudo mkdir -p /var/lib/promtail
```

---

# ✅ Шаг 5 — Конфигурация Promtail

Создай файл:

```bash
sudo nano /etc/promtail/promtail.yaml
```

---

## Конфигурация Promtail (Production)

⚠ Обязательно заменить:

* `10.13.1.155` — IP сервера Loki
* `SERVER_NAME` — имя текущего сервера

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://10.13.1.155:3100/loki/api/v1/push

scrape_configs:

- job_name: nginx_access
  static_configs:
    - targets:
        - localhost
      labels:
        job: nginx
        host: SERVER_NAME
        __path__: /var/log/nginx/access.log

  pipeline_stages:
    - regex:
        expression: '^(?P<remote_addr>\S+) \S+ \S+ \[[^\]]+\] "(?P<method>\S+) (?P<uri>\S+) \S+" (?P<status>\d{3}) (?P<body_bytes>\d+)'
    - labels:
        status:
        method:
        uri:

- job_name: nginx_error
  static_configs:
    - targets:
        - localhost
      labels:
        job: nginx_error
        host: SERVER_NAME
        __path__: /var/log/nginx/error.log
```

---

## Примеры SERVER_NAME

```
lms1
api01
web02
haproxy01
```

---

# ✅ Шаг 6 — Systemd сервис Promtail

Создай сервис:

```bash
sudo nano /etc/systemd/system/promtail.service
```

```ini
[Unit]
Description=Promtail Log Collector
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/promtail \
 -config.file=/etc/promtail/promtail.yaml

Restart=always

[Install]
WantedBy=multi-user.target
```

---

# ✅ Шаг 7 — Запуск Promtail

```bash
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable promtail
sudo systemctl start promtail
```

---

# ✅ Шаг 8 — Проверка работы

## Проверка сервиса

```bash
sudo systemctl status promtail
```

---

## Проверка получения логов в Grafana

Открыть:

```
Grafana → Explore → Loki
```

Запрос:

```logql
{job="nginx"}
```

Если отображаются логи — настройка выполнена успешно ✅

---

# 🚀 Результат

После выполнения настройки:

✅ Централизованный сбор логов NGINX
✅ Access и Error логи всех серверов
✅ HTTP статус как label
✅ Поддержка нескольких серверов
✅ Готовность к monitoring dashboard

---

# 📊 Архитектура решения

```
NGINX
   ↓
Promtail
   ↓
Loki
   ↓
Grafana
```

---


