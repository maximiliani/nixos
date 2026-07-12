{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.inckmann.vpn.wireguardGateway;
  enabled = cfg.bootstrap.enable && cfg.enable;
in
{
  config = mkIf enabled {
    systemd.services.inckmann-wireguard-bootstrap-secrets = {
      description = "Generate first-install WireGuard secrets if missing";
      wantedBy = [ "multi-user.target" ];
      before = [ "wg-quick-${cfg.interfaceName}.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ pkgs.coreutils pkgs.wireguard-tools ];
      script = ''
        set -euo pipefail
        umask 077

        MARKER_FILE=/var/lib/inckmann-vpn-bootstrap/.wireguard-generated
        WG_KEY_FILE=${lib.escapeShellArg cfg.bootstrap.privateKeyFile}

        ensure_parent_dir() {
          install -d -m 0700 "$(dirname "$1")"
        }

        if [ ! -s "$WG_KEY_FILE" ]; then
          ensure_parent_dir "$WG_KEY_FILE"
          wg genkey > "$WG_KEY_FILE"
          chmod 0600 "$WG_KEY_FILE"
        fi

        ensure_parent_dir "$MARKER_FILE"
        date -u +"%Y-%m-%dT%H:%M:%SZ" > "$MARKER_FILE"
        chmod 0600 "$MARKER_FILE"
      '';
    };
  };
}
