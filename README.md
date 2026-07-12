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

## VPN module overview

`flake.nix` exports:

```nix
inputs.self.nixosModules.vpn
```

Role modules under `modules/vpn/`:
- `managed-client.nix`
- `headscale/control.nix`
- `headscale/bootstrap.nix`
- `derp-relay.nix`
- `exit-node.nix`
- `site-gateway.nix`
- `wireguard/gateway.nix`
- `wireguard/bootstrap.nix`
- `ipsec/gateway.nix`
- `ipsec/bootstrap.nix`
- `bootstrap/options.nix`

Identity module:
- `modules/identity/keycloak-server.nix`
- `modules/identity/keycloak-bootstrap.nix`

Networking module:
- `modules/networking/edge-proxy.nix`

Inventory is tracked in `inventory/fleet.nix`.
`serverProfile` is no longer used; node intent is expressed via `roles` and `tags`.

`fleet.nix` is now the single source of truth for node identity.  
Each node is resolved via `fleetInventory.getNode "<node-name>"`, which computes:
- `name`
- `hostName`
- `domain`
- `publicHostname` (defaults to `<name>.<defaultDomain>` when no public hostname is set)

`flake.nix` passes this as `fleetNode` to host configs.  
`modules/vpn/fleet-node-defaults.nix` now auto-derives:
- `networking.hostName`
- `networking.domain`
- `inckmann.fleet.*`

On all fleet-backed nodes, SSH client aliases are generated from fleet inventory automatically.
You can log in using node name or host name shortcut, for example:

```bash
ssh vps2-de-berlin
# or
ssh vps2
```

## Headscale + Keycloak OIDC

`modules/vpn/headscale/control.nix` supports template-based config rendering with OIDC secret injection:
- template secret: `headscale_config_template`
- OIDC client secret: `headscale_oidc_client_secret`
- tailnet DNS base domain via `inckmann.vpn.headscaleControl.dns.baseDomain`

The template must contain:

```yaml
client_secret: __HEADSCALE_OIDC_CLIENT_SECRET__
base_domain: __HEADSCALE_DNS_BASE_DOMAIN__
magic_dns: __HEADSCALE_DNS_MAGIC_DNS__
```

At service start, the placeholder is replaced from `/run/secrets/headscale_oidc_client_secret`.
Default node FQDN suffix is `headscale.inckmann.de`.

### DNS delegation / NS records

Do **not** delegate public DNS (`NS`) for `headscale.inckmann.de` to Headscale.
Headscale DNS is distributed to enrolled clients (MagicDNS), not operated as a public authoritative nameserver.

What to configure in public DNS instead:
- `A/AAAA` records for your control endpoints (for example `vpn.net.inckmann.de`, `auth.inckmann.de`).
- Keep normal public zone NS records on your DNS provider/authoritative DNS.
- No `NS` delegation for `headscale.inckmann.de` is required for client node naming.

## Keycloak server on VPS2

`modules/identity/keycloak-server.nix` deploys:
- local PostgreSQL (database/user auto-provision)
- Keycloak service on `127.0.0.1:8081`
- reverse-proxy ingress through `inckmann.networking.edgeProxy.targets."auth.inckmann.de"`
- production defaults enabled (strict hostname, proxy header mode, health + metrics)

Current `vps2` config already includes:
- `inckmann.identity.keycloak.enable = true;`
- `inckmann.identity.keycloak.hostname = "auth.inckmann.de";`
- `auth.inckmann.de -> 127.0.0.1:8081` edge target

## First-install bootstrap (optional)

You can let NixOS generate missing VPN bootstrap secrets on first install:

```nix
inckmann.vpn.bootstrap.generateOnFirstInstall = true;
```

Behavior:
- Runs per-domain one-shot units:
  - `inckmann-keycloak-bootstrap-secrets.service`
  - `inckmann-headscale-bootstrap-secrets.service`
  - `inckmann-wireguard-bootstrap-secrets.service`
  - `inckmann-ipsec-bootstrap-secrets.service`
- Generates only missing files (idempotent on rebuild)
- Stores local bootstrap files under `/var/lib/inckmann-vpn-bootstrap/secrets/`
- Services are ordered after bootstrap generation when enabled

Optional path override:

```nix
inckmann.vpn.bootstrap.stateDir = "/var/lib/inckmann-vpn-bootstrap";
```

Generated files:
- `keycloak_db_password`
- `keycloak_admin_password`
- `headscale_oidc_client_secret`
- `headscale_config_template`
- `headscale_config`
- `wireguard_gateway_private_key`
- `ipsec_gateway_server_key`
- `ipsec_gateway_server_cert`
- `ipsec_gateway_ca_cert`

Important:
- This mode is opt-in and does **not** replace long-term SOPS management.
- After first provisioning, migrate/rotate into `secrets/<host>/default.yaml` and disable bootstrap mode.

