# NixOS configurations

## Adding new hosts to SOPS

Modify `.sops.yaml` and add host key groups, then create `secrets/<hostname>/default.yaml`.

Example:

```yaml
keys:
  - &<hostname> age1...
creation_rules:
  - path_regex: ^secrets/<hostname>/.*$
    key_groups:
      - pgp:
          - *admin
        age:
          - *<hostname>
```

```bash
mkdir -p secrets/<hostname>
sops edit secrets/<hostname>/default.yaml
```

On another trusted host:

```bash
export SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt
find secrets -name "*" -type f -exec sops updatekeys {} -y \;
```

## VPN Infrastructure

### Architecture

This fleet uses a multi-VPN architecture with Headscale as the primary control plane:

- **Headscale/Tailscale**: Primary mesh network with ACL-based access control
- **WireGuard**: High-performance site-to-site tunnels (optional)
- **IPSec (IKEv2)**: Mobile client support (iOS/Android native) (optional)
- **Exit Node**: VPS-2 provides internet exit via all VPN technologies

All VPN technologies route through a unified intranet with both IPv4 and IPv6 support.

### Addressing

| Network | IPv4 | IPv6 (ULA) | IPv6 (Public) |
|---------|------|------------|---------------|
| VPS-2 Public | `87.106.81.219/32` | - | `2a01:239:469:4c00::1/80` |
| Intranet Gateway | `10.66.0.1/16` | `fd66:6600::1/64` | - |
| Headscale Server | `100.64.0.1/10` | `fd66:6601::1/64` | `2a01:239:469:4c00::2/128` |
| WireGuard Server | `10.66.200.1/24` | `fd66:6602::1/64` | `2a01:239:469:4c00::3/128` |
| IPSec Pool Start | `10.66.210.1/24` | `fd66:6603::1/64` | `2a01:239:469:4c00::10/128` |

**Client Addresses:**
- t420: `100.64.0.2` (IPv4), `fd66:6601::2` (IPv6 ULA)
- mbp-2016: `100.64.0.3` (IPv4), `fd66:6601::3` (IPv6 ULA)

### Traffic Flow

```
                    Internet
                       ↑
              [VPS-2 Exit Node]
         (87.106.81.219 / 2a01:239:469:4c00::1)
              /    |    \
     Headscale  WireGuard  IPSec
         ↓          ↓         ↓
    [Intranet 10.66.0.0/16 + fd66:6600::/64]
         ↓
    [t420, mbp-2016 clients]
```

- **Default routing**: Headscale is preferred for inter-client traffic
- **Exit node**: All traffic to `autogroup:internet` routes through VPS-2
- **Intranet**: Direct routing between `10.66.0.0/16` and `fd66:6600::/64`

---

## Initial Setup (VPS-2)

### 1. Deploy configuration

```bash
# From your local machine
git push

# SSH into VPS-2
ssh root@vps2.de-berlin.net.inckmann.de

# Deploy
sudo nixos-rebuild switch --flake .#vps2-de-berlin
```

### 2. Bootstrap generates secrets automatically

The bootstrap service runs on first boot and generates:
- `/var/lib/inckmann-vpn-bootstrap/secrets/headscale-oidc-client-secret`
- `/var/lib/inckmann-vpn-bootstrap/secrets/keycloak-db-password`
- `/var/lib/inckmann-vpn-bootstrap/secrets/wireguard-private-key`
- `/var/lib/inckmann-vpn-bootstrap/secrets/wireguard-psk`
- `/var/lib/inckmann-vpn-bootstrap/secrets/ipsec-ca-cert`
- `/var/lib/inckmann-vpn-bootstrap/secrets/ipsec-server-key`
- `/var/lib/inckmann-vpn-bootstrap/secrets/ipsec-server-cert`

### 3. Login to Tailscale/Headscale

```bash
# Get auth URL
tailscale login --login-server=https://vpn.net.inckmann.de

# Open URL in browser, authenticate via Keycloak OIDC
# Copy the auth key and save it:
echo "tskey-auth-..." > /var/lib/inckmann-vpn-bootstrap/secrets/tailscale-auth-key
sudo systemctl restart tailscaled
```

