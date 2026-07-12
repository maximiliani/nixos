{ config, lib, pkgs, ... }:
let
  inherit (lib) concatStringsSep escapeShellArg mkEnableOption mkIf mkOption types;
  cfg = config.inckmann.vpn.managedClient;
  upArgs = [
    "--login-server=${cfg.loginServer}"
  ] ++ cfg.extraUpFlags;
in
{
  options.inckmann.vpn.managedClient = {
    enable = mkEnableOption "managed VPN client baseline (Headscale/Tailscale-compatible)";

    package = mkOption {
      type = types.package;
      default = pkgs.tailscale;
      description = "Package providing tailscale and tailscaled.";
    };

    loginServer = mkOption {
      type = types.str;
      default = "https://vpn.net.inckmann.de";
      description = "Control-plane login server for managed client enrollment.";
    };

    extraUpFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra flags appended to the tailscale up helper command.";
    };

    owner = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Human owner label for this managed client node.";
    };
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      package = cfg.package;
      useRoutingFeatures = "client";
    };

    environment.systemPackages = [
      cfg.package
      (pkgs.writeShellScriptBin "vpn-client-up" ''
        exec ${cfg.package}/bin/tailscale up ${concatStringsSep " " (map escapeShellArg upArgs)} "$@"
      '')
    ];
  };
}
