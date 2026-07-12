{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption optionals types;
  cfg = config.inckmann.vpn.managedClient;
in
{
  options.inckmann.vpn.managedClient = {
    enable = mkEnableOption "Join Headscale-managed tailnet as client";
    
    tags = mkOption {
      type = types.listOf types.str;
      default = [ "tag:client" ];
      description = "Tailscale tags to advertise for this client";
    };
    
    acceptRoutes = mkOption {
      type = types.bool;
      default = true;
      description = "Accept routes advertised by exit nodes";
    };
    
    loginServer = mkOption {
      type = types.str;
      default = "https://vpn.net.inckmann.de";
      description = "Headscale login server URL";
    };
  };
  
  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      extraUpFlags = [
        "--login-server=${cfg.loginServer}"
        "--advertise-tags=${lib.concatStringsSep "," cfg.tags}"
      ];
      extraSetFlags = [
        "--ssh"
      ] ++ optionals cfg.acceptRoutes [ "--accept-routes" ];
    };
  };
}
