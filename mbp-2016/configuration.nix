# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  modulesPath,
  lib,
  pkgs,
  config,
  inputs,
  ...
} @ args:

{
  networking.hostName = "mbp-2016"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "de_DE.UTF-8/UTF-8"
  ];

  i18n.extraLocaleSettings = {
    LANGUAGE = lib.mkDefault "en_US";
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "de";
    variant = "mac_nodeadkeys";
  };

  # Configure console keymap
  console.keyMap = "de";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.maximiliani = {
    isNormalUser = true;
    description = "Maximilian Inckmann";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
	  signal-desktop
	  keepassxc
	  podman
	  podman-desktop
	  jetbrains.webstorm
	  jetbrains.idea
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget
    curl
    vim
    nano
    git
    gh
    gnupg
    yubikey-personalization
  ];


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

  nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
    };
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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

  users.defaultUserShell = pkgs.zsh;
  environment.shells = with pkgs; [ zsh ];
  programs.zsh = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
      update = "sudo nixos-rebuild switch";
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
  security.pam.sshAgentAuth.enable = true;
  security.sudo.extraConfig = "Defaults env_keep += SSH_AUTH_SOCK";
  services.udev.packages = [ pkgs.yubikey-personalization ];  # Enable the OpenSSH daemon to use a YubiKey for SSH authentication.
}