### 4. Approve tags and routes

In Headscale admin console (`https://vpn.net.inckmann.de/web`):
- Approve `tag:vpn-gateway` for vps2-de-berlin
- Approve advertised routes: `10.66.0.0/16`, `fd66:6600::/64`
- Mark as exit node

### 5. Verify services

```bash
systemctl status headscale
systemctl status keycloak
systemctl status tailscaled
systemctl status wg-quick-wg-gateway
systemctl status strongswan-swanctl
```

---

## ACL Tags and Access Control

Access is controlled via `headscale_acl.hujson`:

| Tag | Purpose | Members |
|-----|---------|---------|
| `tag:vpn-gateway` | VPN infrastructure | vps2-de-berlin |
| `tag:client` | Regular client devices | t420, mbp-2016 |
| `tag:service` | Internal services | (future services) |

**Groups:**
- `group:admins`: `maximilian@inckmann.de` - full access
- `group:fleet-nodes`: All enrolled devices

**ACL Rules:**
- Admins → vpn-gateway: full access
- Clients → services: allowed
- Everyone → `autogroup:internet`: exit node access
- Self → self: device self-access
- Members → intranet (`10.66.0.0/16`, `fd66:6600::/64`): full intranet access

---

## Adding WireGuard Peers

Edit `inventory/fleet.nix` and add to `vps2-de-berlin.wireguardPeers`:

```nix
wireguardPeers = [
  {
    name = "fritzbox-home";
    ipv4 = "10.66.200.2";
    ipv6 = "fd66:6602::2";
    publicKey = "generate-with-wg genkey | wg pubkey";
  }
];
```

Then update `servers/vps2.de-berlin.net.inckmann.de/configuration.nix`:

```nix
networking.wg-quick.interfaces.wg-gateway.peers = [
  {
    publicKey = "...";  # From fleet
    allowedIPs = [ "10.66.200.2/32" "fd66:6602::2/128" ];
    presharedKeyFile = "/var/lib/inckmann-vpn-bootstrap/secrets/wireguard-psk";
    persistentKeepalive = 25;
  }
];
```

Deploy: `sudo nixos-rebuild switch --flake .#vps2-de-berlin`

**Client configuration** (e.g., Fritz!Box or other WireGuard client):
```ini
[Interface]
PrivateKey = <client-private-key>
Address = 10.66.200.2/24, fd66:6602::2/64
DNS = 1.1.1.1, 2606:4700:4700::1111

[Peer]
PublicKey = <vps2-server-public-key>
PresharedKey = <psk-from-secrets>
Endpoint = vpn.net.inckmann.de:51820
AllowedIPs = 0.0.0.0/0, ::/0  # Full tunnel via exit node
PersistentKeepalive = 25
```

---

## Adding IPSec EAP Users

Edit `inventory/fleet.nix` and add to `vps2-de-berlin.ipsecEapUsers`:

```nix
ipsecEapUsers = {
  maximilian = "secure-password-here";
};
```

Update `servers/vps2.de-berlin.net.inckmann.de/configuration.nix`:

```nix
services.strongswan-swanctl.swanctl.secrets.eap = {
  maximilian = {
    id.main = "maximilian";
    secret = "secure-password-here";
  };
};
```

Deploy: `sudo nixos-rebuild switch --flake .#vps2-de-berlin`

**Client configuration** (iOS/Android/Windows native IKEv2):
- Server: `vpn.net.inckmann.de`
- Remote ID: `vpn.net.inckmann.de`
- Username: `maximilian`
- Password: (from ipsecEapUsers)
- CA Certificate: Import from `/var/lib/inckmann-vpn-bootstrap/secrets/ipsec-ca-cert`

---

## Client Enrollment

### NixOS Clients (t420, mbp-2016)

Already configured via `inckmann.vpn.managedClient` module. Just deploy:

```bash
sudo nixos-rebuild switch --flake .#t420
# or
sudo nixos-rebuild switch --flake .#mbp-2016
```

