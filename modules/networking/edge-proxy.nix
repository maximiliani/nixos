{ config, lib, ... }:
let
  inherit (lib) mapAttrs mkEnableOption mkIf mkOption optionals types;
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
        (_serverName: target: {
          enableACME = target.enableACME;
          forceSSL = target.forceSSL;
          locations."/" = {
            proxyPass = "${target.upstreamScheme}://${target.upstream}";
            proxyWebsockets = target.proxyWebsockets;
          };
        })
        cfg.targets;
    };

    networking.firewall.allowedTCPPorts = optionals cfg.openFirewall [ 80 443 ];
  };
}
