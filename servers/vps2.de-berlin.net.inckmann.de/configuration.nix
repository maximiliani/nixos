{ config, modulesPath, lib, pkgs, inputs, self, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];

  # The auto-connect unit `tailscaled-autoconnect.service` was introduced by an
  # earlier revision of this config and removed since, but its generated unit
  # file survives across generations in /etc/systemd/system. Mask it persistently
  # here (in the highest-precedence /etc/systemd/system dir, so it survives
  # reboots and is honored at switch time) — the stale file is in read-only store
  # space. Also pre-create the per-domain ACME cert dirs that the headscale/kanidm
  # containers bind-mount, so systemd-nspawn can clone them before ACME runs.
  systemd.tmpfiles.rules = [
    "L+ /etc/systemd/system/tailscaled-autoconnect.service - - - - /dev/null"
    "d /var/lib/acme/auth.inckmann.de 0750 acme nginx -"
    "d /var/lib/acme/headscale.inckmann.de 0750 acme nginx -"
  ];

  # The tailscale-exit container uses enableTun = true, which needs the tun
  # kernel module and a working /dev/net/tun on the host.
  boot.kernelModules = [ "tun" ];

  # === Network Configuration ===
  networking = {
    hostName = "vps2-de-berlin";
    domain = "net.inckmann.de";
    enableIPv6 = true;
    nameservers = config.myModules.internet-nameservers;
    # === Firewall Configuration ===
    firewall = {
      allowPing = true;
      allowedTCPPorts = [ 80 443 ];  # ACME + HTTPS for Headscale
      allowedUDPPorts = [ 500 4500 51820 ];  # IPSec NAT-T/IKE + WireGuard
      # trustedInterfaces = [ "tailscale0" "wg-gateway" ];
    };
    # Port forwarding for the proxy/headscale/exit containers is declared in
    # container.nix (with loopbackIPs for internal hosts reaching their own URL).
  };

  # === System Packages ===
  environment.systemPackages = with pkgs; [
    curl
    git
    gh
    ddate
    testdisk
    vim
    nano
    gnupg
    sops
    openssl
    tailscale
    wireguard-tools
  ];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  security.sudo.extraConfig = "Defaults env_keep += SSH_AUTH_SOCK";

  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCfR8hq2XwnAtb/AF+9d22eusxlS79p8VjRzLMpvaJH+rc8IwKFQfdX+C4iNwjHa2abCZHcRsPXeH2YRvWuF5BQWEB1ocudWQvaz5qzUpD08WjRC2R/g/xvi4YAvMoE/vgmflMveGSn3C5wBc3PXUFqDLmUorKvA/db5lmmKAsqScHWdQVXksEVxCmcTgicq2wCgIT9CdVvHj1OGJnwUVdAJe6Rlapvg0n6UVWttnVUPH+FwvBd/H5ynAjdr+jZKOgb8+iP0ZhWql4DXqLNmxH8dV0Smm8J99n2tQiPaKwCBhJZ6wYoPLSqsJQttDJEooc9lmQ5PXCTrUJqsMK8lNbH cardno:15_418_505"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFVpt4Z5d+gu06m3/n7NsjcREUNdM8aVo7zaCrzmZcIQifNczStjj4BGE09jr/CpjwPRMRZSosL69od30U/mX0M= cardno:15_418_505"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDNiTQBygCYSnoDlz9yY22pW83soTtNdSsiln4AGSCyMyH4CW2gGcXjBgAuIbce0JEipCB6tat4XfnKstAWMrtVbAK5szObzsGgnY4Debw1AF0ypGvWUNgkWT52jp+LeKCNA+CjjczrW0GIiL6lKC4ZZVxxxHC0/Tq2fzhLx+A/bbTmohorTCGJP1NTKHGqP87KgN8z2RM0MQU3Q4yCkVwRoYcfYxcD8UsnXS9JP3yEJJ6RsWTSHARgMpHhFnIgInZv7cjsZnyc7E6L5v0/nzoVT6uCeCeRbreNmIg2J2gol+UIOvh59J1n5USOmghNE2GtFiHDSxDqKJs9EGbFtwDZJnLsAe0Erg9rrraG7NgxPB2oHbeHsIBo4Rf1MGfrrxz2vXhd31cPfl0S/q2hgjC7y2swZFWQ4kxL0A4Hu2NVRGKp+eyBRjRSNS4QLoLm0njLpF3mw50VNlq3Pc5Ar3n6ucSrqKuFC5imRrJQNOw6a4CXwmAgk9bjuOn6qxZgpDs= VPS Max Raoul"
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  system.stateVersion = "25.11";
}
