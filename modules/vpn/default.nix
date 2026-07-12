{
  imports = [
    ./bootstrap/options.nix
    ./fleet-node-defaults.nix
    ./fleet-ssh-aliases.nix
    ./role-metadata.nix
    ./managed-client.nix
    ./headscale/control.nix
    ./headscale/bootstrap.nix
    ./derp-relay.nix
    ./exit-node.nix
    ./site-gateway.nix
    ./wireguard/gateway.nix
    ./wireguard/bootstrap.nix
    ./ipsec/gateway.nix
    ./ipsec/bootstrap.nix
  ];
}
