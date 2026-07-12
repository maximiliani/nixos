{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.inckmann.vpn.wireguardGateway;
in
{
  options.inckmann.vpn.wireguardGateway = {
    enable = mkEnableOption "WireGuard gateway profile for appliance and standard clients";

    interfaceName = mkOption {
      type = types.str;
      default = "wg-gateway";
      description = "WireGuard interface name.";
    };

    addresses = mkOption {
      type = types.listOf types.str;
      default = [ "10.66.200.1/24" ];
      description = "Interface addresses for the WireGuard gateway network.";
    };

    listenPort = mkOption {
      type = types.port;
      default = 51820;
      description = "WireGuard UDP listener port.";
    };

    manageSopsSecrets = mkOption {
      type = types.bool;
      default = false;
      description = "Declare private key + PSK via sops-nix. If disabled, uses bootstrap-generated secrets.";
    };

    privateKeyFile = mkOption {
      type = types.str;
      default = "/var/lib/inckmann-vpn-bootstrap/secrets/wireguard-private-key";
      description = "Path to server private key file.";
    };

    presharedKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Global PSK file for all peers (null = disabled).";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open WireGuard UDP listener in firewall.";
    };

    peers = mkOption {
      type = types.listOf (types.submodule {
        options = {
          publicKey = mkOption {
            type = types.str;
          };
          allowedIPs = mkOption {
            type = types.listOf types.str;
            default = [ ];
          };
          endpoint = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          presharedKeyFile = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          persistentKeepalive = mkOption {
            type = types.nullOr types.int;
            default = null;
          };
        };
      });
      default = [ ];
      description = "WireGuard peers.";
    };

    bootstrap = {
      enable = mkEnableOption "bootstrap-based secret generation";

      privateKeyFile = mkOption {
        type = types.str;
        default = "/var/lib/inckmann-vpn-bootstrap/secrets/wireguard-private-key";
        description = "Bootstrap-generated private key path.";
      };
    };
  };
}
