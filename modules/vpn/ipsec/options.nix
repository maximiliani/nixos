{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.inckmann.vpn.ipsecGateway;
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

    manageSopsSecrets = mkOption {
      type = types.bool;
      default = false;
      description = "Declare server key + certs via sops-nix. If disabled, uses bootstrap-generated secrets.";
    };

    serverKeyFile = mkOption {
      type = types.str;
      default = "/var/lib/inckmann-vpn-bootstrap/secrets/ipsec-server-key";
      description = "Path to server private key.";
    };

    serverCertFile = mkOption {
      type = types.str;
      default = "/var/lib/inckmann-vpn-bootstrap/secrets/ipsec-server-cert";
      description = "Path to server certificate.";
    };

    caCertFile = mkOption {
      type = types.str;
      default = "/var/lib/inckmann-vpn-bootstrap/secrets/ipsec-ca-cert";
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

    bootstrap = {
      enable = mkEnableOption "bootstrap-based secret generation";

      serverKeyFile = mkOption {
        type = types.str;
        default = "/var/lib/inckmann-vpn-bootstrap/secrets/ipsec-server-key";
        description = "Bootstrap-generated server key path.";
      };

      serverCertFile = mkOption {
        type = types.str;
        default = "/var/lib/inckmann-vpn-bootstrap/secrets/ipsec-server-cert";
        description = "Bootstrap-generated server cert path.";
      };

      caCertFile = mkOption {
        type = types.str;
        default = "/var/lib/inckmann-vpn-bootstrap/secrets/ipsec-ca-cert";
        description = "Bootstrap-generated CA cert path.";
      };
    };
  };
}
