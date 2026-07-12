{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.inckmann.vpn.headscaleControl;
  enabled = cfg.bootstrap.enable && cfg.enable;
  dnsMagic = if cfg.dns.magicDNS then "true" else "false";
  dnsResolversYaml = lib.concatMapStringsSep "\n" (resolver: "      - ${resolver}") cfg.dns.globalResolvers;
in
{
  config = mkIf enabled {
    systemd.services.inckmann-headscale-bootstrap-secrets = {
      description = "Generate first-install Headscale secrets if missing";
      wantedBy = [ "multi-user.target" ];
      before = [ "headscale.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ pkgs.coreutils pkgs.openssl ];
      script = ''
        set -euo pipefail
        umask 077

        MARKER_FILE=/var/lib/inckmann-vpn-bootstrap/.headscale-generated
        TEMPLATE_FILE=${lib.escapeShellArg cfg.bootstrap.configTemplateFile}
        CONFIG_FILE=${lib.escapeShellArg cfg.bootstrap.configFile}
        OIDC_SECRET_FILE=${lib.escapeShellArg cfg.bootstrap.oidcClientSecretFile}

        ensure_parent_dir() {
          install -d -m 0700 "$(dirname "$1")"
        }

        secure_headscale_file() {
          local target="$1"
          if id -u headscale >/dev/null 2>&1; then
            chown headscale:headscale "$target"
            chmod 0640 "$target"
          else
            chmod 0600 "$target"
          fi
        }

        if [ ! -s "$OIDC_SECRET_FILE" ]; then
          ensure_parent_dir "$OIDC_SECRET_FILE"
          openssl rand -base64 36 | tr -d '\n' > "$OIDC_SECRET_FILE"
          printf '\n' >> "$OIDC_SECRET_FILE"
        fi
        secure_headscale_file "$OIDC_SECRET_FILE"

        if [ ! -s "$TEMPLATE_FILE" ]; then
          ensure_parent_dir "$TEMPLATE_FILE"
          cat > "$TEMPLATE_FILE" <<'EOF'
server_url: https://vpn.net.inckmann.de
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090
noise:
  private_key_path: /var/lib/headscale/noise_private.key
prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48
derp:
  server:
    enabled: false
oidc:
  only_start_if_oidc_is_available: true
  issuer: __HEADSCALE_OIDC_ISSUER__
  client_id: __HEADSCALE_OIDC_CLIENT_ID__
  client_secret: __HEADSCALE_OIDC_CLIENT_SECRET__
  scope: ["openid", "profile", "email", "groups"]
  allowed_groups: ["/admins", "/family", "/friends"]
dns:
  override_local_dns: true
  magic_dns: __HEADSCALE_DNS_MAGIC_DNS__
  base_domain: __HEADSCALE_DNS_BASE_DOMAIN__
  nameservers:
    global:
${dnsResolversYaml}
EOF
        fi
        secure_headscale_file "$TEMPLATE_FILE"

        if [ ! -s "$CONFIG_FILE" ]; then
          ensure_parent_dir "$CONFIG_FILE"
          cat > "$CONFIG_FILE" <<EOF
server_url: https://vpn.net.inckmann.de
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090
noise:
  private_key_path: /var/lib/headscale/noise_private.key
prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48
derp:
  server:
    enabled: false
oidc:
  only_start_if_oidc_is_available: true
  issuer: https://auth.inckmann.de/realms/inckmann
  client_id: headscale
  client_secret: $(cat "$OIDC_SECRET_FILE")
  scope: ["openid", "profile", "email", "groups"]
  allowed_groups: ["/admins", "/family", "/friends"]
dns:
  override_local_dns: true
  magic_dns: ${dnsMagic}
  base_domain: ${cfg.dns.baseDomain}
  nameservers:
    global:
${dnsResolversYaml}
EOF
        fi
        secure_headscale_file "$CONFIG_FILE"

        ensure_parent_dir "$MARKER_FILE"
        date -u +"%Y-%m-%dT%H:%M:%SZ" > "$MARKER_FILE"
        chmod 0600 "$MARKER_FILE"
      '';
    };
  };
}
