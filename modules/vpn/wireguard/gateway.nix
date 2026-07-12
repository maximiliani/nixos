{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption optionalAttrs optionals types;
  cfg = config.inckmann.vpn.wireguardGateway;
  usingBootstrap = !cfg.manageSopsSecrets && cfg.bootstrap.enable;
  effectivePrivateKeyFile =
    if usingBootstrap && cfg.privateKeyFile == "/run/secrets/wireguard_gateway_private_key"
    then cfg.bootstrap.privateKeyFile
    else if cfg.manageSopsSecrets
    then config.sops.secrets.wireguard_gateway_private_key.path
    else cfg.privateKeyFile;
  effectivePresharedKeyFile =
    if cfg.presharedKeyFile != null && cfg.manageSopsSecrets
    then config.sops.secrets.wireguard_gateway_preshared_key.path
    else cfg.presharedKeyFile;
  declareSopsSecret = cfg.manageSopsSecrets && !usingBootstrap;
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

    privateKeyFile = mkOption {
      type = types.str;
      default = "/run/secrets/wireguard_gateway_private_key";
      description = "Path to server private key file.";
    };

    manageSopsSecret = mkOption {
      type = types.bool;
      default = true;
      description = "Declare wireguard_gateway_private_key secret via sops-nix when enabled.";
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

  config = mkIf cfg.enable {
    sops.secrets = mkIf declareSopsSecret {
      wireguard_gateway_private_key = { };
    } // mkIf (cfg.presharedKeyFile != null && declareSopsSecret) {
      wireguard_gateway_preshared_key = { };
    };

    networking.firewall.allowedUDPPorts = optionals cfg.openFirewall [ cfg.listenPort ];
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    networking.wg-quick.interfaces.${cfg.interfaceName} = {
      address = cfg.addresses;
      listenPort = cfg.listenPort;
      privateKeyFile = effectivePrivateKeyFile;
      peers = map
        (peer:
          {
            inherit (peer) publicKey allowedIPs;
          }
          // optionalAttrs (peer.endpoint != null) { endpoint = peer.endpoint; }
          // optionalAttrs (peer.presharedKeyFile != null) { presharedKeyFile = peer.presharedKeyFile; }
          // optionalAttrs (peer.persistentKeepalive != null) { persistentKeepalive = peer.persistentKeepalive; })
        cfg.peers;
    };

    systemd.services."wg-quick-${cfg.interfaceName}" = mkIf usingBootstrap {
      after = [ "inckmann-wireguard-bootstrap-secrets.service" ];
      requires = [ "inckmann-wireguard-bootstrap-secrets.service" ];
    };
  };
}
