{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.inckmann.identity.keycloak;
  enabled = cfg.bootstrap.enable && cfg.enable;
in
{
  config = mkIf enabled {
    systemd.services.inckmann-keycloak-bootstrap-secrets = {
      description = "Generate first-install Keycloak secrets if missing";
      wantedBy = [ "multi-user.target" ];
      before = [ "keycloak.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ pkgs.coreutils pkgs.openssl ];
      script = ''
        set -euo pipefail
        umask 077

        MARKER_FILE=/var/lib/inckmann-vpn-bootstrap/.keycloak-generated
        DB_PASSWORD_FILE=${lib.escapeShellArg cfg.bootstrap.dbPasswordFile}

        ensure_parent_dir() {
          install -d -m 0700 "$(dirname "$1")"
        }

        secure_keycloak_file() {
          local target="$1"
          if id -u keycloak >/dev/null 2>&1; then
            chown keycloak:keycloak "$target"
            chmod 0640 "$target"
          else
            chmod 0600 "$target"
          fi
        }

        random_secret_file() {
          local target="$1"
          if [ -s "$target" ]; then
            return 0
          fi
          ensure_parent_dir "$target"
          openssl rand -base64 36 | tr -d '\n' > "$target"
          printf '\n' >> "$target"
        }

        random_secret_file "$DB_PASSWORD_FILE"
        secure_keycloak_file "$DB_PASSWORD_FILE"

        ensure_parent_dir "$MARKER_FILE"
        date -u +"%Y-%m-%dT%H:%M:%SZ" > "$MARKER_FILE"
        chmod 0600 "$MARKER_FILE"
      '';
    };
  };
}
