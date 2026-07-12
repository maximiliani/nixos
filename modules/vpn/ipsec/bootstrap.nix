{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.inckmann.vpn.ipsecGateway;
  enabled = cfg.bootstrap.enable && cfg.enable;
in
{
  config = mkIf enabled {
    systemd.services.inckmann-ipsec-bootstrap-secrets = {
      description = "Generate first-install IPSec secrets if missing";
      wantedBy = [ "multi-user.target" ];
      before = [ "strongswan-swanctl.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ pkgs.coreutils pkgs.openssl ];
      script = ''
        set -euo pipefail
        umask 077

        MARKER_FILE=/var/lib/inckmann-vpn-bootstrap/.ipsec-generated
        KEY_FILE=${lib.escapeShellArg cfg.bootstrap.serverKeyFile}
        CERT_FILE=${lib.escapeShellArg cfg.bootstrap.serverCertFile}
        CA_FILE=${lib.escapeShellArg cfg.bootstrap.caCertFile}

        ensure_parent_dir() {
          install -d -m 0700 "$(dirname "$1")"
        }

        has_key=0
        has_cert=0
        has_ca=0
        [ -s "$KEY_FILE" ] && has_key=1
        [ -s "$CERT_FILE" ] && has_cert=1
        [ -s "$CA_FILE" ] && has_ca=1

        if [ "$has_key" -eq 1 ] && [ "$has_cert" -eq 1 ] && [ "$has_ca" -eq 1 ]; then
          :
        elif [ "$has_key" -eq 1 ] || [ "$has_cert" -eq 1 ] || [ "$has_ca" -eq 1 ]; then
          echo "IPSec bootstrap files are partially present. Resolve manually before rerun." >&2
          exit 1
        else
          ensure_parent_dir "$KEY_FILE"
          ensure_parent_dir "$CERT_FILE"
          ensure_parent_dir "$CA_FILE"

          tmpdir="$(mktemp -d)"
          trap 'rm -rf "$tmpdir"' EXIT

          openssl genrsa -out "$tmpdir/ca.key" 4096
          openssl req -x509 -new -nodes -key "$tmpdir/ca.key" -sha256 -days 3650 \
            -subj "/CN=Inckmann VPN CA" \
            -out "$CA_FILE"

          openssl genrsa -out "$KEY_FILE" 4096
          openssl req -new -key "$KEY_FILE" \
            -subj "/CN=${cfg.serverId}" \
            -out "$tmpdir/server.csr"
          openssl x509 -req -in "$tmpdir/server.csr" \
            -CA "$CA_FILE" -CAkey "$tmpdir/ca.key" -CAcreateserial \
            -out "$CERT_FILE" -days 825 -sha256

          chmod 0600 "$KEY_FILE"
          chmod 0600 "$CERT_FILE"
          chmod 0600 "$CA_FILE"
        fi

        ensure_parent_dir "$MARKER_FILE"
        date -u +"%Y-%m-%dT%H:%M:%SZ" > "$MARKER_FILE"
        chmod 0600 "$MARKER_FILE"
      '';
    };
  };
}
