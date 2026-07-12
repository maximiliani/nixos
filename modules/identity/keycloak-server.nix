{ config, lib, ... }:
let
  inherit (lib) elem mkEnableOption mkIf mkOption recursiveUpdate types;
  cfg = config.inckmann.identity.keycloak;
  bootstrap = config.inckmann.vpn.bootstrap;
  usingBootstrap = bootstrap.generateOnFirstInstall && elem "keycloak" bootstrap.secretGroups;
  effectiveDbPasswordFile =
    if usingBootstrap && cfg.database.passwordFile == "/run/secrets/keycloak_db_password"
    then bootstrap.paths.keycloakDbPassword
    else cfg.database.passwordFile;
  effectiveAdminPasswordFile =
    if usingBootstrap && cfg.adminPasswordFile == "/run/secrets/keycloak_admin_password"
    then bootstrap.paths.keycloakAdminPassword
    else cfg.adminPasswordFile;
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
      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = "Provision local PostgreSQL database and user.";
      };
      passwordFile = mkOption {
        type = types.str;
        default = "/run/secrets/keycloak_db_password";
        description = "Database password file path.";
      };
    };

    adminPasswordFile = mkOption {
      type = types.str;
      default = "/run/secrets/keycloak_admin_password";
      description = "Initial Keycloak admin password file path.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = (!edgeProxyCfg.enable) || builtins.hasAttr cfg.hostname edgeProxyCfg.targets;
        message = "inckmann.identity.keycloak requires inckmann.networking.edgeProxy.targets.\"${cfg.hostname}\" when edge proxy is enabled.";
      }
      {
        assertion = (!cfg.database.createLocally) || cfg.database.host == "localhost";
        message = "inckmann.identity.keycloak.database.createLocally requires database.host = \"localhost\".";
      }
    ];

    sops.secrets = mkIf declareSopsSecrets {
      keycloak_db_password = {
        owner = "keycloak";
        group = "keycloak";
      };
      keycloak_admin_password = {
        owner = "keycloak";
        group = "keycloak";
      };
    };

    services.keycloak = {
      enable = true;
      realmFiles = cfg.realmFiles;
      database = {
        type = "postgresql";
        createLocally = cfg.database.createLocally;
        host = cfg.database.host;
        name = cfg.database.name;
        username = cfg.database.user;
        passwordFile = effectiveDbPasswordFile;
      };
      settings = recursiveUpdate {
        bootstrap-admin-username = "admin";
        bootstrap-admin-password._secret = effectiveAdminPasswordFile;
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

    systemd.services.keycloak = mkIf usingBootstrap {
      after = [ "inckmann-keycloak-bootstrap-secrets.service" ];
      requires = [ "inckmann-keycloak-bootstrap-secrets.service" ];
    };
  };
}
