#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

########################################
# Add swap for t3.micro
########################################

if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
fi

swapon /swapfile || true

if ! grep -q '^/swapfile ' /etc/fstab; then
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

dnf update -y
dnf install -y wget tar git nginx

NODE_EXPORTER_VERSION="1.8.2"
PROMETHEUS_VERSION="2.53.0"

########################################
# Install Node Exporter
########################################

useradd --no-create-home --shell /sbin/nologin node_exporter || true

cd /tmp

wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

tar -xzf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

install -o node_exporter -g node_exporter -m 0755 \
  "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" \
  /usr/local/bin/node_exporter

cat >/etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=always
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

########################################
# Install Prometheus
########################################

useradd --no-create-home --shell /sbin/nologin prometheus || true

mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus

cd /tmp

wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"

tar -xzf "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"

install -o prometheus -g prometheus -m 0755 \
  "prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus" \
  /usr/local/bin/prometheus

install -o prometheus -g prometheus -m 0755 \
  "prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool" \
  /usr/local/bin/promtool

########################################
# Prometheus configuration
########################################

cat >/etc/prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - /etc/prometheus/alerts.yml

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets:
          - "localhost:9090"

  - job_name: "node-exporter"
    static_configs:
      - targets:
          - "localhost:9100"
EOF

########################################
# Prometheus alert rules
########################################

cat >/etc/prometheus/alerts.yml <<'EOF'
groups:
  - name: infrastructure-alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "CPU usage is above 80 percent"

      - alert: ServerUnavailable
        expr: up{job="node-exporter"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Node Exporter is unavailable"
EOF

chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /var/lib/prometheus

/usr/local/bin/promtool check config /etc/prometheus/prometheus.yml

cat >/etc/systemd/system/prometheus.service <<'EOF'
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus
Restart=always
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

########################################
# Start core monitoring services
########################################

systemctl daemon-reload
systemctl enable --now node_exporter
systemctl enable --now prometheus
systemctl enable --now nginx

########################################
# Install Grafana
########################################

cat >/etc/yum.repos.d/grafana.repo <<'EOF'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

dnf install -y grafana

########################################
# Provision Prometheus data source
########################################

mkdir -p /etc/grafana/provisioning/datasources

cat >/etc/grafana/provisioning/datasources/prometheus.yml <<'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: false
EOF

########################################
# Configure Nginx test page
########################################

cat >/usr/share/nginx/html/index.html <<'EOF'
<!doctype html>
<html>
<head>
  <title>Terraform GitOps Monitoring</title>
</head>
<body>
  <h1>Terraform + GitOps + Prometheus + Grafana</h1>
  <p>This server was automatically provisioned using Terraform.</p>
</body>
</html>
EOF

########################################
# Start services
########################################

systemctl daemon-reload
systemctl enable --now node_exporter
systemctl enable --now prometheus
systemctl enable --now grafana-server
systemctl enable --now nginx