{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.inckmann.vpn.bootstrap;
in
{
  options.inckmann.vpn.bootstrap = {
    generateOnFirstInstall = mkEnableOption "first-install VPN secret bootstrap generation";

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/inckmann-vpn-bootstrap";
      description = "Base directory for local first-install bootstrap state and generated secrets.";
    };

    markerFile = mkOption {
      type = types.str;
      default = "${cfg.stateDir}/.generated";
      description = "Marker file written after successful bootstrap runs.";
    };

    secretGroups = mkOption {
      type = types.listOf (types.enum [ "keycloak" "headscale" "wireguard" "ipsec" ]);
      default = [ "keycloak" "headscale" "wireguard" "ipsec" ];
      description = "Secret groups to generate during first-install bootstrap.";
    };

    serverId = mkOption {
      type = types.str;
      default = "vpn.net.inckmann.de";
      description = "Server identity used for generated Headscale/IPSec defaults.";
    };

    oidcIssuer = mkOption {
      type = types.str;
      default = "https://auth.inckmann.de/realms/inckmann";
      description = "Default OIDC issuer value used in generated Headscale config.";
    };

    oidcClientId = mkOption {
      type = types.str;
      default = "headscale";
      description = "Default OIDC client ID value used in generated Headscale config.";
    };

    paths = {
      keycloakDbPassword = mkOption {
        type = types.str;
        default = "${cfg.stateDir}/secrets/keycloak_db_password";
        description = "Bootstrap-generated Keycloak DB password file.";
      };
      keycloakAdminPassword = mkOption {
        type = types.str;
        default = "${cfg.stateDir}/secrets/keycloak_admin_password";
        description = "Bootstrap-generated Keycloak admin password file.";
      };
      headscaleConfigTemplate = mkOption {
        type = types.str;
        default = "${cfg.stateDir}/secrets/headscale_config_template";
        description = "Bootstrap-generated Headscale template config file.";
      };
      headscaleConfig = mkOption {
        type = types.str;
        default = "${cfg.stateDir}/secrets/headscale_config";
        description = "Bootstrap-generated static Headscale config file.";
      };
      headscaleOidcClientSecret = mkOption {
        type = types.str;
        default = "${cfg.stateDir}/secrets/headscale_oidc_client_secret";
        description = "Bootstrap-generated Headscale OIDC client secret file.";
      };
      wireguardGatewayPrivateKey = mkOption {
        type = types.str;
        default = "${cfg.stateDir}/secrets/wireguard_gateway_private_key";
        description = "Bootstrap-generated WireGuard gateway private key file.";
      };
      ipsecGatewayServerKey = mkOption {
        type = types.str;
        default = "${cfg.stateDir}/secrets/ipsec_gateway_server_key";
        description = "Bootstrap-generated IPSec gateway private key file.";
      };
      ipsecGatewayServerCert = mkOption {
        type = types.str;
        default = "${cfg.stateDir}/secrets/ipsec_gateway_server_cert";
        description = "Bootstrap-generated IPSec gateway certificate file.";
      };
      ipsecGatewayCaCert = mkOption {
        type = types.str;
        default = "${cfg.stateDir}/secrets/ipsec_gateway_ca_cert";
        description = "Bootstrap-generated IPSec CA certificate file.";
      };
    };
  };
}
