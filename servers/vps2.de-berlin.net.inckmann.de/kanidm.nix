{
  config,
  pkgs,
  sops,
  ...
}:
let
  secrets = config.sops.secrets;
  inherit (pkgs) fetchurl fetchzip;
  logos = {
    headscale = fetchurl {
      url = "https://github.com/juanfont/headscale/raw/refs/heads/main/docs/assets/logo/headscale3_header_stacked_left.svg";
      hash = "sha256-1W+e1cQXKb9izpmKws9OeX9NwoSHwCON/aoYzNbYU2w=";
    };
  };
in
{
  imports = [
    sops
    ../../modules
  ];
  networking = {
    hostName = "kanidm";
  };

  sops = {
    defaultSopsFile = ../../secrets/vps2-de-berlin/kanidm.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true; # generate key above if it does not exist yet (has to be added manually to .sops.yaml)
      sshKeyPaths = [ ];
    };
    secrets = {
      admin_password.owner = "kanidm";
      idm_admin_password.owner = "kanidm";
      headscale = {
        owner = "kanidm";
        sopsFile = ../../secrets/vps2-de-berlin/headscale.yaml;
      };
    };
  };

  users.users.kanidm = {
    uid = 999;
  };

  # environment.systemPackages = [ config.services.kanidm.package ];

  services.kanidm = {
    package = pkgs.kanidmWithSecretProvisioning_1_11;
    server = {
      enable = true;
      settings = {
        bindaddress = "0.0.0.0:443";
        ldapbindaddress = "0.0.0.0:3636";
        http_client_address_info.x-forward-for = [
          config.myModules.ips.ssl-proxy.ipv4.address
          config.myModules.ips.ssl-proxy.ipv6.address
        ];
        version = "2";
        domain = "auth.inckmann.de";
        origin = "https://auth.inckmann.de";
        tls_key = "/var/lib/acme/auth.inckmann.de/key.pem";
        tls_chain = "/var/lib/acme/auth.inckmann.de/fullchain.pem";
      };
    };

    provision = {
      enable = true;
      adminPasswordFile = secrets.admin_password.path;
      idmAdminPasswordFile = secrets.idm_admin_password.path;

      groups = {
        headscale = { };
        family = { };
        friends = { };
      };

      systems.oauth2 = {
        headscale_service = {
          displayName = "Headscale";
          imageFile = logos.headscale;
          originLanding = "https://headscale.inckmann.de/oidc/callback";
          originUrl = [ "https://headscale.inckmann.de/oidc/callback" ];
          basicSecretFile = secrets.headscale.path;
          scopeMaps.headscale = [
            "openid"
            "profile"
            "email"
          ];
        };

        persons = {
          raoul = {
            displayName = "Raoul";
            legalName = "Raoul Honermann";
            mailAddresses = [ "raoul@honermann.info" ];
            groups = [
              "headscale"
              "friends"
            ];
          };

          maximilian = {
            displayName = "Maximilian";
            legalName = "Maximilian Inckmann";
            mailAddresses = [ "maximilian@inckmann.de" ];
            groups = [
              "family"
              "friends"
              "headscale"
            ];
          };
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    443
    3636
  ];
  system.stateVersion = "26.05";
}
