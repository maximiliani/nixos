{ config, lib, pkgs, ... }:
let
  domainName = "inckmann.de";
in
{
  sops.secrets.ionos.sopsFile = ../../secrets/vps2-de-berlin/acme.yaml;
  # The acme systemd units run as User=acme/Group=acme. Declaring them here (with a
  # fixed uid/gid so the proxy/headscale/kanidm containers can share /var/lib/acme)
  # guarantees the acme group exists on the host; the security.acme module alone does
  # not always (re)create it on this box.
  users.users.acme = {
    uid = 995;
    group = "acme";
    isSystemUser = true;
    home = "/var/lib/acme";
  };
  users.groups.acme.gid = 995;
  users.groups.nginx = { };
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "admin@inckmann.de";
      group = "nginx";
      dnsProvider = "ionos";
      environmentFile = config.sops.secrets.ionos.path;
    };
    certs = lib.genAttrs (map (subdomain: (if subdomain == "" then "" else "${subdomain}.") + "${domainName}")
      [
        ""
        "auth"
        "headscale"
        "newsticker.gsm"
        "db.newsticker.gsm"
        "vpn"
      ]
    ) (
      n: { }
    ) // {
      # headscale + kanidm/proxy load their certs from per-domain directories that
      # are bind-mounted into the containers (see container.nix), so each entry
      # above must stay a separate ACME cert (not SANs of one cert).
      "${domainName}".reloadServices = [
        "nginx"
        "headscale"
        "kanidm"
      ];
    };
  };

}
