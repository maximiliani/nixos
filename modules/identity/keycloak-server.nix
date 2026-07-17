{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption mkDefault recursiveUpdate types;
  cfg = config.inckmann.identity.keycloak;
  edgeProxyCfg = config.inckmann.networking.edgeProxy;
in
{
  options.inckmann.identity.keycloak = {
    enable = mkEnableOption "Keycloak identity server";

    hostname = mkOption {
      type = types.str;
      example = "auth.inckmann.de";
      description = "Public hostname for Keycloak.";
    };

    localHttpPort = mkOption {
      type = types.port;
      default = 8081;
      description = "Local HTTP port for reverse-proxy ingress.";
    };

    settings = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional Keycloak settings merged with production-safe defaults.";
    };

    database = {
      passwordFile = mkOption {
        type = types.str;
        default = "/run/secrets/keycloak-db-password";
        description = "Database password file path.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = (!edgeProxyCfg.enable) || builtins.hasAttr cfg.hostname edgeProxyCfg.targets;
        message = "inckmann.identity.keycloak requires inckmann.networking.edgeProxy.targets.\"${cfg.hostname}\" when edge proxy is enabled.";
      }
    ];

    services.keycloak = {
      enable = true;
      database = {
        type = "postgresql";
        createLocally = true;
        passwordFile = cfg.database.passwordFile;
      };
      initialAdminPassword = "HinzKunz";
      settings = recursiveUpdate {
        hostname = cfg.hostname;
        hostname-strict = false;
        http-enabled = true;
        http-host = "127.0.0.1";
        http-port = cfg.localHttpPort;
        proxy-headers = "xforwarded";
        health-enabled = true;
        metrics-enabled = true;
      } cfg.settings;
    };
  };
}
