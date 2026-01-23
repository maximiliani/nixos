{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    {
      self,
      nixpkgs,
      disko,
      ...
    }@inputs:
    {
      # Use this for all other targets
      # nixos-anywhere --flake .#generic --generate-hardware-config nixos-generate-config ./hardware-configuration.nix <hostname>
      nixosConfigurations.vps2-de-berlin = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = [
          disko.nixosModules.disko
          ./configuration.nix
          ./hardware-configuration.nix
        ];
      };
    };
}
