{
  config,
  pkgs,
  sops,
  ...
}:{
  imports = [
    ../../modules/
  ];

  networking = {
    hostName = "headscale";
  };

  sops.secrets.headscale_oidc_client_secret = {
      sopsFile = ../secrets/headscale.yaml;
      owner = "headscale";
    };

  services.headscale = {
    enable = true;
    port = 443;
    address = "[::]";

    settings = {
      server_url = "https://headscale.inckmann.de";
      policy.path = ./headscale_acl.hujson;
      tls_letsencrypt_hostname = "headscale.inckmann.de";

      prefixes = {
        v4 = "10.1.0.0/16";
        v6 = "fd01:0001::/64";
      };

      dns = {
        override_local_dns = true;
        magic_dns = true;
        base_domain = "net.inckmann.de";
        search_domains = [ "localdomain" ];
        nameservers.global = config.myModules.internet-nameservers;
      };

      oidc = {
        # only_start_if_oidc_is_available = true;
        issuer = "https://auth.inckmann.de/oauth2/openid/${client_id}";
        client_id = "headscale";
        client_secret_path = config.sops.secrets.headscale_oidc_client_secret.path;
        scope = [ "openid" "profile" "email" "groups" ];
        allowed_groups = ["/family" "/friends" ];
        pkce.enabled = true;
      };
    };
  };
}