Login when prompted:
```bash
tailscale login --login-server=https://vpn.net.inckmann.de
```

### Non-NixOS Clients

Install Tailscale, then:

```bash
tailscale up --login-server https://vpn.net.inckmann.de
```

Authenticate via Keycloak OIDC in browser.

---

## Migrating to Sops-Nix

When ready to migrate from bootstrap to sops-nix:

### 1. Generate secrets locally

```bash
cd /Users/maximilian/GitHub/nixos

# Headscale OIDC secret
cat > secrets/vps2-de-berlin/headscale.yaml <<EOF
headscale_oidc_client_secret: $(openssl rand -base64 36)
EOF

# Keycloak DB password
cat > secrets/vps2-de-berlin/keycloak.yaml <<EOF
keycloak_db_password: $(openssl rand -base64 36)
EOF

# WireGuard private key
cat > secrets/vps2-de-berlin/wireguard.yaml <<EOF
wireguard_gateway_private_key: $(wg genkey)
EOF

# WireGuard PSK
cat > secrets/vps2-de-berlin/wireguard-psk.yaml <<EOF
wireguard_gateway_preshared_key: $(openssl rand -base64 32)
EOF
```

### 2. Encrypt with sops

```bash
sops -e -i secrets/vps2-de-berlin/headscale.yaml
sops -e -i secrets/vps2-de-berlin/keycloak.yaml
sops -e -i secrets/vps2-de-berlin/wireguard.yaml
sops -e -i secrets/vps2-de-berlin/wireguard-psk.yaml
```

For IPSec certs, copy from bootstrap and encode:
```bash
# On VPS-2
cat /var/lib/inckmann-vpn-bootstrap/secrets/ipsec-server-key | base64 -w0
# Add to YAML with proper formatting, then encrypt
```

### 3. Update configuration

In `servers/vps2.de-berlin.net.inckmann.de/configuration.nix`:

```nix
# Change secret paths to use sops
services.headscale.settings.oidc.client_secret_path = 
  config.sops.secrets.headscale_oidc_client_secret.path;

services.keycloak.database.passwordFile = 
  config.sops.secrets.keycloak_db_password.path;

networking.wg-quick.interfaces.wg-gateway.privateKeyFile = 
  config.sops.secrets.wireguard_gateway_private_key.path;
```

Add sops declarations:
```nix
sops.secrets = {
  headscale_oidc_client_secret = {
    sopsFile = self + /secrets/vps2-de-berlin/headscale.yaml;
    owner = "headscale";
    group = "headscale";
  };
  keycloak_db_password = {
    sopsFile = self + /secrets/vps2-de-berlin/keycloak.yaml;
    owner = "keycloak";
    group = "keycloak";
  };
  # etc...
};
```

### 4. Remove bootstrap state

```bash
sudo rm -rf /var/lib/inckmann-vpn-bootstrap/
```

---

## Inventory Management

All node metadata is in `inventory/fleet.nix`:
- Network addresses (IPv4 + IPv6)
- Roles and tags
- WireGuard peers
- IPSec users

Access helper functions in Nix expressions:
```nix
let
  fleetNode = fleetInventory.getNode "vps2-de-berlin";
  vpnAddr = fleetInventory.getVpnAddresses "vps2-de-berlin";
in { ... }
```

---

## Generic edge proxy targets

Configure domain -> upstream mappings:

```nix
inckmann.networking.edgeProxy.targets = {
  "newsticker.gsm.inckmann.de".upstream = "10.66.0.20:8080";
  "db.newsticker.gsm.inckmann.de".upstream = "10.66.0.21:54321";
  "auth.inckmann.de".upstream = "127.0.0.1:8081";
};
```

Assign to region by running the proxy role on the node in that region (for example `de-berlin` node serves `*.inckmann.de`).

---

## Adding users

1. Create user in Keycloak (`https://auth.inckmann.de`)
2. Assign groups (`admins`, `family`, `friends`)
3. User enrolls device via Tailscale login
4. Approve device and tags in Headscale admin console
5. ACL policy automatically applies based on groups/tags
