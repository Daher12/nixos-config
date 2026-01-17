{
  config,
  pkgs,
  lib,
  ...
}:

# Monitoring Stack
#
# Components:
#   - Prometheus :9090 (localhost)
#   - Alertmanager :9093 (localhost)
#   - Node Exporter :9100 (localhost)
#   - Grafana :3001 (localhost, via Caddy)
#   - Intel GPU metrics (custom script)

let
  # Alert rules configuration
  alertRulesFile = pkgs.writeText "alert-rules.yml" (
    builtins.toJSON {
      groups = [
        {
          name = "system_alerts";
          interval = "60s";
          rules = [
            {
              alert = "HighCPUUsage";
              expr = ''100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90'';
              for = "5m";
              labels = {
                severity = "warning";
              };
              annotations = {
                summary = "CPU > 90% for 5m";
              };
            }
            {
              alert = "HighMemoryUsage";
              expr = "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 90";
              for = "5m";
              labels = {
                severity = "warning";
              };
              annotations = {
                summary = "Memory > 90% for 5m";
              };
            }
            {
              alert = "LowDiskSpace";
              expr = ''100 - ((node_filesystem_avail_bytes{mountpoint="/mnt/storage"} * 100) / node_filesystem_size_bytes{mountpoint="/mnt/storage"}) > 90'';
              for = "10m";
              labels = {
                severity = "critical";
              };
              annotations = {
                summary = "Storage < 10% free";
              };
            }
            {
              alert = "LowRootDiskSpace";
              expr = ''100 - ((node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"}) > 85'';
              for = "10m";
              labels = {
                severity = "warning";
              };
              annotations = {
                summary = "Root < 15% free";
              };
            }
            {
              alert = "ContainerDown";
              expr = ''up{job="cadvisor"} == 0'';
              for = "2m";
              labels = {
                severity = "critical";
              };
              annotations = {
                summary = "cAdvisor down";
              };
            }
            {
              alert = "HighIOWait";
              expr = ''avg(irate(node_cpu_seconds_total{mode="iowait"}[5m])) * 100 > 50'';
              for = "5m";
              labels = {
                severity = "warning";
              };
              annotations = {
                summary = "I/O wait > 50%";
              };
            }
          ];
        }
      ];
    }
  );

  # Intel GPU Metrics Script (Text Parsing Mode)
  gpuMetricsScript = pkgs.writeShellScript "collect-gpu-metrics" ''
    export LC_ALL=C
    TMPFILE=/var/lib/prometheus-node-exporter/intel_gpu.prom.tmp
    OUTFILE=/var/lib/prometheus-node-exporter/intel_gpu.prom

    # Capture ~4 seconds of output for smoothing
    OUTPUT=$(${pkgs.coreutils}/bin/timeout 4s ${pkgs.intel-gpu-tools}/bin/intel_gpu_top -s 1000 | tr -d '\r')

    echo "$OUTPUT" | ${pkgs.gawk}/bin/awk '
      BEGIN { render_sum=0; video_sum=0; enhance_sum=0; samples=0 }
      /Freq/ || /req/ || /^$/ { next }
      $1 ~ /^[0-9.]+$/ && NF >= 13 {
        render_sum  += $7; video_sum += $11; enhance_sum += $13; samples++
      }
      END {
        if (samples > 0) {
          render  = render_sum / samples
          video   = video_sum / samples
          enhance = enhance_sum / samples
          busy = render
          if (video > busy) busy = video
          if (enhance > busy) busy = enhance
        } else {
          render = 0; video = 0; enhance = 0; busy = 0
        }
        printf "intel_gpu_engine_busy_percent{engine=\"render\"} %.2f\n", render
        printf "intel_gpu_engine_busy_percent{engine=\"video\"} %.2f\n", video
        printf "intel_gpu_engine_busy_percent{engine=\"videoenhance\"} %.2f\n", enhance
        printf "intel_gpu_busy_percent %.2f\n", busy
        print "intel_gpu_build_info{version=\"${pkgs.intel-gpu-tools.version}\"} 1"
      }
    ' > "$TMPFILE"

    if [ -s "$TMPFILE" ]; then
      mv "$TMPFILE" "$OUTFILE"
      chmod 644 "$OUTFILE"
    fi
  '';
in
{
  # --- Secrets Definition ---
  sops.secrets = {
    "grafana_admin_password" = {
      owner = config.systemd.services.grafana.serviceConfig.User or "grafana";
      restartUnits = [ "grafana.service" ];
    };
    "ntfy_url" = {
      # Accessed via LoadCredential, no specific owner needed
      restartUnits = [ "alertmanager-ntfy-bridge.service" ];
    };
  };

  # --- Prometheus ---
  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "127.0.0.1";
    retentionTime = "30d";
    extraFlags = [
      "--storage.tsdb.wal-compression"
      "--storage.tsdb.min-block-duration=2h"
      "--storage.tsdb.max-block-duration=2h"
    ];
    globalConfig = {
      scrape_interval = "30s";
      evaluation_interval = "30s";
      external_labels = {
        monitor = "nix-media";
        environment = "production";
      };
    };

    ruleFiles = [ alertRulesFile ];
    alertmanagers = [
      {
        static_configs = [ { targets = [ "127.0.0.1:9093" ]; } ];
      }
    ];
    scrapeConfigs = [
      {
        job_name = "node";
        scrape_interval = "30s";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
            labels = {
              instance = "nix-media";
            };
          }
        ];
      }
      {
        job_name = "cadvisor";
        scrape_interval = "60s";
        static_configs = [
          {
            targets = [ "127.0.0.1:8080" ];
            labels = {
              instance = "nix-media";
            };
          }
        ];
      }
      {
        job_name = "docker";
        scrape_interval = "120s";
        static_configs = [
          {
            targets = [ "127.0.0.1:9323" ];
            labels = {
              instance = "nix-media";
            };
          }
        ];
      }
    ];
    exporters.node = {
      enable = true;
      port = 9100;
      enabledCollectors = [
        "cpu"
        "diskstats"
        "filesystem"
        "loadavg"
        "meminfo"
        "netdev"
        "stat"
        "systemd"
        "textfile"
        "uname"
        "xfs"
      ];
      extraFlags = [
        "--collector.textfile.directory=/var/lib/prometheus-node-exporter"
        "--collector.disable-defaults"
      ];
    };
  };

  # --- Alertmanager ---
  services.prometheus.alertmanager = {
    enable = true;
    port = 9093;
    listenAddress = "127.0.0.1";
    configuration = {
      global = {
        resolve_timeout = "5m";
      };
      route = {
        receiver = "ntfy";
        group_by = [
          "alertname"
          "severity"
        ];
        group_wait = "30s";
        group_interval = "5m";
        repeat_interval = "4h";
        routes = [
          {
            match = {
              severity = "critical";
            };
            receiver = "ntfy";
            repeat_interval = "1h";
          }
        ];
      };
      receivers = [
        {
          name = "ntfy";
          webhook_configs = [
            {
              url = "http://127.0.0.1:9095/alert";
              send_resolved = true;
            }
          ];
        }
      ];
    };
  };

  # --- Webhook bridge: Alertmanager -> ntfy ---
  systemd.services.alertmanager-ntfy-bridge = {
    description = "Alertmanager to ntfy webhook bridge";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      DynamicUser = true;
      MemoryMax = "64M";
      # Securely load the URL secret
      LoadCredential = [ "ntfy_url:${config.sops.secrets.ntfy_url.path}" ];
    };

    script = ''
      ${pkgs.python3}/bin/python3 << 'EOF'
      import http.server
      import json
      import urllib.request
      import os
      import sys

      # Load Secret from Systemd Credential
      try:
          # Use double quotes to avoid Nix single-quote escape issues
          cred_path = os.path.join(os.environ.get('CREDENTIALS_DIRECTORY', ""), 'ntfy_url')
          with open(cred_path, 'r') as f:
              NTFY_URL = f.read().strip()
      except Exception as e:
          print(f"Failed to load ntfy_url secret: {e}", file=sys.stderr)
          sys.exit(1)

      class AlertHandler(http.server.BaseHTTPRequestHandler):
          def do_POST(self):
              length = int(self.headers.get('Content-Length', 0))
              body = json.loads(self.rfile.read(length)) if length else {}
              
              for alert in body.get('alerts', []):
                  status = alert.get('status', 'unknown')
                  labels = alert.get('labels', {})
                  annotations = alert.get('annotations', {})
                  
                  severity = labels.get('severity', 'warning')
                  alertname = labels.get('alertname', 'Alert')
                  summary = annotations.get('summary', 'No details')
                  
                  priority = {'critical': 'urgent', 'warning': 'high'}.get(severity, 'default')
                  
                  if status == 'resolved':
                      tags = 'white_check_mark,resolved'
                      title = f"Resolved: {alertname}"
                  else:
                      tags = 'rotating_light,warning' if severity == 'warning' else 'fire,critical'
                      title = f"Alert: {alertname}"
                  
                  req = urllib.request.Request(NTFY_URL, data=summary.encode())
                  req.add_header('Title', title)
                  req.add_header('Priority', priority)
                  req.add_header('Tags', tags)
                  
                  try:
                      urllib.request.urlopen(req, timeout=10)
                  except Exception as e:
                      print(f"Failed to send to ntfy: {e}")
              
              self.send_response(200)
              self.end_headers()
          
          def log_message(self, format, *args):
              pass

      server = http.server.HTTPServer(('127.0.0.1', 9095), AlertHandler)
      print("Alertmanager-ntfy bridge listening on :9095")
      server.serve_forever()
      EOF
    '';
  };

  # --- Resource limits ---
  systemd.services.prometheus.serviceConfig = {
    MemoryMax = "512M";
    MemoryHigh = "384M";
    CPUQuota = "50%";
    CPUWeight = 100;
    IOWeight = 100;
    TasksMax = 512;
    Nice = 10;
  };
  systemd.services.prometheus-node-exporter.serviceConfig = {
    MemoryMax = "128M";
    MemoryHigh = "96M";
    CPUQuota = "20%";
    CPUWeight = 50;
    TasksMax = 64;
    Nice = 15;
  };
  systemd.services.alertmanager.serviceConfig = {
    MemoryMax = "128M";
    CPUQuota = "10%";
    Nice = 10;
  };

  # --- Intel GPU metrics setup ---
  systemd.tmpfiles.rules = [
    "d /var/lib/prometheus-node-exporter 0755 prometheus prometheus - -"
  ];
  systemd.services.intel-gpu-metrics = {
    description = "Intel GPU Metrics Collector";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      TimeoutStartSec = "8s";
      MemoryMax = "32M";
      CPUQuota = "10%";
      Nice = 19;
      ExecStart = "${gpuMetricsScript}";
    };
  };
  systemd.timers.intel-gpu-metrics = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10s";
      OnUnitActiveSec = "30s";
    };
  };

  # --- Grafana ---
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_port = 3001;
        http_addr = "127.0.0.1";
        root_url = "%(protocol)s://%(domain)s/grafana";
        serve_from_sub_path = true;
        enable_gzip = true;
      };
      security = {
        admin_user = "admin";
        # Password handled via file provisioning below
        allow_embedding = false;
        cookie_secure = true;
        cookie_samesite = "lax";
        disable_gravatar = true;
      };
      users = {
        allow_sign_up = false;
        default_theme = "dark";
      };
      "auth.anonymous" = {
        enabled = true;
        org_name = "Main Org.";
        org_role = "Viewer";
      };
      dashboards.default_home_dashboard_path = "/etc/grafana/dashboards/system-overview.json";
    };

    # Provision Admin Password from Secret
    security.adminPasswordFile = config.sops.secrets.grafana_admin_password.path;

    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:9090";
          isDefault = true;
          uid = "prometheus-ds";
        }
      ];
      dashboards.settings.providers = [
        {
          name = "default";
          type = "file";
          disableDeletion = false;
          updateIntervalSeconds = 10;
          allowUiUpdates = true;
          options.path = "/etc/grafana/dashboards";
        }
      ];
    };
  };
  systemd.services.grafana.serviceConfig = {
    MemoryMax = "384M";
    MemoryHigh = "320M";
    CPUQuota = "30%";
    CPUWeight = 100;
    TasksMax = 256;
    Nice = 5;
  };

  # --- Dashboard ---
  environment.etc."grafana/dashboards/system-overview.json".text = builtins.toJSON {
    title = "NixOS Media Server";
    uid = "nixos-overview";
    tags = [ "nixos" ];
    timezone = "browser";
    schemaVersion = 38;
    refresh = "1m";
    time = {
      from = "now-6h";
      to = "now";
    };
    panels = [
      {
        id = 1;
        gridPos = {
          x = 0;
          y = 0;
          w = 12;
          h = 8;
        };
        type = "timeseries";
        title = "CPU Usage";
        targets = [
          {
            expr = ''100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'';
            legendFormat = "CPU Usage";
          }
        ];
        fieldConfig.defaults = {
          unit = "percent";
          min = 0;
          max = 100;
          custom.lineWidth = 2;
          thresholds = {
            mode = "absolute";
            steps = [
              {
                value = 0;
                color = "green";
              }
              {
                value = 70;
                color = "yellow";
              }
              {
                value = 90;
                color = "red";
              }
            ];
          };
        };
      }
      {
        id = 2;
        gridPos = {
          x = 12;
          y = 0;
          w = 12;
          h = 8;
        };
        type = "timeseries";
        title = "Memory Usage";
        targets = [
          {
            expr = "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))";
            legendFormat = "RAM Used";
          }
        ];
        fieldConfig.defaults = {
          unit = "percent";
          min = 0;
          max = 100;
          custom.lineWidth = 2;
          thresholds = {
            mode = "absolute";
            steps = [
              {
                value = 0;
                color = "green";
              }
              {
                value = 70;
                color = "yellow";
              }
              {
                value = 90;
                color = "red";
              }
            ];
          };
        };
      }
      {
        id = 3;
        gridPos = {
          x = 0;
          y = 8;
          w = 12;
          h = 8;
        };
        type = "timeseries";
        title = "Storage Usage";
        targets = [
          {
            expr = ''100 - ((node_filesystem_avail_bytes{mountpoint="/mnt/storage"} * 100) / node_filesystem_size_bytes{mountpoint="/mnt/storage"})'';
            legendFormat = "Storage Used";
          }
        ];
        fieldConfig.defaults = {
          unit = "percent";
          min = 0;
          max = 100;
          custom.lineWidth = 2;
          thresholds = {
            mode = "absolute";
            steps = [
              {
                value = 0;
                color = "green";
              }
              {
                value = 80;
                color = "yellow";
              }
              {
                value = 90;
                color = "red";
              }
            ];
          };
        };
      }
      {
        id = 4;
        gridPos = {
          x = 12;
          y = 8;
          w = 12;
          h = 8;
        };
        type = "timeseries";
        title = "Network Traffic";
        targets = [
          {
            expr = ''irate(node_network_receive_bytes_total{device="enp1s0"}[5m])'';
            legendFormat = "RX";
          }
          {
            expr = ''irate(node_network_transmit_bytes_total{device="enp1s0"}[5m])'';
            legendFormat = "TX";
          }
        ];
        fieldConfig.defaults = {
          unit = "Bps";
          custom.lineWidth = 2;
        };
      }
      {
        id = 5;
        gridPos = {
          x = 0;
          y = 16;
          w = 12;
          h = 8;
        };
        type = "timeseries";
        title = "Container CPU";
        targets = [
          {
            expr = ''rate(container_cpu_usage_seconds_total{name=~"jellyfin|audiobookshelf"}[5m]) * 100'';
            legendFormat = "{{name}}";
          }
        ];
        fieldConfig.defaults = {
          unit = "percent";
          min = 0;
          custom.lineWidth = 2;
        };
      }
      {
        id = 6;
        gridPos = {
          x = 12;
          y = 16;
          w = 12;
          h = 8;
        };
        type = "timeseries";
        title = "Container Memory";
        targets = [
          {
            expr = ''container_memory_usage_bytes{name=~"jellyfin|audiobookshelf"}'';
            legendFormat = "{{name}}";
          }
        ];
        fieldConfig.defaults = {
          unit = "bytes";
          custom.lineWidth = 2;
        };
      }
      {
        id = 8;
        gridPos = {
          x = 0;
          y = 24;
          w = 12;
          h = 8;
        };
        type = "timeseries";
        title = "Intel GPU (N100)";
        targets = [
          {
            expr = "intel_gpu_busy_percent";
            legendFormat = "GPU Overall";
          }
          {
            expr = ''intel_gpu_engine_busy_percent{engine="render"}'';
            legendFormat = "Render/3D";
          }
          {
            expr = ''intel_gpu_engine_busy_percent{engine="video"}'';
            legendFormat = "Video (Transcoding)";
          }
          {
            expr = ''intel_gpu_engine_busy_percent{engine="videoenhance"}'';
            legendFormat = "Video Enhancement";
          }
        ];
        fieldConfig.defaults = {
          unit = "percent";
          min = 0;
          max = 100;
          custom.lineWidth = 2;
          thresholds = {
            mode = "absolute";
            steps = [
              {
                value = 0;
                color = "green";
              }
              {
                value = 70;
                color = "yellow";
              }
              {
                value = 90;
                color = "red";
              }
            ];
          };
        };
      }
      {
        id = 7;
        gridPos = {
          x = 12;
          y = 24;
          w = 12;
          h = 8;
        };
        type = "timeseries";
        title = "Disk I/O";
        targets = [
          {
            expr = ''irate(node_disk_read_bytes_total{device=~"sd[a-z]+|nvme[0-9]+n[0-9]+"}[5m])'';
            legendFormat = "{{device}} read";
          }
          {
            expr = ''irate(node_disk_written_bytes_total{device=~"sd[a-z]+|nvme[0-9]+n[0-9]+"}[5m]) * -1'';
            legendFormat = "{{device}} write";
          }
        ];
        fieldConfig.defaults = {
          unit = "binBps";
          custom = {
            lineWidth = 2;
            fillOpacity = 10;
            gradientMode = "opacity";
          };
          thresholds = {
            mode = "absolute";
            steps = [ ];
          };
        };
      }
    ];
  };
}
