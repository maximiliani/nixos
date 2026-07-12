{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.inckmann.fleet = {
    name = mkOption {
      type = types.str;
      default = "unknown";
      description = "Canonical node name in fleet inventory.";
    };

    region = mkOption {
      type = types.str;
      default = "unknown";
      description = "Logical region identifier used for routing and policy.";
    };

    roles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Role tags for this host (control-plane, relay, exit-node, site-gateway).";
    };

    publicHostname = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Primary public hostname for this node.";
    };

    privateCidrs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Private CIDRs originated by this node or site.";
    };
  };
}
