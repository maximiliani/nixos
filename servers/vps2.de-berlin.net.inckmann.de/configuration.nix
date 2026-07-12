{ modulesPath
, lib
, pkgs
, inputs
, self
, ...
} @ args:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ../../modules/vpn
    ../../modules/identity
    ../../modules/networking
  ];
  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  inckmann.vpn = {
    headscaleControl = {
      enable = true;
      bootstrap.enable = true;
      manageSopsSecrets = false;
      dns.baseDomain = "headscale.inckmann.de";
      keycloakOidc = {
        enable = true;
        issuer = "https://auth.inckmann.de/realms/inckmann";
        clientId = "headscale";
      };
    };
    derpRelay.enable = false;
    exitNode.enable = false;
    siteGateway.enable = false;
    wireguardGateway = {
      enable = true;
      bootstrap.enable = true;
      manageSopsSecrets = false;
      listenPort = 51820;
      addresses = [ "10.66.200.1/24" ];
      presharedKeyFile = null;
      peers = [ ];
    };
    ipsecGateway = {
      enable = true;
      bootstrap.enable = true;
      manageSopsSecrets = false;
      serverId = "vpn.net.inckmann.de";
      poolCidr = "10.66.210.0/24";
      eapUsers = { };
    };
  };

  inckmann.identity.keycloak = {
    enable = true;
    bootstrap.enable = true;
    manageSopsSecrets = false;
    hostname = "auth.inckmann.de";
    localHttpPort = 8081;
  };

  inckmann.networking.edgeProxy = {
    enable = true;
    targets = {
      "newsticker.gsm.inckmann.de".upstream = "10.66.0.20:8080";
      "db.newsticker.gsm.inckmann.de".upstream = "10.66.0.21:54321";
      "auth.inckmann.de".upstream = "127.0.0.1:8081";
    };
  };

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
  ];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  security.sudo.extraConfig = "Defaults env_keep += SSH_AUTH_SOCK";

  # Enable the OpenSSH daemon
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCfR8hq2XwnAtb/AF+9d22eusxlS79p8VjRzLMpvaJH+rc8IwKFQfdX+C4iNwjHa2abCZHcRsPXeH2YRvWuF5BQWEB1ocudWQvaz5qzUpD08WjRC2R/g/xvi4YAvMoE/vgmflMveGSn3C5wBc3PXUFqDLmUorKvA/db5lmmKAsqScHWdQVXksEVxCmcTgicq2wCgIT9CdVvHj1OGJnwUVdAJe6Rlapvg0n6UVWttnVUPH+FwvBd/H5ynAjdr+jZKOgb8+iP0ZhWql4DXqLNmxH8dV0Smm8J99n2tQiPaKwCBhJZ6wYoPLSqsJQttDJEooc9lmQ5PXCTrUJqsMK8lNbH cardno:15_418_505"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFVpt4Z5d+gu06m3/n7NsjcREUNdM8aVo7zaCrzmZcIQifNczStjj4BGE09jr/CpjwPRMRZSosL69od30U/mX0M= cardno:15_418_505"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDNiTQBygCYSnoDlz9yY22pW83soTtNdSsiln4AGSCyMyH4CW2gGcXjBgAuIbce0JEipCB6tat4XfnKstAWMrtVbAK5szObzsGgnY4Debw1AF0ypGvWUNgkWT52jp+LeKCNA+CjjczrW0GIiL6lKC4ZZVxxxHC0/Tq2fzhLx+A/bbTmohorTCGJP1NTKHGqP87KgN8z2RM0MQU3Q4yCkVwRoYcfYxcD8UsnXS9JP3yEJJ6RsWTSHARgMpHhFnIgInZv7cjsZnyc7E6L5v0/nzoVT6uCeCeRbreNmIg2J2gol+UIOvh59J1n5USOmghNE2GtFiHDSxDqKJs9EGbFtwDZJnLsAe0Erg9rrraG7NgxPB2oHbeHsIBo4Rf1MGfrrxz2vXhd31cPfl0S/q2hgjC7y2swZFWQ4kxL0A4Hu2NVRGKp+eyBRjRSNS4QLoLm0njLpF3mw50VNlq3Pc5Ar3n6ucSrqKuFC5imRrJQNOw6a4CXwmAgk9bjuOn6qxZgpDs= VPS Max Raoul"
  ];

  system.stateVersion = "25.11";

  # Sops - kept for future migration
  sops = {
    defaultSopsFile = self + /secrets/vps2-de-berlin/default.yaml;
    age = {
     keyFile = "/var/lib/sops-nix/key.txt";
     generateKey = true;
    };
    secrets = {
      hello = { };
    };
  };
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };

  nix.registry.nixpkgs.flake = inputs.nixpkgs;
}
