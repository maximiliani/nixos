{ config, lib, ... }:
let
  inherit (lib) mapAttrs mkEnableOption mkIf mkOption optionalAttrs optionals types;
  cfg = config.inckmann.networking.edgeProxy;
in
{
  options.inckmann.networking.edgeProxy = {
    enable = mkEnableOption "generic edge reverse proxy targets";

    targets = mkOption {
      type = types.attrsOf (types.submodule ({ ... }: {
        options = {
          upstream = mkOption {
            type = types.str;
            description = "Upstream host:port target.";
          };

          upstreamScheme = mkOption {
            type = types.enum [ "http" "https" ];
            default = "http";
            description = "Protocol used to reach upstream.";
          };

          enableACME = mkOption {
            type = types.bool;
            default = false;
            description = "Request ACME certificate for this hostname.";
          };

          useACMEHost = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Reuse ACME certificate from another configured hostname.";
          };

          sslCertificate = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Path to TLS certificate PEM file for this hostname.";
          };

          sslCertificateKey = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Path to TLS private key PEM file for this hostname.";
          };

          forceSSL = mkOption {
            type = types.bool;
            default = true;
            description = "Redirect HTTP to HTTPS for this hostname.";
          };

          proxyWebsockets = mkOption {
            type = types.bool;
            default = true;
            description = "Enable websocket proxy behavior.";
          };
        };
      }));
      default = { };
      description = "Map of server name to upstream proxy settings.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open HTTP/HTTPS firewall ports.";
    };
  };

  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts = mapAttrs
        (_serverName: target:
          let
            hasTlsMaterial =
              target.enableACME
              || target.useACMEHost != null
              || (target.sslCertificate != null && target.sslCertificateKey != null);
          in
          {
            enableACME = target.enableACME;
            forceSSL = target.forceSSL && hasTlsMaterial;
            locations."/" = {
              proxyPass = "${target.upstreamScheme}://${target.upstream}";
              proxyWebsockets = target.proxyWebsockets;
              proxy_set_header = X-Forwarded-For $proxy_protocol_addr;
              proxy_set_header = X-Forwarded-Proto $scheme;
              proxy_set_header = X-Forwarded-Host $host;
              proxy_set_header = X-Forwarded-Port 8888;
            };
          }
          // optionalAttrs (target.useACMEHost != null) {
            useACMEHost = target.useACMEHost;
          }
          // optionalAttrs (target.sslCertificate != null) {
            sslCertificate = target.sslCertificate;
          }
          // optionalAttrs (target.sslCertificateKey != null) {
            sslCertificateKey = target.sslCertificateKey;
          })
        cfg.targets;
    };

    networking.firewall.allowedTCPPorts = optionals cfg.openFirewall [ 80 443 ];
  };
}
