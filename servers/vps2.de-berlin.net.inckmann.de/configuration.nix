{ config, modulesPath, lib, pkgs, inputs, sops, self, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];

  # === Network Configuration ===
  networking = {
    hostName = "vps2-de-berlin";
    domain = "net.inckmann.de";
    enableIPv6 = true;
    nameservers = [ "1.1.1.1" "1.0.0.1" "9.9.9.9" "149.112.112.112" "2606:4700:4700::1111" "2606:4700:4700::1001" "2620:fe::fe" "2620:fe::9"];
    # === Firewall Configuration ===
    firewall = {
      allowPing = true;
      allowedTCPPorts = [ 80 443 ];  # ACME + HTTPS for Headscale
      allowedUDPPorts = [ 500 4500 51820 ];  # IPSec NAT-T/IKE + WireGuard
      # trustedInterfaces = [ "tailscale0" "wg-gateway" ];
    };
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

  # === Sops ===
  sops = {
    defaultSopsFile = self + /secrets/vps2-de-berlin/default.yaml;
    age = {
     keyFile = "/var/lib/sops-nix/key.txt";
     generateKey = true;
    };
    secrets = {
      headscale_oidc_client_secret = {
        sopsFile = self + /secrets/vps2-de-berlin/headscale.yaml;
        owner = "headscale";
      };
      admin_password = {
        sopsFile = self + /secrets/vps2-de-berlin/kanidm.yaml;
        owner = "kanidm";
      };
      idm_admin_password = {
        sopsFile = self + /secrets/vps2-de-berlin/kanidm.yaml;
        owner = "kanidm";
      };
      # wireguard_private_key = {
      #   sopsFile = self + /secrets/vps2-de-berlin/wireguard.yaml;
      # };
      # wireguard_gateway_preshared_key = {
      #   sopsFile = self + /secrets/vps2-de-berlin/wireguard.yaml;
      # };
      # ipsec_server_key = {
      #   sopsFile = self + /secrets/vps2-de-berlin/ipsec.yaml;
      # };
      # ipsec_server_cert = {
      #   sopsFile = self + /secrets/vps2-de-berlin/ipsec.yaml;
      # };
      # ipsec_ca_cert = {
      #   sopsFile = self + /secrets/vps2-de-berlin/ipsec.yaml;
      # };
    };
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  system.stateVersion = "25.11";
}
