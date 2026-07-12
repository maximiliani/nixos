#!/usr/bin/env bash
# Script to generate and encrypt SOPS secrets for vps2-de-berlin
# Run this AFTER initial bootstrap deployment, then migrate services to use sops-nix

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$ROOT_DIR/secrets/vps2-de-berlin"

echo "=== Generating SOPS secrets for vps2-de-berlin ==="
echo ""

# Ensure secrets directory exists
mkdir -p "$SECRETS_DIR"

# Check if sops is available
if ! command -v sops &> /dev/null; then
    echo "ERROR: sops is not installed. Install it first:"
    echo "  nix-shell -p sops"
    exit 1
fi

# Check if age key exists
AGE_KEY_FILE="/var/lib/sops-nix/key.txt"
if [[ ! -f "$AGE_KEY_FILE" ]]; then
    # Try to find it in common locations
    if [[ -f "$HOME/.config/sops/age/keys.txt" ]]; then
        AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
    elif [[ -f "$HOME/.sops/age/keys.txt" ]]; then
        AGE_KEY_FILE="$HOME/.sops/age/keys.txt"
    else
        echo "WARNING: Age key file not found at $AGE_KEY_FILE"
        echo "Set SOPS_AGE_KEY_FILE environment variable or create the key file"
        exit 1
    fi
fi

export SOPS_AGE_KEY_FILE

echo "Using age key file: $SOPS_AGE_KEY_FILE"
echo ""

# Function to create and encrypt a secret
create_secret() {
    local filename="$1"
    local key="$2"
    local value="$3"
    local filepath="$SECRETS_DIR/$filename"
    
    echo "Creating $filename..."
    
    # Create YAML file
    cat > "$filepath" <<EOF
$key: |
  $value
EOF
    
    # Encrypt with sops
    if sops -e -i "$filepath" 2>/dev/null; then
        echo "  ✓ Encrypted: $filepath"
    else
        echo "  ✗ Failed to encrypt: $filepath"
        rm -f "$filepath"
        return 1
    fi
}

# Function to copy existing secret from bootstrap
copy_bootstrap_secret() {
    local filename="$1"
    local key="$2"
    local bootstrap_path="$3"
    local filepath="$SECRETS_DIR/$filename"
    
    if [[ ! -f "$bootstrap_path" ]]; then
        echo "  ⊘ Skipping $filename (bootstrap secret not found at $bootstrap_path)"
        return 0
    fi
    
    echo "Creating $filename from bootstrap..."
    
    # Read the bootstrap secret
    local value
    value=$(cat "$bootstrap_path")
    
    # Create YAML file (handle multiline values)
    if [[ "$value" == *$'\n'* ]]; then
        # Multiline value (certificates, keys)
        cat > "$filepath" <<EOF
$key: |
$(echo "$value" | sed 's/^/  /')
EOF
    else
        # Single line value
        cat > "$filepath" <<EOF
$key: $value
EOF
    fi
    
    # Encrypt with sops
    if sops -e -i "$filepath" 2>/dev/null; then
        echo "  ✓ Encrypted: $filepath"
    else
        echo "  ✗ Failed to encrypt: $filepath"
        rm -f "$filepath"
        return 1
    fi
}

echo "--- Generating new random secrets ---"
echo ""

# Headscale OIDC client secret (random base64)
HEADSCALE_OIDC_SECRET=$(openssl rand -base64 36)
create_secret "headscale.yaml" "headscale_oidc_client_secret" "$HEADSCALE_OIDC_SECRET"

# Keycloak DB password (random base64)
KEYCLOAK_DB_PASSWORD=$(openssl rand -base64 36)
create_secret "keycloak.yaml" "keycloak_db_password" "$KEYCLOAK_DB_PASSWORD"

# WireGuard private key
WIREGUARD_PRIVATE_KEY=$(wg genkey 2>/dev/null || echo "PLACEHOLDER_INSTALL_WIREGUARD_TOOLS")
if [[ "$WIREGUARD_PRIVATE_KEY" == "PLACEHOLDER"* ]]; then
    echo "WARNING: wireguard-tools not installed, using placeholder"
    echo "Generate manually with: wg genkey"
fi
create_secret "wireguard.yaml" "wireguard_gateway_private_key" "$WIREGUARD_PRIVATE_KEY"

# WireGuard preshared key
WIREGUARD_PSK=$(openssl rand -base64 32)
create_secret "wireguard-psk.yaml" "wireguard_gateway_preshared_key" "$WIREGUARD_PSK"

echo ""
echo "--- Copying existing bootstrap secrets ---"
echo ""

BOOTSTRAP_DIR="/var/lib/inckmann-vpn-bootstrap/secrets"

# IPSec server key (PEM format, multiline)
copy_bootstrap_secret "ipsec-server-key.yaml" "ipsec_gateway_server_key" "$BOOTSTRAP_DIR/ipsec-server-key"

# IPSec server cert (PEM format, multiline)
copy_bootstrap_secret "ipsec-server-cert.yaml" "ipsec_gateway_server_cert" "$BOOTSTRAP_DIR/ipsec-server-cert"

# IPSec CA cert (PEM format, multiline)
copy_bootstrap_secret "ipsec-ca-cert.yaml" "ipsec_gateway_ca_cert" "$BOOTSTRAP_DIR/ipsec-ca-cert"

echo ""
echo "=== Summary ==="
echo ""
echo "Generated secrets in $SECRETS_DIR:"
ls -la "$SECRETS_DIR"/*.yaml 2>/dev/null || echo "No secrets generated"
echo ""
echo "Next steps:"
echo "1. Verify secrets can be decrypted:"
echo "   sops -d $SECRETS_DIR/headscale.yaml"
echo ""
echo "2. Update servers/vps2.de-berlin.net.inckmann.de/configuration.nix:"
echo "   - Uncomment sops configuration section"
echo "   - Set manageSopsSecrets = true for each service"
echo "   - Update secret paths to use config.sops.secrets.<name>.path"
echo ""
echo "3. Deploy updated configuration:"
echo "   sudo nixos-rebuild switch --flake .#vps2-de-berlin"
echo ""
echo "4. Remove bootstrap state:"
echo "   sudo rm -rf /var/lib/inckmann-vpn-bootstrap/"
echo ""
