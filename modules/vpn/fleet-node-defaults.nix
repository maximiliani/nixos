{ lib, fleetNode ? null, ... }:
let
  inherit (lib) mkDefault mkIf;
in
{
  config = mkIf (fleetNode != null) {
    networking.hostName = mkDefault fleetNode.hostName;
    networking.domain = mkDefault fleetNode.domain;

    inckmann.fleet = {
      name = mkDefault fleetNode.name;
      region = mkDefault fleetNode.region;
      roles = mkDefault fleetNode.roles;
      publicHostname = mkDefault fleetNode.publicHostname;
      privateCidrs = mkDefault fleetNode.privateCidrs;
    };
  };
}
