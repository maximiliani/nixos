{ config, lib, ... }:
let
  inherit (lib) elem mapAttrs mkEnableOption mkIf mkOption optionals recursiveUpdate types;
  cfg = config.inckmann.vpn.ipsecGateway;
  bootstrap = config.inckmann.vpn.bootstrap;
  usingBootstrap = bootstrap.generateOnFirstInstall && elem "ipsec" bootstrap.secretGroups;
  effectiveServerKeyFile =
    if usingBootstrap && cfg.serverKeyFile == "/run/secrets/ipsec_gateway_server_key"
    then bootstrap.paths.ipsecGatewayServerKey
    else cfg.serverKeyFile;
  effectiveServerCertFile =
    if usingBootstrap && cfg.serverCertFile == "/run/secrets/ipsec_gateway_server_cert"
    then bootstrap.paths.ipsecGatewayServerCert
    else cfg.serverCertFile;
  effectiveCaCertFile =
    if usingBootstrap && cfg.caCertFile == "/run/secrets/ipsec_gateway_ca_cert"
    then bootstrap.paths.ipsecGatewayCaCert
    else cfg.caCertFile;
  declareSopsSecrets = cfg.manageSopsSecrets && !usingBootstrap;
  defaultSettings = {
    connections."ikev2-eap" = {
      version = 2;
      local_addrs = [ "%any" ];
      remote_addrs = [ "%any" ];
      pools = [ "ikev2-pool" ];
      proposals = cfg.ikeProposals;
      local.main = {
        auth = "pubkey";
        id = cfg.serverId;
        certs = [ effectiveServerCertFile ];
      };
      remote.main = {
        auth = "eap-mschapv2";
        eap_id = "%any";
      };
      children."net-all" = {
        local_ts = [ "0.0.0.0/0" "::/0" ];
        esp_proposals = cfg.espProposals;
        dpd_action = "restart";
      };
    };

    pools."ikev2-pool" = {
      addrs = cfg.poolCidr;
      dns = cfg.poolDnsServers;
    };

    secrets.eap = mapAttrs (id: secret: {
      id.main = id;
      inherit secret;
    }) cfg.eapUsers;
  };
in
{
  options.inckmann.vpn.ipsecGateway = {
    enable = mkEnableOption "IPSec gateway (strongSwan swanctl)";

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open IKE/IPSec NAT-T ports (UDP 500/4500).";
    };

    serverId = mkOption {
      type = types.str;
      default = "vpn.net.inckmann.de";
      description = "Server identity/FQDN used in IKEv2 profile.";
    };

    serverKeyFile = mkOption {
      type = types.str;
      default = "/run/secrets/ipsec_gateway_server_key";
      description = "Path to server private key.";
    };

    serverCertFile = mkOption {
      type = types.str;
      default = "/run/secrets/ipsec_gateway_server_cert";
      description = "Path to server certificate.";
    };

    caCertFile = mkOption {
      type = types.str;
      default = "/run/secrets/ipsec_gateway_ca_cert";
      description = "Path to issuing CA certificate for client trust distribution.";
    };

    poolCidr = mkOption {
      type = types.str;
      default = "10.66.210.0/24";
      description = "IP address pool for IPSec clients.";
    };

    poolDnsServers = mkOption {
      type = types.listOf types.str;
      default = [ "1.1.1.1" "9.9.9.9" ];
      description = "DNS servers assigned to IPSec clients.";
    };

    ikeProposals = mkOption {
      type = types.listOf types.str;
      default = [ "aes256-sha256-modp2048" ];
      description = "IKE proposal list.";
    };

    espProposals = mkOption {
      type = types.listOf types.str;
      default = [ "aes256-sha256" ];
      description = "ESP proposal list.";
    };

    eapUsers = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "EAP username -> password map for client authentication.";
    };

    settingsOverrides = mkOption {
      type = types.attrs;
      default = { };
      description = "Deep override attrset merged onto module-generated swanctl settings.";
    };

    manageSopsSecrets = mkOption {
      type = types.bool;
      default = true;
      description = "Declare IPSec secret files via sops-nix when enabled.";
    };
  };

  config = mkIf cfg.enable {
    sops.secrets = mkIf declareSopsSecrets {
      ipsec_gateway_server_key = { };
      ipsec_gateway_server_cert = { };
      ipsec_gateway_ca_cert = { };
    };

    services.strongswan-swanctl = {
      enable = true;
      swanctl = recursiveUpdate defaultSettings cfg.settingsOverrides;
    };

    environment.etc."ipsec-gateway/ca.crt".source = effectiveCaCertFile;

    systemd.services.strongswan-swanctl = mkIf usingBootstrap {
      after = [ "inckmann-ipsec-bootstrap-secrets.service" ];
      requires = [ "inckmann-ipsec-bootstrap-secrets.service" ];
    };

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    networking.firewall.allowedUDPPorts = optionals cfg.openFirewall [ 500 4500 ];
  };
}
