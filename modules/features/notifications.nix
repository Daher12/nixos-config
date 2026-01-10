{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.features.notifications;

  ntfySend = pkgs.writeShellScriptBin "ntfy-send" ''
    set -euo pipefail
    PRIORITY="''${1:-default}"
    TAGS="''${2:-}"
    TITLE="''${3:-Notification}"
    MESSAGE="''${4:-}"
    
    ${pkgs.curl}/bin/curl -sf --max-time 10 --retry 2 --retry-delay 5 \
      -H "Title: $TITLE" \
      -H "Priority: $PRIORITY" \
      -H "Tags: $TAGS" \
      -d "$MESSAGE" \
      "${cfg.server}/${cfg.topic}" \
      || ${pkgs.util-linux}/bin/logger -t ntfy-send "Failed to send: $TITLE"
  '';

  smartdNotify = pkgs.writeShellScript "smartd-ntfy" ''
    ${ntfySend}/bin/ntfy-send urgent warning,hard_drive \
      "Disk Error: $SMARTD_DEVICE" \
      "SMART error on ${config.networking.hostName}: $SMARTD_MESSAGE"
  '';
in
{
  options.features.notifications = {
    enable = lib.mkEnableOption "ntfy push notifications";

    server = lib.mkOption {
      type = lib.types.str;
      default = "https://ntfy.sh";
      description = "ntfy server URL";
    };

    topic = lib.mkOption {
      type = lib.types.str;
      example = "my-server-alerts";
      description = "ntfy topic (use unique, unguessable name)";
    };

    monitorServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "docker-jellyfin"
        "nixos-upgrade"
      ];
      description = "Services to monitor for failures";
    };

    bootNotification = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Send notification on system boot";
    };

    smartdNotifications = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable SMART disk error notifications";
    };

    alertmanagerBridge = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Alertmanager webhook bridge";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.topic != "";
        message = "features.notifications.topic must be set to a unique value";
      }
    ];

    environment.systemPackages = [ ntfySend ];

    systemd.services =
      (lib.genAttrs cfg.monitorServices (name: { unitConfig.OnFailure = "ntfy-failure@%n.service"; }))
      // {
        "ntfy-failure@" = {
          description = "Notify on %i failure";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = ''${ntfySend}/bin/ntfy-send urgent rotating_light,skull "Failed: %i" "Service %i failed on ${config.networking.hostName}"'';
          };
        };
      }
      // (lib.optionalAttrs cfg.bootNotification {
        ntfy-boot = {
          description = "Notify on system boot";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = ''${ntfySend}/bin/ntfy-send default computer,white_check_mark "System Boot" "${config.networking.hostName} started successfully"'';
          };
        };
      })
      // (lib.optionalAttrs cfg.alertmanagerBridge {
        alertmanager-ntfy-bridge = {
          description = "Alertmanager to ntfy webhook bridge";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            Type = "simple";
            Restart = "always";
            RestartSec = "5s";
            DynamicUser = true;
            MemoryMax = "64M";
          };
          script = ''
            ${pkgs.python3}/bin/python3 << 'EOF'
            import http.server, json, urllib.request
            
            NTFY_URL = "${cfg.server}/${cfg.topic}"
            
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
                            tags, title = 'white_check_mark,resolved', f"Resolved: {alertname}"
                        else:
                            tags = 'rotating_light,warning' if severity == 'warning' else 'fire,critical'
                            title = f"Alert: {alertname}"
                        
                        req = urllib.request.Request(NTFY_URL, data=summary.encode())
                        req.add_header('Title', title)
                        req.add_header('Priority', priority)
                        req.add_header('Tags', tags)
                        try: urllib.request.urlopen(req, timeout=10)
                        except Exception as e: print(f"Failed: {e}")
                    
                    self.send_response(200)
                    self.end_headers()
                
                def log_message(self, format, *args): pass
            
            server = http.server.HTTPServer(('127.0.0.1', 9095), AlertHandler)
            print("Alertmanager-ntfy bridge listening on :9095")
            server.serve_forever()
            EOF
          '';
        };
      });

    services.smartd = lib.mkIf cfg.smartdNotifications {
      notifications.x11.enable = false;
      notifications.wall.enable = true;
      notifications.mail.enable = false;
      defaults.monitored = "-a -o on -s (S/../.././02|L/../../6/03) -W 4,45,55 -m @${smartdNotify}";
    };
  };
}
