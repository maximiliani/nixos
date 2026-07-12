{ config, lib, fleetNode ? null, fleetInventory ? null, ... }:
let
  inherit (lib) concatStringsSep mkEnableOption mkIf;
  hasFleetContext = fleetNode != null && fleetInventory != null;
  peerNodeNames =
    if hasFleetContext
    then builtins.filter (nodeName: nodeName != fleetNode.name) (builtins.attrNames fleetInventory.nodes)
    else [ ];
  sshFleetConfig = concatStringsSep "\n" (map
    (nodeName:
      let node = fleetInventory.getNode nodeName;
      in ''
        Host ${nodeName} ${node.hostName}
          HostName ${node.publicHostname}
          User ${node.sshUser}
      '')
    peerNodeNames);
in
{
  options.inckmann.fleet.sshAliases.enable = mkEnableOption "fleet-derived SSH aliases";

  config = mkIf (hasFleetContext && config.inckmann.fleet.sshAliases.enable) {
    programs.ssh.extraConfig = sshFleetConfig;
  };
}
