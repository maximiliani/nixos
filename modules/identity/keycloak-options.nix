{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.inckmann.identity.keycloak;
in
{
  options.inckmann.identity.keycloak = {
    enable = mkEnableOption "Keycloak identity server";

    manageSopsSecrets = mkOption {
      type = types.bool;
      default = false;
      description = "Declare DB password via sops-nix. If disabled, uses bootstrap-generated secrets.";
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
        default = "/var/lib/inckmann-vpn-bootstrap/secrets/keycloak-db-password";
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
}
