{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.inckmann.vpn.exitNode;
in
{
  options.inckmann.vpn.exitNode.enable = mkEnableOption "exit-node baseline profile";

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.tailscale ];
    networking.firewall.checkReversePath = "loose";
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
  };
}
