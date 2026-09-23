{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib.types)
    bool
    str
    listOf
    nullOr
    ;
  inherit (lib) mkOption mkIf optional;
  cfg = config.local.tailscale;
  formatLists = prefix: list: (builtins.concatStringsSep "," (map (t: "${prefix}${t}") list));

  ipv4CidrRelaxStrict = "^([0-9]{1,3}\\.){3}[0-9]{1,3}/(3[0-2]|[12]?[0-9]|0)$";
  ipv6CidrRelaxStrict =
    "^(([0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}){0,7})"
    + "|(([0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}){0,6})?::"
    + "([0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}){0,6})?))"
    + "/(12[0-8]|1[01][0-9]|[1-9]?[0-9]|0)$";
  invalidIpCidrs =
    ips:
    builtins.filter (
      ip:
      (builtins.match ipv4CidrRelaxStrict ip == null) && (builtins.match ipv6CidrRelaxStrict ip == null)
    ) ips;
in
{
  options = {
    local.tailscale = {
      enable = mkOption {
        type = bool;
        default = false;
        description = "Ob tailscale auf diesem Host eingerichtet werden soll";
      };
      user = mkOption {
        type = str;
        default = "maximilian";
        description = "Unter welchem Nutzer dieser Host regestriert werden soll";
      };
      tags = mkOption {
        type = listOf str;
        default = [ ];
        description = "Tags die dem Host zugewiesen werden sollen";
      };
      exit-node = mkOption {
        type = bool;
        default = false;
        description = "Ob dieser client eine exit-node sein soll";
      };
      server = mkOption {
        type = bool;
        default = cfg.exit-node;
        description = "Ist dieser client ein server";
      };
      extern = mkOption {
        type = bool;
        default = false;
        description = "ist dies ein Externen Nutzer";
      };
      routes = mkOption {
        type = listOf str;
        default = [ ];
        description = "routes to advertise";
      };
      operator = mkOption {
        type = nullOr str;
        default = null;
        description = "operator who can control tailscale without sudo";
      };
      webclient = mkOption {
        type = bool;
        default = true;
        description = "Enable the webclient for management via the Browser";
      };
      accept-routes = mkOption {
        type = bool;
        default = true;
        description = "Accept advertised Routes";
      };
      ssh = mkOption {
        type = bool;
        default = true;
        description = "Enable the tailscale ssh Server";
      };
    };
  };
  config = mkIf cfg.enable rec {
    assertions = [
      {
        assertion = (invalidIpCidrs cfg.routes) == [ ];
        message = "config.local.tailscale.routes seams to contain a value which is not an ip addr with CIDR. Namely: ${builtins.concatStringsSep ", " (invalidIpCidrs cfg.routes)}";
      }
    ];
    sops = {
      secrets."${cfg.user}-auth-key".sopsFile = inputs.self + /secrets/tailscale.yaml;
    };
    local.tailscale.tags = optional cfg.server "server" ++ optional cfg.extern "extern";
    services.tailscale = {
      enable = cfg.enable;
      authKeyFile = config.sops.secrets."${cfg.user}-auth-key".path;
      openFirewall = true;
      extraUpFlags = [
        "--login-server=https://headscale.inckmann.de"
      ]
      ++ optional (cfg.tags != [ ]) "--advertise-tags=${formatLists "tag:" cfg.tags}";

      extraSetFlags =
        [ ]
        ++ optional cfg.exit-node "--advertise-exit-node"
        ++ optional cfg.webclient "--webclient"
        ++ optional cfg.accept-routes "--accept-routes"
        ++ optional cfg.ssh "--ssh"
        ++ optional (cfg.operator != null) "--operator=${cfg.operator}"
        ++ optional (cfg.routes != [ ]) "--advertise-routes=${formatLists "" cfg.routes}";
      useRoutingFeatures = if cfg.exit-node then "both" else "client";
    };
  };
}
