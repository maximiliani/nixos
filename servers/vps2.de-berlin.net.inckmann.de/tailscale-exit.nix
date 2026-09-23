{ config, ... }:
let
  tailscale-exit = config.myModules.ips.tailscale-exit;
in
{
  imports = [
    ../../modules
  ];
  local.tailscale = {
    enable = true;
    exit-node = true;
    routes = [
      "10.0.0.0/8"
    ];
  };

  services.tailscale = {
    extraUpFlags = [
      "--snat-subnet-routes=false"
    ];
  };

  networking = {
    hostName = "tailscale-exit";
    enableIPv6 = true;
    useHostResolvConf = false;
    tempAddresses = "disabled";
    nameservers = config.myModules.internet-nameservers;
    interfaces.eth0 = {
      ipv4.addresses = [ tailscale-exit-vps2-de-berlin.ipv4 ];
      ipv6.addresses = [ tailscale-exit-vps2-de-berlin.ipv6 ];
    };
    firewall = {
      allowPing = true;
    };
  };
  system.stateVersion = "26.05";
}
