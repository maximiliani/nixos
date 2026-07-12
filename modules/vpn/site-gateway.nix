{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.inckmann.vpn.siteGateway;
in
{
  options.inckmann.vpn.siteGateway.enable = mkEnableOption "site-gateway baseline profile";

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.tailscale pkgs.tcpdump ];
    networking.firewall.checkReversePath = "loose";
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
  };
}
