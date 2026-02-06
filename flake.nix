{
  description = "NixOS configuration with flakes";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixos-hardware.url = "github:NixOS/nixos-hardware/master";

  outputs =
    {
      self,
      nixpkgs,
      disko,
      nixos-hardware,
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
          ./servers/vps2.de-berlin.net.inckmann.de/configuration.nix
          ./servers/vps2.de-berlin.net.inckmann.de/hardware-configuration.nix
        ];
      };

      nixosConfigurations.mbp-2016 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = [
          nixos-hardware.nixosModules.apple-macbook-pro-14-1
          ./mbp-2016/configuration.nix
          ./mbp-2016/hardware-configuration.nix
        ];
      };
    };
}