## Manual SOPS secret names for vps2

Use these keys in `secrets/vps2-de-berlin/default.yaml`:
- `keycloak_db_password`
- `keycloak_admin_password`
- `headscale_config_template`
- `headscale_oidc_client_secret`
- `wireguard_gateway_private_key`
- `ipsec_gateway_server_key`
- `ipsec_gateway_server_cert`
- `ipsec_gateway_ca_cert`
- `derp_tls_cert`
- `derp_tls_key`
- `acme_dns_api_token`

Trusted client flow:

```bash
export SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt
sops edit secrets/vps2-de-berlin/default.yaml
```

## VPS2 rollout

1. Choose bootstrap mode:
   - **Preferred long-term:** put secrets into `secrets/vps2-de-berlin/default.yaml`
   - **First-install bootstrap:** set `inckmann.vpn.bootstrap.generateOnFirstInstall = true;`
2. Enable desired roles in `servers/vps2.de-berlin.net.inckmann.de/configuration.nix`:
   - `inckmann.identity.keycloak.enable = true;`
   - `inckmann.vpn.headscaleControl.enable = true;`
   - `inckmann.vpn.headscaleControl.dns.baseDomain = "headscale.inckmann.de";`
   - `inckmann.vpn.derpRelay.enable = true;`
   - `inckmann.networking.edgeProxy.enable = true;`
   - optional: `inckmann.vpn.wireguardGateway.enable = true;`
   - optional: `inckmann.vpn.ipsecGateway.enable = true;`
3. Rebuild:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#vps2-de-berlin
```

4. Bootstrap first user:

```bash
sudo headscale users create maximilian
sudo headscale preauthkeys create --user maximilian --reusable=false --expiration 24h
```

5. Bootstrap Keycloak realm/client for Headscale:
   - create realm: `inckmann`
   - create OIDC client: `headscale` (confidential)
   - set client secret to value in `headscale_oidc_client_secret`
   - ensure group claims are included (`groups`)

6. If bootstrap mode was used:
   - copy generated values into SOPS-managed host secrets
   - rotate credentials/certs where needed
   - set `inckmann.vpn.bootstrap.generateOnFirstInstall = false;`

## Generic edge proxy targets

Configure domain -> upstream mappings:

```nix
inckmann.networking.edgeProxy.targets = {
  "newsticker.gsm.inckmann.de".upstream = "10.66.0.20:8080";
  "db.newsticker.gsm.inckmann.de".upstream = "10.66.0.21:54321";
  "auth.inckmann.de".upstream = "10.66.0.30:8080";
};
```

Assign to region by running the proxy role on the node in that region (for example `de-berlin` node serves `*.inckmann.de`).

## NixOS managed clients (mbp-2016)

`mbp-2016` is preconfigured as first managed client for user **Maximilian**.

Enroll:

```bash
vpn-client-up --auth-key <HEADSCALE_PREAUTH_KEY>
```

## Non-NixOS managed clients

Install Tailscale, then enroll against Headscale:

```bash
tailscale up --login-server https://vpn.net.inckmann.de --auth-key <HEADSCALE_PREAUTH_KEY>
```

## WireGuard gateway connections (Fritz!Box example)

1. Choose target region node (example: `vps2-de-berlin`) and enable `wireguardGateway`.
2. Create peer keys on client/device.
3. Add peer in NixOS:

```nix
inckmann.vpn.wireguardGateway.peers = [
  {
    publicKey = "<FRITZBOX_PUBLIC_KEY>";
    allowedIPs = [ "10.66.200.10/32" ];
    persistentKeepalive = 25;
  }
];
```

4. Configure Fritz!Box WireGuard endpoint to that region hostname/IP (e.g. `vpn.net.inckmann.de:51820`).
5. Region assignment is the selected gateway endpoint (Berlin endpoint => Berlin region).

## IPSec gateway connections (Fritz!Box example)

1. Enable `inckmann.vpn.ipsecGateway.enable = true;` on region node.
2. Add user credential:

```nix
inckmann.vpn.ipsecGateway.eapUsers = {
  fritzbox-home = "<STRONG_PASSWORD>";
};
```

3. Import `ipsec_gateway_ca_cert` into client trust store.
4. Configure Fritz!Box IKEv2 profile:
   - Remote ID / server: `vpn.net.inckmann.de`
   - Username: `fritzbox-home`
   - Password: value from `eapUsers`
5. Region assignment is the selected IPSec server endpoint.

Override any generated IPSec boilerplate via:

```nix
inckmann.vpn.ipsecGateway.settingsOverrides = { ... };
```

## Adding users

1. Create user in Keycloak.
2. Assign groups (`admins`, `family`, `friends`, `exit-<region>-allowed`).
3. Create Headscale user/preauth key.
4. Enroll device and verify ACL policy.
