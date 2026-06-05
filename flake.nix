{
inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-25.11";
    sops-nix = {
        url = "github:Mic92/sops-nix";
        inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
        url = "github:nix-community/disko";
        inputs.nixpkgs.follows = "nixpkgs";
    };
};
outputs = {self, nixpkgs, ...}@inputs: {
   nixosConfigurations = {
      vps2-de-berlin = nixpkgs.lib.nixosSystem rec {
         system = "x86_64-linux";
         specialArgs = {
            inherit inputs self;
         };
         modules = [
           { nixpkgs.config.allowUnfree = true; }
           inputs.sops-nix.nixosModules.sops
           inputs.disko.nixosModules.disko
           ./servers/vps2.de-berlin.net.inckmann.de/configuration.nix
           ./servers/vps2.de-berlin.net.inckmann.de/hardware-configuration.nix
         ];
      };

      t420 = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs = {
            inherit inputs self;
        };
        modules = [
          { nixpkgs.config.allowUnfree = true; }
          ./t420/configuration.nix
          ./nix-config.nix
          inputs.sops-nix.nixosModules.sops
        ];
      };

      mbp-2016 = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        specialArgs = {
            inherit inputs self;
        };
        modules = [
          { nixpkgs.config.allowUnfree = true; }
          ./nix-config.nix
          ./mbp-2016/configuration.nix
          ./mbp-2016/hardware-configuration.nix
          inputs.sops-nix.nixosModules.sops
        ];
      };
   };
};
}
