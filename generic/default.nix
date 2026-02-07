{ config
, pkgs
, inputs
, lib
, ...
}:
let
  base = "/etc/nixpkgs/channels";
  nixpkgsPath = "${base}/nixpkgs";
  nixpkgs-unstablePath = "${base}/nixpkgs-unstable";
  nixpkgs-stablePath = "${base}/nixpkgs-stable";
  full = config.local.full;
in
{
  options.local = {
    stable = lib.mkOption {
      default = true;
      type = lib.types.bool;
    };
    full = lib.mkOption {
      description = "Enable non-neccesary options set to false if you have storage limits";
      default = true;
      type = lib.types.bool;
    };
  };

  config = {
    system.nixos.label = lib.mkIf (config.image ? baseName) config.networking.hostName;

    nix = {
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      optimise.automatic = true;
      registry = {
        nixpkgs.flake = inputs.nixpkgs-stable;
        nixpkgs-unstable.flake = inputs.nixpkgs;
        streamdeck.flake = inputs.streamdeck-obs;
      };
      nixPath = [
        "nixpkgs=${nixpkgsPath}"
        "nixpkgs-unstable=${nixpkgs-unstablePath}"
        "nixpkgs-stable=${nixpkgs-stablePath}"
      ];
    };
  };

  security.sudo.extraConfig = "Defaults env_keep += SSH_AUTH_SOCK";

  users.defaultUserShell = pkgs.zsh;
  environment.shells = with pkgs; [ zsh ];

  environment.systemPackages = with pkgs; [
    curl
    git
    gh
    vim
    nano
  ];

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  security.pam.sshAgentAuth.enable = true;

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

    #      oh-my-zsh = {
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
      ll = "ls -l";
      update = "sudo nixos-rebuild switch";
      update-server = "nixos-rebuild switch --flake ${config.system.autoUpgrade.flake} --refresh";
      upgrade = "nix flake update --commit-lock-file --flake /etc/nixos";
      nixos = "cd /etc/nixos";
      vi = "nvim ";
      sudo = "sudo "; # This allows aliases to work with sudo
    };
  };

  programs.gnupg.agent = {
    enable = true;
    #   enableSSHSupport = true;
  };
  hardware.gpgSmartcards.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  programs.ssh.startAgent = true;

}
