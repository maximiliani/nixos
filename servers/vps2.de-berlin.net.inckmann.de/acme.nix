{ config, lib, ... }:
{
  sops.secrets.ionos.sopsFile = ../secrets/vps2-de-berlin/acme.yaml;
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "admin@inckmann.de";
      group = "nginx";
      dnsProvider = "ionos";
      environmentFile = config.sops.secrets.ionos.path;
    };
    certs =
      (lib.genAttrs (map (subdomain: (if subdomain == "" then "" else "${subdomain}.") + "inckmann.de")
        [
          ""
          "auth"
          "headscale"
          "newsticker.gsm"
          "db.newsticker.gsm"
          "vpn"
        ]
      ) (n: { }))
  };

}
