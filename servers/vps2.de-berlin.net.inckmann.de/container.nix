{
  config,
  inputs,
  lib,
  pkgs,
  sops,
  stable,
  ...
}:
let
  mkContainer =
    options:
    lib.recursiveUpdate {
      autoStart = true;
      specialArgs = {
        inherit inputs stable sops;
        secureboot = false;
      };
      privateNetwork = true;
      bindMounts = {
        "${config.sops.age.keyFile}" = {
          mountPoint = "/var/lib/sops-nix/key.txt";
          hostPath = config.sops.age.keyFile;
        };
      };
    } options;
in
{
  networking.nat = {
    enable = true;
    # Use "ve-*" when using nftables instead of iptables
    internalInterfaces = ["ve-+"];
    externalInterface = "ens6";
    # Lazy IPv6 connectivity for the container
    enableIPv6 = true;
  };

  services.avahi.enable = true;

  console.keyMap = "de";

  # boot.supportedFilesystems = [
  #   "zfs"
  #   "lvm"
  # ];

  boot.tmp.cleanOnBoot = true;

  systemd.services = {
    "container@kanidm" = rec {
      wants = [
        "container@proxy.service"
      ];
      after = wants;
    };
  };

  containers = {
    proxy = mkContainer {
      config = (import ./proxy.nix);
      bindMounts = lib.mkForce {
        "/var/lib/acme" = { };
      };
      hostAddress = "10.0.0.1";
      localAddress = config.myModules.ips.ssl-proxy.ipv4.address;
      hostAddress6 = "fc00::1";
      localAddress6 = config.myModules.ips.ssl-proxy.ipv6.address;
    };
    kanidm = mkContainer {
      config = (import ./kanidm.nix);
      bindMounts."/var/lib/acme/auth.inckmann.de" = { };
      hostAddress = "10.0.0.3";
      localAddress = config.myModules.ips.kanidm.ipv4.address;
      hostAddress6 = "fc00::3";
      localAddress6 = config.myModules.ips.kanidm.ipv6.address;
    };
    headscale = mkContainer {
      config = (import ./headscale.nix);
      bindMounts."/var/lib/acme/headscale.inckmann.de" = { };
      hostAddress = "10.0.0.5";
      localAddress = config.myModules.ips.headscale.ipv4.address;
      hostAddress6 = "fc00::5";
      localAddress6 = config.myModules.ips.headscale.ipv6.address;
    };
    tailscale-exit = mkContainer {
      config = (import ./tailscale.nix);
      enableTun = true;
      bindMounts."/var/lib/tailscale/" = {
        isReadOnly = false;
        hostPath = "/var/lib/tailscale-exit-node";
      };
      hostAddress = "10.0.0.7";
      localAddress = config.myModules.ips.headscale.ipv4.address;
      hostAddress6 = "fc00::7";
      localAddress6 = config.myModules.ips.headscale.ipv6.address;
    };
  };

  myModules.autoUpgrade.enable = true;
  myModules.autoUpgrade.allowReboot = true;
  local.tailscale = {
    enable = true;
    server = true;
    accept-routes = false;
  };
  services.tailscale.extraSetFlags = [ "--accept-dns=false" ];
}
