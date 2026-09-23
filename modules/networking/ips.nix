{ lib, ... }:
let
  inherit (lib) types mkOption;
  inherit (types) submodule;
  addrOpts =
    v:
    assert v == 4 || v == 6;
    {
      options = {
        address = mkOption {
          type = types.str;
          description = ''IPv${toString v} address of the interface. Leave empty to configure the interface using DHCP.'';
        };

        prefixLength = mkOption {
          type = types.ints.between 0 (if v == 4 then 32 else 128);
          description = ''Subnet mask of the interface, specified as the number of bits in the prefix (`${if v == 4 then "24" else "64"}`).'';
          default = if v == 4 then 24 else 48;
        };
      };
    };
in
{
  options.myModules.ips = mkOption {
    type = types.attrsOf (
      types.submodule ({
        options = {
          ipv4 = mkOption {
            type = submodule (addrOpts 4);
            description = "IPv4 address for the server.";
          };
          ipv6 = mkOption {
            type = submodule (addrOpts 6);
            description = "IPv6 address for the server.";
          };
        };
      })
    );
    description = "Configuration for local IPs, including servers";
  };

  config = {
    myModules.ips = rec {
      cloudflare = {
        ipv4.address = "1.1.1.1";
        ipv6.address = "2606:4700:4700::1001";
      };
      vps2-de-berlin = {
        ipv4 = {
          address = "87.106.81.219";
          prefixLength = "32";
        };
        ipv6 = {
          address = "2a01:239:469:4c00::1";
          prefixLength = 128;
        };
      };
      ssl-proxy = {
        ipv4.address = "10.0.0.2";
        ipv6.address = "fc00::2";
      };
      kanidm = {
        ipv4.address = "10.0.0.4";
        ipv6.address = "fc00::4";
      };
      headscale = {
        ipv4.address = "10.0.0.6";
        ipv6.address = "fc00::6";
      };
      tailscale-exit-vps2-de-berlin = {
        ipv4.address = "10.0.0.8";
        ipv6.address = "fc00::8";
      }
    };
  };
  myModules.internet-nameservers = [
    # Cloudflare
    "1.1.1.1"
    "1.0.0.1"
    "2606:4700:4700::1111"
    "2606:4700:4700::1001"
    # Quad9
    "9.9.9.9"
    "149.112.112.112"
    "2620:fe::fe"
    "2620:fe::9"
  ];
}
