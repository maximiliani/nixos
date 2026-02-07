{ lib
, config
, pkgs
, ...
}:
let
  cfg = config.myModules.autoUpgrade;
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.myModules.autoUpgrade = {
    enable = mkEnableOption "Auto Upgrade";
    daysToKeep = mkOption {
      type = types.int;
      description = "Days to keep the generations for";
      default = 14;
    };
    delayForInternet = mkOption {
      type = types.bool;
      description = "Wait for the Internet to be up before trying to update. This is useful for Laptop. But it pings google.";
      default = false;
    };
    branch = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "An Optional branch to use for the updates";
      example = "dev";
    };
    allowReboot = mkOption {
      type = types.bool;
      default = false;
      description = "Allow to reboot the computer";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.gc = {
      automatic = lib.mkDefault true;
      options = "--delete-older-than ${toString cfg.daysToKeep}d";
    };
    system.autoUpgrade = {
      enable = true;
      flake =
        "git+https://github.com/maximiliani/nixos"
        + lib.optionalString (cfg.branch != null) "?ref=${cfg.branch}";
      allowReboot = lib.mkDefault cfg.allowReboot;
    };
    # Allow nixos-upgrade to restart on failure (e.g. when laptop wakes up before network connection is set)
    systemd.services.nixos-upgrade = lib.mkIf cfg.delayForInternet {
      preStart = "${pkgs.host}/bin/host google.com"; # Check network connectivity
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "120";
      };
      unitConfig = {
        StartLimitIntervalSec = 600;
        StartLimitBurst = 2;
      };
    };

  };
}
