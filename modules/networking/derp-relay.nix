{ config, lib, pkgs, ... }:
let
  inherit (lib) concatStringsSep mkEnableOption mkIf mkOption optionals types;
  cfg = config.inckmann.vpn.derpRelay;
in
{
  options.inckmann.vpn.derpRelay = {
    enable = mkEnableOption "DERP relay service";

    package = mkOption {
      type = types.package;
      default = pkgs.tailscale;
      description = "Package providing the derper binary.";
    };

    hostname = mkOption {
      type = types.str;
      default = "relay.net.inckmann.de";
      description = "Public relay hostname announced to clients.";
    };

    port = mkOption {
      type = types.port;
      default = 443;
      description = "DERP listener port.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open relay TCP port in firewall.";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra derper CLI args (for cert mode, STUN, etc.).";
    };
  };

  config = mkIf cfg.enable {
    users.groups.derper = { };
    users.users.derper = {
      isSystemUser = true;
      group = "derper";
      home = "/var/lib/derper";
      createHome = true;
    };

    systemd.services.derper = {
      description = "Tailscale DERP relay";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "derper";
        Group = "derper";
        Restart = "on-failure";
        RestartSec = "5s";
        WorkingDirectory = "/var/lib/derper";
        ExecStart = "${cfg.package}/bin/derper -a :${toString cfg.port} -hostname ${cfg.hostname} ${concatStringsSep " " cfg.extraArgs}";
      };
    };

    networking.firewall.allowedTCPPorts = optionals cfg.openFirewall [ cfg.port ];
    environment.systemPackages = [ cfg.package ];
  };
}
