{ config, lib, pkgs, ... }:
let
  domainName = "inckmann.de";
in
{
  sops.secrets.ionos.sopsFile = ../../secrets/vps2-de-berlin/acme.yaml;
  # users.users.acme = {
  #   uid = 995;
  #   group = "acme";
  #   isSystemUser = true;
  #   # home = "/var/lib/acme";
  # };
  # users.groups.acme.gid = 995;
  users.groups.nginx = { };
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "admin@inckmann.de";
      group = "nginx";
      dnsProvider = "ionos";
      environmentFile = config.sops.secrets.ionos.path;
    };
    certs = {
      "${domainName}" = {
        group = config.services.nginx.group;
        extraDomainNames = (map (subdomain: (if subdomain == "" then "" else "${subdomain}.") + "${domainName}")
          [
            ""
            "auth"
            "headscale"
            "newsticker.gsm"
            "db.newsticker.gsm"
            "vpn"
          ]
        );
#         postRun = ''
#           # set permission on dir
#           ${pkgs.acl}/bin/setfacl -m \
#           u:995:rx,u:nginx:rx,u:acme:rx \
#           /var/lib/acme/${domainName}
#
#           # set permission on key file
#           ${pkgs.acl}/bin/setfacl -m \
#           u:995:rwx,u:nginx:r,u:acme:r \
#           /var/lib/acme/${domainName}/*.pem
#         '';
        reloadServices = [
          "nginx"
          "headscale"
          "kanidm"
        ];
      };
    };
  };

}
