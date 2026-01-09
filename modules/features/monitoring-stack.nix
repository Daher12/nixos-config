{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.monitoring-stack;

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
              labels.severity = "warning";
              annotations.summary = "CPU > 90% for 5m";
            }
            {
              alert = "HighMemoryUsage";
              expr = ''100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 90'';
              for = "5m";
              labels.severity = "warning";
              annotations.summary = "Memory > 90% for 5m";
            }
            {
              alert = "LowDiskSpace";
              expr = ''100 - ((node_filesystem_avail_bytes{mountpoint="/mnt/storage"} * 100) / node_filesystem_size_bytes{mountpoint="/mnt/storage"}) > 90'';
              for = "10m";
              labels.severity = "critical";
              annotations.summary = "Storage < 10% free";
            }
            {
              alert = "LowRootDiskSpace";
              expr = ''100 - ((node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"}) > 85'';
              for = "10m";
              labels.severity = "warning";
              annotations.summary = "Root < 15% free";
            }
            {
              alert = "HighIOWait";
              expr = ''avg(irate(node_cpu_seconds_total{mode="iowait"}[5m])) * 100 > 50'';
              for = "5m";
              labels.severity = "warning";
              annotations.summary = "I/O wait > 50%";
            }
            {
              alert = "ContainerDown";
              expr = ''up{job="cadvisor"} == 0'';
              for = "2m";
              labels.severity = "critical";
              annotations.summary = "cAdvisor down";
            }
          ];
        }
      ];
    }
  );

  # Intel GPU metrics with N100-specific documentation
  gpuMetricsScript = pkgs.writeShellScript "collect-gpu-metrics" ''
    # =============================================================================
    # Intel GPU Metrics Collector for N100 (Alder Lake-N)
    # =============================================================================
    # Hardware: Intel N100 (Device ID: 46d1)
    # Tool: intel_gpu_top v${pkgs.intel-gpu-tools.version}
    # Sample interval: 1000ms (1 second)
    #
    # COLUMN LAYOUT (text mode output):
    # ----------------------------------
    # $1  = Freq Req (MHz)    - Requested GPU frequency
    # $2  = Freq Act (MHz)    - Actual GPU frequency
    # $3  = IRQ/s             - Interrupts per second
    # $4  = RC6 (%)           - Render idle power state percentage
    # $5  = Power GPU (W)     - GPU power consumption
    # $6  = Power Pkg (W)     - Package power consumption
    #
    # ENGINE UTILIZATION COLUMNS:
    # ---------------------------
    # $7  = Render/3D (%)     - 3D rendering workload
    # $11 = Video (%)         - Video decode/encode (QSV)
    # $13 = VideoEnhance (%)  - Video post-processing
    #
    # N100 NOTES:
    # -----------
    # - Video engine = QuickSync (H.264/HEVC/VP9/AV1 transcoding)
    # - Render can spike during UI compositing even on headless systems
    # - VideoEnhance handles tone mapping, scaling, deinterlacing
    # - Overall utilization = max(Render, Video, VideoEnhance)
    #
    # TROUBLESHOOTING:
    # ----------------
    # If metrics stop updating:
    #   1. Check /dev/dri/renderD128 permissions (should be 0666)
    #   2. Verify i915.force_probe=46d1 in kernel params
    #   3. Run: intel_gpu_top -s 1000 (manual test)
    #   4. Check journalctl -u intel-gpu-metrics for errors
    # =============================================================================

    export LC_ALL=C  # Ensure decimal points are dots, not commas
    
    TMPFILE=/var/lib/prometheus-node-exporter/intel_gpu.prom.tmp
    OUTFILE=/var/lib/prometheus-node-exporter/intel_gpu.prom
    
    # Capture ~4 seconds of samples for statistical smoothing
    OUTPUT=$(${pkgs.coreutils}/bin/timeout 4s ${pkgs.intel-gpu-tools}/bin/intel_gpu_top -s 1000 | tr -d '\r')
    
    echo "$OUTPUT" | ${pkgs.gawk}/bin/awk '
      BEGIN {
        render_sum=0; video_sum=0; enhance_sum=0; samples=0
      }
      
      # Skip headers and empty lines
      /Freq/ || /req/ || /^$/ { next }
      
      # Parse data lines: must start with number and have enough columns
      $1 ~ /^[0-9.]+$/ && NF >= 13 {
        render_sum  += $7
        video_sum   += $11
        enhance_sum += $13
        samples++
      }
      
      END {
        if (samples > 0) {
          render  = render_sum / samples
          video   = video_sum / samples
          enhance = enhance_sum / samples
          
          # Overall = max of any engine (conservative approach)
          busy = render
          if (video > busy) busy = video
          if (enhance > busy) busy = enhance
        } else {
          render = 0; video = 0; enhance = 0; busy = 0
        }
        
        # Output Prometheus metrics
        printf "intel_gpu_engine_busy_percent{engine=\"render\"} %.2f\n", render
        printf "intel_gpu_engine_busy_percent{engine=\"video\"} %.2f\n", video
        printf "intel_gpu_engine_busy_percent{engine=\"videoenhance\"} %.2f\n", enhance
        printf "intel_gpu_busy_percent %.2f\n", busy
        printf "intel_gpu_build_info{version=\"${pkgs.intel-gpu-tools.version}\"} 1\n"
      }
    ' > "$TMPFILE"
    
    # Atomic write to prevent partial reads
    if [ -s "$TMPFILE" ]; then
      mv "$TMPFILE" "$OUTFILE"
      chmod 644 "$OUTFILE"
    fi
  '';

  # Complete Grafana dashboard with all 8 panels
  dashboardJson = builtins.toJSON {
    title = "NixOS Media Server";
    uid = "nixos-overview";
    tags = [ "nixos" "media" ];
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
            refId = "A";
          }
        ];
        fieldConfig.defaults = {
          unit = "percent";
          min = 0;
          max = 100;
          custom = {
            lineWidth = 2;
            fillOpacity = 10;
            gradientMode = "opacity";
          };
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
            expr = ''100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))'';
            legendFormat = "RAM Used";
            refId = "A";
          }
        ];
        fieldConfig.defaults = {
          unit = "percent";
          min = 0;
          max = 100;
          custom = {
            lineWidth = 2;
            fillOpacity = 10;
            gradientMode = "opacity";
          };
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
            refId = "A";
          }
        ];
        fieldConfig.defaults = {
          unit = "percent";
          min = 0;
          max = 100;
          custom = {
            lineWidth = 2;
            fillOpacity = 10;
            gradientMode = "opacity";
          };
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
            refId = "A";
          }
          {
            expr = ''irate(node_network_transmit_bytes_total{device="enp1s0"}[5m])'';
            legendFormat = "TX";
            refId = "B";
          }
        ];
        fieldConfig.defaults = {
          unit = "Bps";
          custom = {
            lineWidth = 2;
            fillOpacity = 10;
            gradientMode = "opacity";
          };
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
            refId = "A";
          }
        ];
        fieldConfig.defaults = {
          unit = "percent";
          min = 0;
          custom = {
            lineWidth = 2;
            fillOpacity = 10;
            gradientMode = "opacity";
          };
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
            refId = "A";
          }
        ];
        fieldConfig.defaults = {
          unit = "bytes";
          custom = {
            lineWidth = 2;
            fillOpacity = 10;
            gradientMode = "opacity";
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
        title = "Disk I/O (Reads (+) / Writes (-))";
        targets = [
          {
            expr = ''irate(node_disk_read_bytes_total{device=~"sd[a-z]+|nvme[0-9]+n[0-9]+"}[5m])'';
            legendFormat = "{{device}} read";
            refId = "A";
          }
          {
            expr = ''irate(node_disk_written_bytes_total{device=~"sd[a-z]+|nvme[0-9]+n[0-9]+"}[5m]) * -1'';
            legendFormat = "{{device}} write";
            refId = "B";
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
            refId = "A";
          }
          {
            expr = ''intel_gpu_engine_busy_percent{engine="render"}'';
            legendFormat = "Render/3D";
            refId = "B";
          }
          {
            expr = ''intel_gpu_engine_busy_percent{engine="video"}'';
            legendFormat = "Video (Transcoding)";
            refId = "C";
          }
          {
            expr = ''intel_gpu_engine_busy_percent{engine="videoenhance"}'';
            legendFormat = "Video Enhancement";
            refId = "D";
          }
        ];
        fieldConfig.defaults = {
          unit = "percent";
          min = 0;
          max = 100;
          custom = {
            lineWidth = 2;
            fillOpacity = 10;
            gradientMode = "opacity";
          };
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
    ];
  };
in
{
  options.features.monitoring-stack = {
    enable = lib.mkEnableOption "Prometheus + Grafana + Alertmanager monitoring";

    prometheus = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 9090;
      };
      retentionDays = lib.mkOption {
        type = lib.types.int;
        default = 30;
      };
    };

    grafana = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 3001;
      };
      adminPassword = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Initial admin password (change after first login)";
      };
    };

    alertmanager = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 9093;
      };
      webhookUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:9095/alert";
        description = "Alert webhook endpoint (for ntfy bridge)";
      };
    };

    nodeExporter = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 9100;
      };
    };

    intelGpuMetrics = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Collect Intel GPU metrics via intel_gpu_top";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      port = cfg.prometheus.port;
      listenAddress = "127.0.0.1";
      retentionTime = "${toString cfg.prometheus.retentionDays}d";
      extraFlags = [
        "--storage.tsdb.wal-compression"
        "--storage.tsdb.min-block-duration=2h"
        "--storage.tsdb.max-block-duration=2h"
      ];
      globalConfig = {
        scrape_interval = "30s";
        evaluation_interval = "30s";
        external_labels = {
          monitor = config.networking.hostName;
          environment = "production";
        };
      };

      ruleFiles = [ alertRulesFile ];

      alertmanagers = lib.mkIf cfg.alertmanager.enable [
        { static_configs = [ { targets = [ "127.0.0.1:${toString cfg.alertmanager.port}" ]; } ]; }
      ];

      scrapeConfigs = [
        {
          job_name = "node";
          scrape_interval = "30s";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString cfg.nodeExporter.port}" ];
              labels.instance = config.networking.hostName;
            }
          ];
        }
        {
          job_name = "cadvisor";
          scrape_interval = "60s";
          static_configs = [
            {
              targets = [ "127.0.0.1:8080" ];
              labels.instance = config.networking.hostName;
            }
          ];
        }
        {
          job_name = "docker";
          scrape_interval = "120s";
          static_configs = [
            {
              targets = [ "127.0.0.1:9323" ];
              labels.instance = config.networking.hostName;
            }
          ];
        }
      ];

      exporters.node = {
        enable = true;
        port = cfg.nodeExporter.port;
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

    services.prometheus.alertmanager = lib.mkIf cfg.alertmanager.enable {
      enable = true;
      port = cfg.alertmanager.port;
      listenAddress = "127.0.0.1";
      configuration = {
        global.resolve_timeout = "5m";
        route = {
          receiver = "webhook";
          group_by = [
            "alertname"
            "severity"
          ];
          group_wait = "30s";
          group_interval = "5m";
          repeat_interval = "4h";
          routes = [
            {
              match.severity = "critical";
              receiver = "webhook";
              repeat_interval = "1h";
            }
          ];
        };
        receivers = [
          {
            name = "webhook";
            webhook_configs = [
              {
                url = cfg.alertmanager.webhookUrl;
                send_resolved = true;
              }
            ];
          }
        ];
      };
    };

    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_port = cfg.grafana.port;
          http_addr = "127.0.0.1";
          root_url = "%(protocol)s://%(domain)s/grafana";
          serve_from_sub_path = true;
          enable_gzip = true;
        };
        security = {
          admin_user = "admin";
          admin_password = cfg.grafana.adminPassword;
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
          org_role = "Viewer";
        };
        dashboards.default_home_dashboard_path = "/etc/grafana/dashboards/system-overview.json";
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:${toString cfg.prometheus.port}";
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

    environment.etc."grafana/dashboards/system-overview.json".text = dashboardJson;

    systemd.tmpfiles.rules = lib.mkIf cfg.intelGpuMetrics [
      "d /var/lib/prometheus-node-exporter 0755 prometheus prometheus - -"
    ];

    systemd.services.intel-gpu-metrics = lib.mkIf cfg.intelGpuMetrics {
      description = "Intel GPU Metrics Collector";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        TimeoutStartSec = "8s";
        ExecStart = gpuMetricsScript;
      };
    };

    systemd.timers.intel-gpu-metrics = lib.mkIf cfg.intelGpuMetrics {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "10s";
        OnUnitActiveSec = "30s";
      };
    };

    # Resource limits
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
      IOWeight = 50;
      TasksMax = 64;
      Nice = 15;
    };

    systemd.services.alertmanager.serviceConfig = {
      MemoryMax = "128M";
      CPUQuota = "10%";
      Nice = 10;
    };

    systemd.services.grafana.serviceConfig = {
      MemoryMax = "384M";
      MemoryHigh = "320M";
      CPUQuota = "30%";
      CPUWeight = 100;
      TasksMax = 256;
      Nice = 5;
    };
  };
}
