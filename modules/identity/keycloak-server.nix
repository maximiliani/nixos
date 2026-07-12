{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption recursiveUpdate types;
  cfg = config.inckmann.identity.keycloak;
  usingBootstrap = !cfg.manageSopsSecrets && cfg.bootstrap.enable;
  effectiveDbPasswordFile =
    if usingBootstrap
    then cfg.bootstrap.dbPasswordFile
    else if cfg.manageSopsSecrets
    then config.sops.secrets.keycloak_db_password.path
    else cfg.database.passwordFile;
  declareSopsSecrets = cfg.manageSopsSecrets && !usingBootstrap;
  edgeProxyCfg = config.inckmann.networking.edgeProxy;
in
{
  options.inckmann.identity.keycloak = {
    enable = mkEnableOption "Keycloak identity server";

    manageSopsSecrets = mkOption {
      type = types.bool;
      default = true;
      description = "Declare Keycloak password secrets via sops-nix when enabled.";
    };

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
      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "PostgreSQL hostname for Keycloak.";
      };
      name = mkOption {
        type = types.str;
        default = "keycloak";
        description = "Keycloak database name.";
      };
      user = mkOption {
        type = types.str;
        default = "keycloak";
        description = "Keycloak database user.";
      };
      passwordFile = mkOption {
        type = types.str;
        default = "/run/secrets/keycloak_db_password";
        description = "Database password file path.";
      };
    };

    bootstrap = {
      enable = mkEnableOption "bootstrap-based secret generation";

      dbPasswordFile = mkOption {
        type = types.str;
        default = "/var/lib/inckmann-vpn-bootstrap/secrets/keycloak-db-password";
        description = "Bootstrap-generated DB password path.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = (!edgeProxyCfg.enable) || builtins.hasAttr cfg.hostname edgeProxyCfg.targets;
        message = "inckmann.identity.keycloak requires inckmann.networking.edgeProxy.targets.\"${cfg.hostname}\" when edge proxy is enabled.";
      }
      {
        assertion = cfg.database.host == "localhost";
        message = "inckmann.identity.keycloak requires database.host = \"localhost\" with local PostgreSQL provisioning.";
      }
    ];

    sops.secrets = mkIf declareSopsSecrets {
      keycloak_db_password = { };
    };

    services.keycloak = {
      enable = true;
      realmFiles = cfg.realmFiles;
      database = {
        type = "postgresql";
        createLocally = true;
        host = cfg.database.host;
        name = cfg.database.name;
        username = cfg.database.user;
        passwordFile = effectiveDbPasswordFile;
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
  };
}
