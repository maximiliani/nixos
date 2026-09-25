{
  lib,
  config,
  ...
}:
let
  ips = config.myModules.ips;

  proxyHost =
    name:
    {
      address,
      proxyWebsockets ? false,
      extraConfig ? "",
      serverAliases ? [ ],
    }:
    let
      acmePath = "/var/lib/acme/${name}";
    in
    {
      inherit serverAliases extraConfig;
      sslCertificate = "${acmePath}/fullchain.pem";
      sslCertificateKey = "${acmePath}/key.pem";
      sslTrustedCertificate = "${acmePath}/chain.pem";
      forceSSL = true;
      http2 = true;
      locations."/" = {
        proxyPass = address;
        inherit proxyWebsockets;
      };
    };
  inherit (lib) mapAttrs;
in
{
  imports = [ ../../modules ];

  #reverse proxy
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    #hardened security settings
    # Only allow PFS-enabled ciphers with AES256
    sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";
    #enable HSTS and other hardening (see nixos wiki)
    appendHttpConfig = ''
      map $scheme $hsts_header {
          https   "max-age=31536000; includeSubdomains; preload";
      }
      more_set_headers 'Strict-Transport-Security: $hsts_header';
      more_set_headers 'Referrer-Policy: strict-origin-when-cross-origin';
      more_set_headers 'X-Frame-Options: SAMEORIGIN';
      more_set_headers 'X-Content-Type-Options: nosniff';
      proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
    '';

    virtualHosts = mapAttrs proxyHost {
      "auth.inckmann.de" = {
        address = "https://${ips.kanidm.ipv4.address}";
      };

      "headscale.inckmann.de" = {
        address = "http://${ips.headscale.ipv4.address}:8081";
        proxyWebsockets = true;
      };
    };
  };

  networking = {
    hostName = "ssl-proxy";
    enableIPv6 = true;
    useHostResolvConf = false;
    tempAddresses = "disabled";
    firewall = {
      allowPing = true;
      allowedTCPPorts = [
        80
        443
      ];
      #enable = lib.mkForce false;
    };
  };
  system.stateVersion = "26.05";
}
