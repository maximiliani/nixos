{ config, lib, pkgs, ... }:
let
  inherit (lib) elem mkEnableOption mkIf mkOption optionals optionalString types;
  cfg = config.inckmann.vpn.headscaleControl;
  bootstrap = config.inckmann.vpn.bootstrap;
  usingBootstrap = bootstrap.generateOnFirstInstall && elem "headscale" bootstrap.secretGroups;
  effectiveConfigFile =
    if usingBootstrap && cfg.configFile == "/run/secrets/headscale_config"
    then bootstrap.paths.headscaleConfig
    else cfg.configFile;
  effectiveConfigTemplateFile =
    if usingBootstrap && cfg.configTemplateFile == "/run/secrets/headscale_config_template"
    then bootstrap.paths.headscaleConfigTemplate
    else cfg.configTemplateFile;
  effectiveOidcClientSecretFile =
    if usingBootstrap && cfg.keycloakOidc.clientSecretFile == "/run/secrets/headscale_oidc_client_secret"
    then bootstrap.paths.headscaleOidcClientSecret
    else cfg.keycloakOidc.clientSecretFile;
  declareSopsSecrets = cfg.manageSopsSecrets && !usingBootstrap;
in
{
  options.inckmann.vpn.headscaleControl = {
    enable = mkEnableOption "Headscale control plane service";

    package = mkOption {
      type = types.package;
      default = pkgs.headscale;
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
      default = true;
      description = "Declare required Headscale secret files via sops-nix when enabled.";
    };

    keycloakOidc = {
      enable = mkEnableOption "Keycloak OIDC secret injection";

      issuer = mkOption {
        type = types.str;
        default = "https://auth.inckmann.de/realms/inckmann";
        description = "Keycloak realm issuer URL for OIDC.";
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

      clientId = mkOption {
        type = types.str;
        default = "headscale";
        description = "OIDC client ID configured in Keycloak.";
      };

      clientSecretFile = mkOption {
        type = types.str;
        default = "/run/secrets/headscale_oidc_client_secret";
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
  };

  config = mkIf cfg.enable {
    users.groups.headscale = { };
    users.users.headscale = {
      isSystemUser = true;
      group = "headscale";
      home = "/var/lib/headscale";
      createHome = true;
    };

    sops.secrets =
      mkIf declareSopsSecrets (
        (if cfg.configMode == "template" then {
          headscale_config_template = {
            owner = "headscale";
            group = "headscale";
          };
        } else {
          headscale_config = {
            owner = "headscale";
            group = "headscale";
          };
        })
        // (if cfg.keycloakOidc.enable then {
          headscale_oidc_client_secret = {
            owner = "headscale";
            group = "headscale";
          };
        } else { })
      );

    systemd.services.headscale = {
      description = "Headscale coordination server";
      after = [ "network-online.target" ] ++ optionals usingBootstrap [ "inckmann-headscale-bootstrap-secrets.service" ];
      requires = optionals usingBootstrap [ "inckmann-headscale-bootstrap-secrets.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      preStart = optionalString (cfg.configMode == "template") ''
        install -d -m 0750 -o headscale -g headscale "$(dirname ${cfg.renderedConfigPath})"
        cp ${effectiveConfigTemplateFile} ${cfg.renderedConfigPath}
        chown headscale:headscale ${cfg.renderedConfigPath}
        chmod 0640 ${cfg.renderedConfigPath}

        ${
          if cfg.keycloakOidc.enable
          then ''
            OIDC_SECRET="$(${pkgs.coreutils}/bin/cat ${effectiveOidcClientSecretFile})"
            OIDC_ESCAPED="$(${pkgs.coreutils}/bin/printf '%s' "$OIDC_SECRET" | ${pkgs.gnused}/bin/sed -e 's/[\/&]/\\&/g')"
            OIDC_ISSUER_ESCAPED="$(${pkgs.coreutils}/bin/printf '%s' ${lib.escapeShellArg cfg.keycloakOidc.issuer} | ${pkgs.gnused}/bin/sed -e 's/[\/&]/\\&/g')"
            OIDC_CLIENT_ID_ESCAPED="$(${pkgs.coreutils}/bin/printf '%s' ${lib.escapeShellArg cfg.keycloakOidc.clientId} | ${pkgs.gnused}/bin/sed -e 's/[\/&]/\\&/g')"
            if ! ${pkgs.gnugrep}/bin/grep -q '__HEADSCALE_OIDC_CLIENT_SECRET__' ${cfg.renderedConfigPath}; then
              echo "missing __HEADSCALE_OIDC_CLIENT_SECRET__ placeholder in ${effectiveConfigTemplateFile}" >&2
              exit 1
            fi
            ${pkgs.gnused}/bin/sed -i "s/__HEADSCALE_OIDC_CLIENT_SECRET__/$OIDC_ESCAPED/g" ${cfg.renderedConfigPath}
            ${pkgs.gnused}/bin/sed -i "s/__HEADSCALE_OIDC_ISSUER__/$OIDC_ISSUER_ESCAPED/g" ${cfg.renderedConfigPath}
            ${pkgs.gnused}/bin/sed -i "s/__HEADSCALE_OIDC_CLIENT_ID__/$OIDC_CLIENT_ID_ESCAPED/g" ${cfg.renderedConfigPath}
          ''
          else ""
        }

        DNS_BASE_DOMAIN_ESCAPED="$(${pkgs.coreutils}/bin/printf '%s' ${lib.escapeShellArg cfg.dns.baseDomain} | ${pkgs.gnused}/bin/sed -e 's/[\/&]/\\&/g')"
        DNS_MAGIC_DNS="${if cfg.dns.magicDNS then "true" else "false"}"
        if ! ${pkgs.gnugrep}/bin/grep -q '__HEADSCALE_DNS_BASE_DOMAIN__' ${cfg.renderedConfigPath}; then
          echo "missing __HEADSCALE_DNS_BASE_DOMAIN__ placeholder in ${effectiveConfigTemplateFile}" >&2
          exit 1
        fi
        if ! ${pkgs.gnugrep}/bin/grep -q '__HEADSCALE_DNS_MAGIC_DNS__' ${cfg.renderedConfigPath}; then
          echo "missing __HEADSCALE_DNS_MAGIC_DNS__ placeholder in ${effectiveConfigTemplateFile}" >&2
          exit 1
        fi
        ${pkgs.gnused}/bin/sed -i "s/__HEADSCALE_DNS_BASE_DOMAIN__/$DNS_BASE_DOMAIN_ESCAPED/g" ${cfg.renderedConfigPath}
        ${pkgs.gnused}/bin/sed -i "s/__HEADSCALE_DNS_MAGIC_DNS__/$DNS_MAGIC_DNS/g" ${cfg.renderedConfigPath}
      '';
      serviceConfig = {
        User = "headscale";
        Group = "headscale";
        Restart = "on-failure";
        RestartSec = "5s";
        ExecStart = "${cfg.package}/bin/headscale serve --config ${
          if cfg.configMode == "template" then cfg.renderedConfigPath else effectiveConfigFile
        }";
        WorkingDirectory = "/var/lib/headscale";
      };
    };

    networking.firewall.allowedTCPPorts = optionals cfg.openFirewall [ cfg.port ];
    environment.systemPackages = [ cfg.package ];
  };
}
