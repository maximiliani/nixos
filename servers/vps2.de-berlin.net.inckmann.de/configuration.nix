{ modulesPath, lib, pkgs, inputs, self, fleetNode, ... }:
let
  # Public networking from IONOS
  publicIpv4 = "87.106.81.219";
  publicIpv6Address = "2a01:239:469:4c00::1";
  publicIpv6Subnet = "2a01:239:469:4c00::/80";
  
  # VPN addressing - local ULA for internal networks
  vpnBaseIpv4 = "10.66.0.1";
  vpnBaseIpv6 = "fd66:6600::1";
  
  # Service addresses
  headscaleLocalIpv4 = "100.64.0.1";
  headscaleLocalIpv6 = "fd66:6601::1";
  headscalePublicIpv6 = "2a01:239:469:4c00::2";
  
  wireguardLocalIpv4 = "10.66.200.1";
  wireguardLocalIpv6 = "fd66:6602::1";
  wireguardPublicIpv6 = "2a01:239:469:4c00::3";
  
  ipsecPoolStartIpv4 = "10.66.210.1";
  ipsecPoolStartIpv6 = "2a01:239:469:4c00::10";
  
  stateDir = "/var/lib/inckmann-vpn-bootstrap";
  secretsDir = "${stateDir}/secrets";
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ../../modules/vpn
    ../../modules/identity
    ../../modules/networking
    ./bootstrap.nix
  ];
  
  # === Network Configuration ===
  networking = {
    hostName = "vps2-de-berlin";
    enableIPv6 = true;
    
    interfaces.eth0 = {
      ipv4.addresses = [{ address = publicIpv4; prefixLength = 32; }];
      ipv6.addresses = [
        { address = publicIpv6Address; prefixLength = 80; }
      ];
    };
    
    defaultGateway = {
      address = "87.106.81.1";
      interface = "eth0";
    };
    defaultGateway6 = {
      address = publicIpv6Address;
      interface = "eth0";
    };
    
    nameservers = [ "1.1.1.1" "1.0.0.1" "2606:4700:4700::1111" "2606:4700:4700::1001" ];
  };
  
  # === Headscale Server ===
  services.headscale = {
    enable = true;
    port = 443;
    address = "[::]";
    
    settings = {
      server_url = "https://vpn.net.inckmann.de";
      listen_addr = "0.0.0.0:8080";
      metrics_listen_addr = "127.0.0.1:9090";
      
      prefixes = {
        v4 = "100.64.0.0/10";
        v6 = "fd66:6601::/64";
      };
      
      dns = {
        override_local_dns = true;
        magic_dns = true;
        base_domain = "headscale.inckmann.de";
        nameservers = {
          global = [ "1.1.1.1" "2606:4700:4700::1111" ];
        };
      };
      
      oidc = {
        only_start_if_oidc_is_available = true;
        issuer = "https://auth.inckmann.de/realms/inckmann";
        client_id = "headscale";
        client_secret_path = "${secretsDir}/headscale-oidc-client-secret";
        scope = [ "openid" "profile" "email" "groups" ];
        allowed_groups = [ "/admins" "/family" "/friends" ];
      };
      
      policy.path = ./headscale_acl.hujson;
      tls_letsencrypt_hostname = "vpn.net.inckmann.de";
    };
  };
  
  # === WireGuard Gateway ===
  networking.wg-quick.interfaces.wg-gateway = {
    address = [
      "${wireguardLocalIpv4}/24"
      "${wireguardLocalIpv6}/64"
      "${wireguardPublicIpv6}/128"
    ];
    listenPort = 51820;
    privateKeyFile = "${secretsDir}/wireguard-private-key";
    peers = [
      # Add WireGuard peers here:
      # {
      #   publicKey = "...";
      #   allowedIPs = [ "10.66.200.2/32" "fd66:6602::2/128" ];
      #   presharedKeyFile = "${secretsDir}/wireguard-psk";
      #   persistentKeepalive = 25;
      # }
    ];
  };
  
  # === IPSec Gateway ===
  services.strongswan-swanctl = {
    enable = true;
    swanctl = {
      connections."ikev2-eap" = {
        version = 2;
        local_addrs = [ "%any" ];
        remote_addrs = [ "%any" ];
        pools = [ "ikev2-pool" ];
        proposals = [ "aes256-sha256-modp2048" ];
        
        local.main = {
          auth = "pubkey";
          id = "vpn.net.inckmann.de";
          certs = [ "${secretsDir}/ipsec-server-cert" ];
        };
        
        remote.main = {
          auth = "eap-mschapv2";
          eap_id = "%any";
        };
        
        children."net-all" = {
          local_ts = [ "0.0.0.0/0" "::/0" ];  # Full tunnel for exit node
          esp_proposals = [ "aes256-sha256" ];
          dpd_action = "restart";
        };
      };
      
      pools."ikev2-pool" = {
        addrs = "10.66.210.0/24";
        dns = [ "1.1.1.1" "2606:4700:4700::1111" ];
      };
      
      secrets.eap = {
        # Add IPSec EAP users here:
        # username = { id.main = "username"; secret = "password"; };
      };
    };
  };
  
  environment.etc."ipsec-gateway/ca.crt".source = "${secretsDir}/ipsec-ca-cert";
  
  # === Keycloak Identity Server ===
  inckmann.identity.keycloak = {
    enable = true;
    hostname = "auth.inckmann.de";
    localHttpPort = 8081;
    database.passwordFile = "${secretsDir}/keycloak-db-password";
  };
  
  # === Exit Node Configuration ===
  inckmann.vpn.exitNode = {
    enable = true;
    advertiseTags = [ "tag:vpn-gateway" ];
    advertiseRoutes = [ 
      "10.66.0.0/16"
      "fd66:6600::/64"
      "10.66.200.0/24"
      "fd66:6602::/64"
      "10.66.210.0/24"
      "fd66:6603::/64"
    ];
  };
  
  # === Firewall Configuration ===
  networking.firewall = {
    allowPing = true;
    allowedTCPPorts = [ 80 443 ];  # ACME + HTTPS for Headscale
    allowedUDPPorts = [ 500 4500 51820 ];  # IPSec NAT-T/IKE + WireGuard
    trustedInterfaces = [ "tailscale0" "wg-gateway" ];
  };
  
  # === Edge Proxy ===
  inckmann.networking.edgeProxy = {
    enable = true;
    targets = {
      "newsticker.gsm.inckmann.de".upstream = "10.66.0.20:8080";
      "db.newsticker.gsm.inckmann.de".upstream = "10.66.0.21:54321";
      "auth.inckmann.de".upstream = "127.0.0.1:8081";
    };
  };
  
  # === System Packages ===
  environment.systemPackages = with pkgs; [
    curl
    git
    gh
    ddate
    testdisk
    vim
    nano
    gnupg
    sops
    tailscale
    wireguard-tools
  ];
  
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  
  security.sudo.extraConfig = "Defaults env_keep += SSH_AUTH_SOCK";
  
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCfR8hq2XwnAtb/AF+9d22eusxlS79p8VjRzLMpvaJH+rc8IwKFQfdX+C4iNwjHa2abCZHcRsPXeH2YRvWuF5BQWEB1ocudWQvaz5qzUpD08WjRC2R/g/xvi4YAvMoE/vgmflMveGSn3C5wBc3PXUFqDLmUorKvA/db5lmmKAsqScHWdQVXksEVxCmcTgicq2wCgIT9CdVvHj1OGJnwUVdAJe6Rlapvg0n6UVWttnVUPH+FwvBd/H5ynAjdr+jZKOgb8+iP0ZhWql4DXqLNmxH8dV0Smm8J99n2tQiPaKwCBhJZ6wYoPLSqsJQttDJEooc9lmQ5PXCTrUJqsMK8lNbH cardno:15_418_505"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFVpt4Z5d+gu06m3/n7NsjcREUNdM8aVo7zaCrzmZcIQifNczStjj4BGE09jr/CpjwPRMRZSosL69od30U/mX0M= cardno:15_418_505"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDNiTQBygCYSnoDlz9yY22pW83soTtNdSsiln4AGSCyMyH4CW2gGcXjBgAuIbce0JEipCB6tat4XfnKstAWMrtVbAK5szObzsGgnY4Debw1AF0ypGvWUNgkWT52jp+LeKCNA+CjjczrW0GIiL6lKC4ZZVxxxHC0/Tq2fzhLx+A/bbTmohorTCGJP1NTKHGqP87KgN8z2RM0MQU3Q4yCkVwRoYcfYxcD8UsnXS9JP3yEJJ6RsWTSHARgMpHhFnIgInZv7cjsZnyc7E6L5v0/nzoVT6uCeCeRbreNmIg2J2gol+UIOvh59J1n5USOmghNE2GtFiHDSxDqKJs9EGbFtwDZJnLsAe0Erg9rrraG7NgxPB2oHbeHsIBo4Rf1MGfrrxz2vXhd31cPfl0S/q2hgjC7y2swZFWQ4kxL0A4Hu2NVRGKp+eyBRjRSNS4QLoLm0njLpF3mw50VNlq3Pc5Ar3n6ucSrqKuFC5imRrJQNOw6a4CXwmAgk9bjuOn6qxZgpDs= VPS Max Raoul"
  ];
  
  # === Sops (for future migration) ===
  # Currently disabled - secrets are generated by bootstrap at runtime
  # To migrate to sops-nix:
  # 1. Generate secrets locally and encrypt with sops
  # 2. Uncomment this section
  # 3. Set manageSopsSecrets = true for each service
  # 4. Remove /var/lib/inckmann-vpn-bootstrap/
  secrets = {
    headscale_oidc_client_secret = { 
      sopsFile = self + /secrets/vps2-de-berlin/headscale.yaml;
    };
    keycloak_db_password = { 
      sopsFile = self + /secrets/vps2-de-berlin/keycloak.yaml;
    };
    wireguard_gateway_private_key = { 
      sopsFile = self + /secrets/vps2-de-berlin/wireguard.yaml;
    };
    wireguard_gateway_preshared_key = { 
      sopsFile = self + /secrets/vps2-de-berlin/wireguard.yaml;
    };
    ipsec_gateway_server_key = { 
      sopsFile = self + /secrets/vps2-de-berlin/ipsec.yaml;
    };
    ipsec_gateway_server_cert = { 
      sopsFile = self + /secrets/vps2-de-berlin/ipsec.yaml;
    };
    ipsec_gateway_ca_cert = { 
      sopsFile = self + /secrets/vps2-de-berlin/ipsec.yaml;
    };
  };
  
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
  };
  
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  
  system.stateVersion = "25.11";
}
