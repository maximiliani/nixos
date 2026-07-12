let
  splitHostname = fqdn:
    let m = builtins.match "^([^.]+)\\.(.+)$" fqdn;
    in
    if m == null
    then { host = fqdn; domain = ""; }
    else {
      host = builtins.elemAt m 0;
      domain = builtins.elemAt m 1;
    };

  data = {
    name = "inckmann-fleet";
    defaultDomain = "net.inckmann.de";
    defaults = {
      role = "unassigned";
      privateCidrs = [ ];
      roles = [ ];
      tags = [ ];
      publicHostname = null;
      sshUser = "root";
    };

    nodes = {
      vps2-de-berlin = {
        region = "de-berlin";
        provider = "ionos";
        roles = [
          "vpn-control-plane"
          "vpn-relay"
          "vpn-exit-node"
          "vpn-site-gateway"
          "vpn-wireguard-gateway"
          "vpn-ipsec-gateway"
          "identity-provider"
          "edge-proxy"
        ];
        hostConfig = "servers/vps2.de-berlin.net.inckmann.de/configuration.nix";
        publicHostname = "vps2.de-berlin.net.inckmann.de";
        tags = [ "prod" "edge" "vpn-full-node" "bootstrap-capable" ];
        privateCidrs = [ "10.66.0.0/16" ];
      };

      mbp-2016 = {
        region = "de-home";
        provider = "local";
        roles = [ "client" ];
        hostConfig = "mbp-2016/configuration.nix";
        publicHostname = null;
        sshUser = "maximiliani";
        tags = [ "client" "maximilian" ];
        owner = "Maximilian Inckmann";
        vpnUser = "maximiliani";
      };
    };

    users = {
      maximilian = {
        displayName = "Maximilian Inckmann";
        groups = [ "admins" ];
        primaryDeviceNodes = [ "mbp-2016" ];
      };
    };

  };
in
data
// {
  getNode = nodeName:
    let
      raw = data.defaults // (data.nodes.${nodeName} or (throw "Unknown fleet node: ${nodeName}"));
      computedPublicHostname =
        if raw.publicHostname != null
        then raw.publicHostname
        else "${nodeName}.${data.defaultDomain}";
      parsed = splitHostname computedPublicHostname;
    in
    raw // {
      name = nodeName;
      publicHostname = computedPublicHostname;
      hostName = parsed.host;
      domain =
        if parsed.domain != ""
        then parsed.domain
        else data.defaultDomain;
    };
}
