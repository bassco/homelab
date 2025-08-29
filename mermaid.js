flowchart TB
    %% Nodes
    subgraph ProxyNetwork["Docker Network: proxy"]
        direction TB

        nginx["NGINX Reverse Proxy<br>Ports: 80/443<br>Volumes:<br>- ./nginx/conf.d<br>- ./nginx/certs<br>- ./nginx/logs"]
        grafana["Grafana<br>Port: 3000<br>Volumes:<br>- ./grafana"]
        prometheus["Prometheus<br>Port: 9090<br>Volumes:<br>- ./prometheus/prometheus.yml"]
        homeassistant["Home Assistant<br>Port: 8123"]
        unifi["UniFi Controller<br>Port: 8443"]
        otel["OpenTelemetry Collector<br>Port: 9464<br>Volumes:<br>- ./otel-collector"]
        nginx_exporter["NGINX Prometheus Exporter<br>Port: 9113"]
        unpoller["Unpoller<br>Port: 9130"]
    end

    %% Connections
    nginx -->|"HTTPS proxy"| grafana
    nginx -->|"HTTPS proxy"| prometheus
    nginx -->|"HTTPS proxy"| homeassistant
    nginx -->|"HTTPS proxy"| unifi

    prometheus -->|"scrapes"| nginx_exporter
    prometheus -->|"scrapes"| unpoller
    prometheus -->|"scrapes"| otel

    homeassistant -->|"OTLP metrics"| otel
    unifi -->|"OTLP metrics"| otel
    nginx_exporter -->|"OTLP metrics (optional)"| otel

    grafana -->|"datasource: Prometheus"| prometheus

    %% Styling
    classDef proxy fill:#dbeafe,stroke:#2563eb,stroke-width:2px,color:#1e3a8a;
    classDef service fill:#e0f2f1,stroke:#00695c,stroke-width:2px,color:#004d40;
    classDef exporter fill:#fff3e0,stroke:#fb8c00,stroke-width:2px,color:#e65100;
    classDef collector fill:#f3e5f5,stroke:#8e24aa,stroke-width:2px,color:#4a148c;

    class nginx,homeassistant,unifi service;
    class grafana,prometheus service;
    class nginx_exporter,unpoller exporter;
    class otel collector;
    class ProxyNetwork proxy;

