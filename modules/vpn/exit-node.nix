{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption optionals types;
  cfg = config.inckmann.vpn.exitNode;
in
{
  options.inckmann.vpn.exitNode = {
    enable = mkEnableOption "VPN exit node functionality";
    
    advertiseTags = mkOption {
      type = types.listOf types.str;
      default = [ "tag:vpn-gateway" ];
      description = "Tailscale tags to advertise";
    };
    
    advertiseRoutes = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "IP routes to advertise via Tailscale (IPv4 and IPv6)";
    };
    
    allowForwarding = mkOption {
      type = types.bool;
      default = true;
      description = "Enable packet forwarding between VPN interfaces";
    };
  };
  
  config = mkIf cfg.enable {
    boot.kernel.sysctl = mkIf cfg.allowForwarding {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
    
    services.tailscale = {
      extraUpFlags = [
        "--advertise-tags=${lib.concatStringsSep "," cfg.advertiseTags}"
        "--advertise-exit-node"
      ] ++ optionals (cfg.advertiseRoutes != []) [
        "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}"
      ];
      
      extraSetFlags = [
        "--accept-routes"
        "--ssh"
      ];
      
      useRoutingFeatures = "both";
    };
    
    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
    };
  };
}
