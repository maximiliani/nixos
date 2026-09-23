{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:
let
  base = "/etc/nixpkgs/channels";
  nixpkgsPath = "${base}/nixpkgs";
in
{
  imports = [
    ./sops.nix
    ./localization.nix
    ./autoUpgrade.nix
    ./networking
  ];
  config = {
    system.nixos.label = lib.mkIf (config.image ? baseName) config.networking.hostName;

    nix = {
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      optimise.automatic = true;
      registry = inputs.nixpkgs;
      nixPath = [
        "nixpkgs=${nixpkgsPath}"
      ];
    };

    security.sudo.extraConfig = "Defaults env_keep += SSH_AUTH_SOCK";

    systemd.tmpfiles.rules = [
      "L+ ${nixpkgsPath}     - - - - ${inputs.nixpkgs}"
    ];

    networking = {
      domain = "net.inckmann.de";
      enableIPv6 = true;
      nameservers = config.myModules.internet-nameservers;
      firewall.allowPing = true;
    };

    users.defaultUserShell = pkgs.zsh;
    environment.shells = with pkgs; [ zsh ];

    sops.secrets.nixAccessTokens = {
      mode = "0440";
      group = config.users.groups.keys.name;
    };

    environment.systemPackages = with pkgs; [
      git
      pciutils
      usbutils
      curl
      ddate
      testdisk
      vim
      nano
      gnupg
      sops
    ];

    fonts = {
      enableDefaultPackages = true;

      packages = with pkgs; [
        meslo-lgs-nf
      ];

      fontconfig.defaultFonts = {
        serif = [ "MesloLGS NF Regular" ];
        sansSerif = [ "MesloLGS NF Regular" ];
        monospace = [ "MesloLGS NF Monospace" ];
      };
    };

    programs.zsh = {
      enable = true;

      ohMyZsh = {
        enable = true;
        customPkgs = with pkgs; [
          omz-nix-shell
          omz-powerlevel10k
          zsh-you-should-use
        ];
        plugins = [
          "git"
          "sudo"
          "nix-shell"
          "you-should-use"
        ];
        theme = "powerlevel10k/powerlevel10k";
      };
      shellAliases = {
        ll = "ls -al";
        update = "sudo nixos-rebuild switch";
        update-server = lib.mkIf (
          config.system.autoUpgrade.flake != null
        ) "nixos-rebuild switch --flake ${config.system.autoUpgrade.flake} --refresh";
        upgrade = "nix flake update --commit-lock-file --flake /etc/nixos";
        nixos = "cd /etc/nixos";
        vi = "nvim ";
        sudo = "sudo "; # This allows aliases to work with sudo
      };
    };

    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    hardware.gpgSmartcards.enable = true;

    # List services that you want to enable:

    # Enable the OpenSSH daemon.
    services.openssh.enable = true;
    programs.ssh.startAgent = true;
  };
}
