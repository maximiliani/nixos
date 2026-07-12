{
inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-26.05";
    sops-nix = {
        url = "github:Mic92/sops-nix";
        inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
        url = "github:nix-community/disko";
        inputs.nixpkgs.follows = "nixpkgs";
    };
};
outputs = {self, nixpkgs, ...}@inputs:
let
  fleetInventory = import ./inventory/fleet.nix;

  mkSystem = { system, modules, fleetNode ? null }:
    nixpkgs.lib.nixosSystem {
      inherit system modules;
      specialArgs = {
        inherit inputs self fleetInventory fleetNode;
      };
    };

  mkFleetSystem = nodeName: { system, modules }:
    let
      fleetNode = fleetInventory.getNode nodeName;
    in
    mkSystem {
      inherit system fleetNode;
      modules = modules fleetNode;
    };

  fleetHosts = {
    vps2-de-berlin = {
      system = "x86_64-linux";
      modules = fleetNode: [
        { nixpkgs.config.allowUnfree = true; }
        inputs.sops-nix.nixosModules.sops
        inputs.disko.nixosModules.disko
        ./${fleetNode.hostConfig}
        ./servers/vps2.de-berlin.net.inckmann.de/hardware-configuration.nix
      ];
    };

    mbp-2016 = {
      system = "x86_64-linux";
      modules = fleetNode: [
        { nixpkgs.config.allowUnfree = true; }
        ./nix-config.nix
        ./${fleetNode.hostConfig}
        ./mbp-2016/hardware-configuration.nix
        inputs.sops-nix.nixosModules.sops
      ];
    };
  };
in {
   nixosModules = {
     vpn = import ./modules/vpn;
     identity = import ./modules/identity;
     networking = import ./modules/networking;
   };
   lib = {
     inherit fleetInventory;
   };
   nixosConfigurations =
     (builtins.mapAttrs mkFleetSystem fleetHosts)
     // {
       t420 = mkSystem {
         system = "x86_64-linux";
         modules = [
           { nixpkgs.config.allowUnfree = true; }
           ./t420/configuration.nix
           ./nix-config.nix
           inputs.sops-nix.nixosModules.sops
         ];
       };
     };
};
}
