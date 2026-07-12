{ config, lib, pkgs, ... }:
let
  stateDir = "/var/lib/inckmann-vpn-bootstrap";
  secretsDir = "${stateDir}/secrets";
in
{
  systemd.services.inckmann-vpn-bootstrap = {
    description = "Generate all VPN secrets for vps2-de-berlin";
    wantedBy = [ "multi-user.target" ];
    before = [ 
      "headscale.service" 
      "keycloak.service" 
      "wg-quick-wg-gateway.service" 
      "strongswan-swanctl.service"
      "tailscaled.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.coreutils pkgs.openssl pkgs.wireguard-tools ];
    script = ''
      set -euo pipefail
      umask 077
      
      mkdir -p ${secretsDir}
      
      # === Headscale OIDC Client Secret ===
      if [ ! -s "${secretsDir}/headscale-oidc-client-secret" ]; then
        openssl rand -base64 36 > "${secretsDir}/headscale-oidc-client-secret"
        echo "Generated Headscale OIDC client secret"
      fi
      
      # === Keycloak DB Password ===
      if [ ! -s "${secretsDir}/keycloak-db-password" ]; then
        openssl rand -base64 36 > "${secretsDir}/keycloak-db-password"
        echo "Generated Keycloak DB password"
      fi
      
      # === WireGuard Private Key ===
      if [ ! -s "${secretsDir}/wireguard-private-key" ]; then
        wg genkey > "${secretsDir}/wireguard-private-key"
        echo "Generated WireGuard private key"
      fi
      
      # === WireGuard Preshared Key ===
      if [ ! -s "${secretsDir}/wireguard-psk" ]; then
        openssl rand -base64 32 > "${secretsDir}/wireguard-psk"
        echo "Generated WireGuard preshared key"
      fi
      
      # === IPSec CA + Server Certificates ===
      if [ ! -s "${secretsDir}/ipsec-ca-cert" ]; then
        tmpdir=$(mktemp -d)
        trap 'rm -rf "$tmpdir"' EXIT
        
        echo "Generating IPSec CA certificate..."
        openssl genrsa -out "$tmpdir/ca.key" 4096
        openssl req -x509 -new -nodes -key "$tmpdir/ca.key" -sha256 -days 3650 \
          -subj "/CN=Inckmann VPN CA" \
          -out "${secretsDir}/ipsec-ca-cert"
        
        echo "Generating IPSec server key and certificate..."
        openssl genrsa -out "${secretsDir}/ipsec-server-key" 4096
        openssl req -new -key "${secretsDir}/ipsec-server-key" \
          -subj "/CN=vpn.net.inckmann.de" \
          -out "$tmpdir/server.csr"
        openssl x509 -req -in "$tmpdir/server.csr" \
          -CA "${secretsDir}/ipsec-ca-cert" \
          -CAkey "$tmpdir/ca.key" \
          -CAcreateserial \
          -out "${secretsDir}/ipsec-server-cert" \
          -days 825 -sha256
        
        chmod 0600 "${secretsDir}/ipsec-server-key"
        chmod 0600 "${secretsDir}/ipsec-server-cert"
        chmod 0600 "${secretsDir}/ipsec-ca-cert"
        echo "Generated IPSec certificates"
      fi
      
      # === Tailscale Auth Key (placeholder) ===
      if [ ! -s "${secretsDir}/tailscale-auth-key" ]; then
        cat > "${secretsDir}/tailscale-auth-key" <<'EOF'
PLACEHOLDER: Run 'tailscale login --login-server=https://vpn.net.inckmann.de' manually
Then save the auth key to this file and restart tailscaled
EOF
        echo "Created placeholder for Tailscale auth key - manual intervention required"
      fi
      
      touch "${stateDir}/.generated"
      echo "Bootstrap complete!"
    '';
  };
}
