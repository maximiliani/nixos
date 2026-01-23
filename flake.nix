{
  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
  outputs = { self, nixpkgs }: {
    nixosConfigurations.vps2-de-berlin = nixpkgs.lib.nixosSystem {
      modules = [ ./configuration.nix ];
    };
  };
}
