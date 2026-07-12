{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.inckmann.vpn.headscaleControl;
in
{
  options.inckmann.vpn.headscaleControl = {
    enable = mkEnableOption "Headscale control plane service";

    package = mkOption {
      type = types.package;
      default = config.nixpkgs.pkgs.headscale;
      description = "Headscale package to run.";
    };

    configMode = mkOption {
      type = types.enum [ "template" "file" ];
      default = "template";
      description = "Whether to run Headscale from a template rendered at startup or a static config file.";
    };

    configFile = mkOption {
      type = types.str;
      default = "/run/secrets/headscale_config";
      description = "Static config path used when configMode = file.";
    };

    configTemplateFile = mkOption {
      type = types.str;
      default = "/run/secrets/headscale_config_template";
      description = "Template config file path used when configMode = template.";
    };

    renderedConfigPath = mkOption {
      type = types.str;
      default = "/run/headscale/config.yaml";
      description = "Rendered config output path used when configMode = template.";
    };

    manageSopsSecrets = mkOption {
      type = types.bool;
      default = false;
      description = "Declare required Headscale secret files via sops-nix when enabled. If disabled, uses bootstrap-generated secrets.";
    };

    oidcClientSecretFile = mkOption {
      type = types.str;
      default = "/var/lib/inckmann-vpn-bootstrap/secrets/headscale-oidc-client-secret";
      description = "Path to OIDC client secret file.";
    };

    dns = {
      magicDNS = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Headscale MagicDNS for managed clients.";
      };

      baseDomain = mkOption {
        type = types.str;
        default = "headscale.inckmann.de";
        description = "Tailnet DNS suffix assigned to nodes (for example <node>.headscale.inckmann.de).";
      };

      globalResolvers = mkOption {
        type = types.listOf types.str;
        default = [ "1.1.1.1" "9.9.9.9" ];
        description = "Upstream recursive resolvers used by Headscale DNS.";
      };
    };

    keycloakOidc = {
      enable = mkEnableOption "Keycloak OIDC secret injection";

      issuer = mkOption {
        type = types.str;
        default = "https://auth.inckmann.de/realms/inckmann";
        description = "Keycloak realm issuer URL for OIDC.";
      };

      clientId = mkOption {
        type = types.str;
        default = "headscale";
        description = "OIDC client ID configured in Keycloak.";
      };

      clientSecretFile = mkOption {
        type = types.str;
        default = "/var/lib/inckmann-vpn-bootstrap/secrets/headscale-oidc-client-secret";
        description = "Path to OIDC client secret file.";
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the configured HTTPS port in the firewall.";
    };

    port = mkOption {
      type = types.port;
      default = 443;
      description = "Public port used by reverse-proxied Headscale API.";
    };

    bootstrap = {
      enable = mkEnableOption "bootstrap-based secret generation (alternative to sops)";

      oidcClientSecretFile = mkOption {
        type = types.str;
        default = "/var/lib/inckmann-vpn-bootstrap/secrets/headscale-oidc-client-secret";
        description = "Bootstrap-generated OIDC secret path.";
      };

      configFile = mkOption {
        type = types.str;
        default = "/var/lib/inckmann-vpn-bootstrap/secrets/headscale-config.yaml";
        description = "Bootstrap-generated config path.";
      };

      configTemplateFile = mkOption {
        type = types.str;
        default = "/var/lib/inckmann-vpn-bootstrap/secrets/headscale-config-template.yaml";
        description = "Bootstrap-generated config template path.";
      };
    };
  };
}
