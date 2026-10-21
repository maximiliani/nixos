{
  config,
  pkgs,
  sops,
  ...
}:{
  imports = [
    ../../modules
  ];

  networking = {
    hostName = "headscale";
  };

  sops.secrets.headscale_oidc_client_secret = {
      sopsFile = ../../secrets/vps2-de-berlin/headscale.yaml;
      owner = "headscale";
    };

  services.headscale = {
    enable = true;
    # The nginx proxy terminates TLS for headscale.inckmann.de (its vhost forwards
    # to http://10.0.0.6:8081), so headscale itself listens on plain HTTP here and
    # must NOT run its own ACME (no tls_letsencrypt_hostname). Port must match the
    # proxy's upstream target. server_url stays the public https:// URL.
    address = "0.0.0.0";
    port = 8081;

    settings = {
      server_url = "https://headscale.inckmann.de";
      policy.path = ./headscale_acl.hujson;

      prefixes = {
        v4 = "10.1.0.0/16";
        v6 = "fd01:0001::/64";
      };

      dns = rec {
        override_local_dns = true;
        magic_dns = true;
        base_domain = "net.inckmann.de";
        search_domains = [ "localdomain" ];
        nameservers.global = config.myModules.internet-nameservers;
      };

      oidc = rec {
        client_id = "headscale";
        issuer = "https://auth.inckmann.de/oauth2/openid/${client_id}";
        client_secret_path = config.sops.secrets.headscale_oidc_client_secret.path;
        # scope = [ "openid" "profile" "email" "groups" ];
        # allowed_groups = ["/family" "/friends" ];
        pkce.enabled = true;
      };
    };
  };
}
