{
inputs = {
nixpkgs.url = "github:NixOs/nixpkgs/nixos-25.11";
sops-nix = {
	url = "github:Mic92/sops-nix";
	inputs.nixpkgs.follows = "nixpkgs";
};
};
outputs = {self, nixpkgs, ...}@inputs: {
	nixosConfigurations.t420 = nixpkgs.lib.nixosSystem rec {
		pkgs = import nixpkgs {
				inherit system;
				config.allowUnfree = true;
			};
		system = "x86_64-linux";
		specialArgs = {
			inherit inputs self;
		};
		modules = [
			./configuration.nix
    			./nix-config.nix
		];
	};
};
}
