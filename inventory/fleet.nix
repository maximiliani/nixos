let
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
      ipv4Address = null;
      ipv6Subnet = null;
      ipv6Gateway = null;
      vpnIpv4Base = null;
      vpnIpv6Base = null;
      headscaleIpv4 = null;
      headscaleIpv6 = null;
      wireguardIpv4 = null;
      wireguardIpv6 = null;
      ipsecPoolStartIpv4 = null;
      ipsecPoolStartIpv6 = null;
      wireguardPeers = [ ];
      ipsecEapUsers = { };
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
        
        # Public networking
        ipv4Address = "87.106.81.219";
        ipv6Subnet = "2a01:239:469:4c00::/80";
        ipv6Gateway = "2a01:239:469:4c00::1";
        
        # VPN addressing (local ULA)
        vpnIpv4Base = "10.66.0.1";
        vpnIpv6Base = "fd66:6600::1";
        
        # Service-specific addresses
        headscaleIpv4 = "100.64.0.1";
        headscaleIpv6 = "2a01:239:469:4c00::2";  # Public IPv6 for headscale
        wireguardIpv4 = "10.66.200.1";
        wireguardIpv6 = "2a01:239:469:4c00::3";  # Public IPv6 for WG
        ipsecPoolStartIpv4 = "10.66.210.1";
        ipsecPoolStartIpv6 = "2a01:239:469:4c00::10";  # Start of IPSec pool
        
        wireguardPeers = [ ];
        ipsecEapUsers = { };
      };

      t420 = {
        region = "de-home";
        provider = "local";
        roles = [ "client" ];
        hostConfig = "t420/configuration.nix";
        publicHostname = null;
        sshUser = "max";
        tags = [ "client" "maximilian" ];
        owner = "Maximilian Inckmann";
        vpnUser = "maximilian";
        
        # Headscale client address (CGNAT + ULA)
        headscaleIpv4 = "100.64.0.2";
        headscaleIpv6 = "fd66:6601::2";
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
        
        # Headscale client address (CGNAT + ULA)
        headscaleIpv4 = "100.64.0.3";
        headscaleIpv6 = "fd66:6601::3";
      };
    };

    users = {
      maximilian = {
        displayName = "Maximilian Inckmann";
        groups = [ "admins" ];
        primaryDeviceNodes = [ "mbp-2016" "t420" ];
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
    in
    raw // {
      name = nodeName;
      publicHostname = computedPublicHostname;
      hostName = raw.hostName or nodeName;
      domain = raw.domain or data.defaultDomain;
    };
  
  getVpnAddresses = nodeName:
    let
      node = data.nodes.${nodeName} or null;
    in
    if node == null then null else {
      headscale = {
        ipv4 = "100.64.0.0/10";
        ipv6 = node.headscaleIpv6 or "fd66:6601::/64";
      };
      wireguard = {
        server = node.wireguardIpv4 or "10.66.200.1";
        subnet = "10.66.200.0/24";
        ipv6Subnet = "fd66:6602::/64";
      };
      ipsec = {
        poolStartIpv4 = node.ipsecPoolStartIpv4 or "10.66.210.1";
        poolStartIpv6 = node.ipsecPoolStartIpv6 or "fd66:6603::1";
        subnet = "10.66.210.0/24";
        ipv6Subnet = "fd66:6603::/64";
      };
    };
}
