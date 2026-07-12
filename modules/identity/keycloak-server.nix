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
      default = "auth.inckmann.de";
      description = "Public hostname for Keycloak.";
    };
    
    localHttpPort = mkOption {
      type = types.port;
      default = 8081;
      description = "Local HTTP port for reverse-proxy ingress.";
    };
    
    realmFiles = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "Realm JSON files imported by Keycloak on startup.";
    };
    
    settings = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional Keycloak settings merged with production-safe defaults.";
    };
    
    database = {
      passwordFile = mkOption {
        type = types.str;
        default = "/var/lib/inckmann-vpn-bootstrap/secrets/keycloak-db-password";
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
      realmFiles = cfg.realmFiles;
      database = {
        type = "postgresql";
        createLocally = false;
        host = "localhost";
        name = "keycloak";
        username = "keycloak";
        passwordFile = cfg.database.passwordFile;
      };
      settings = recursiveUpdate {
        hostname = cfg.hostname;
        hostname-strict = true;
        http-enabled = true;
        http-host = "127.0.0.1";
        http-port = cfg.localHttpPort;
        proxy-headers = "xforwarded";
        health-enabled = true;
        metrics-enabled = true;
      } cfg.settings;
    };
    
    # Create PostgreSQL database and user for Keycloak
    services.postgresql = {
      enable = mkIf cfg.enable true;
      package = mkDefault pkgs.postgresql_15;
      ensureDatabases = [ "keycloak" ];
      ensureUsers = [
        {
          name = "keycloak";
          passwordFile = cfg.database.passwordFile;
          ensureDBOwnership = true;
          isSuperuser = false;
        }
      ];
    };
  };
}
