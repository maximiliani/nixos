{
  description = "NixOS configuration with flakes";

  inputs = {
    self.submodules = true;
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-master.url = "github:NixOS/nixpkgs";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";

  };

  outputs =
    { self, systems, ... }@inputs:
      with inputs;
      let
        inherit (inputs.nixpkgs.lib) filterAttrs mapAttrs elem;
        getCfg = _: cfg: cfg.config.system.build.toplevel;
        pkgsConfig =
          pkgs: system:
          import pkgs {
            overlays = [
              #                (import ./generic/overlays)
              #                mprisRecord.overlays.${system}.default
            ];
            inherit system;
            config = {
              allowUnfree = true; # allow Unfree packages
            };
          };

        stable-nixpkgs = system: pkgsConfig nixpkgs-stable system;
        overlays = system: final: prev: {
          master = pkgsConfig nixpkgs-master system;
          stable = pkgsConfig nixpkgs-stable system;
          unstable = pkgsConfig nixpkgs system;
          ffmpeg-vpl = import nixpkgs-stable {
            #              overlays = [ (import ./generic/overlays/ffmpeg.nix) ];
            overlays = [ ];
            inherit system;
            config.allowUnfree = true;
            modules = [
              ./generic
            ];
          };
        };

        makeSystem =
          { systemModules
          , homeManagerModules ? { }
          , stable ? true
          , system ? "x86_64-linux"
          , secureboot ? false
          , genericHomeManagerModules ? [ ]
          , ...
          }:
          nixpkgs-stable.lib.nixosSystem rec {
            pkgs = if stable then pkgsConfig nixpkgs-stable system else pkgsConfig nixpkgs system;
            inherit system;
            specialArgs = {
              inherit
                inputs
                stable
                #                  secureboot
                #                  genericHomeManagerModules
                ; # ToDO: also make proxmox an option
              #                inherit (hydra.packages.${system}) hydra;
              #                inherit (inputs.sops-nix.nixosModules) sops;
              homeManagerModules =
                nixpkgs.lib.attrsets.foldAttrs (item: acc: item ++ acc)
                  [ ]
                  [
                    {
                      root = [
                        #                          ./generic/users/raoul.nix
                      ];
                    }
                    #                      homeManagerModules
                  ];
            };
            modules = [
              (
                { config, pkgs, ... }:
                {
                  nixpkgs.overlays = [ (overlays system) ];
                }
              )
              #                ./generic/newDefault.nix
              ./generic/modules
              #                ./generic/kernelpatch.nix
            ]
            ++ systemModules;
          };

        # Small tool to iterate over each systems
        eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
      in
      rec {
        nixosConfigurations = {
          vps2-de-berlin = makeSystem {
            systemModules = [
              disko.nixosModules.disko
              ./servers/vps2.de-berlin.net.inckmann.de/configuration.nix
              ./servers/vps2.de-berlin.net.inckmann.de/hardware-configuration.nix
            ];
            stable = true;
          };
          mbp-2016 = makeSystem {
            systemModules = [
              nixos-hardware.nixosModules.apple-macbook-pro-14-1
              ./mbp-2016/configuration.nix
              ./mbp-2016/hardware-configuration.nix
            ];
            stable = true;
          };
        };

        checks = nixpkgs.lib.genAttrs (import systems) (system: {
          pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
            addGcRoot = true;
            src = ./.;
            hooks = {
              action-validator.enable = true;
              beautysh.enable = true;
              beautysh.excludes = [ "p10k.zsh" ];
              check-merge-conflicts.enable = true;
              markdownlint.enable = true;
              mdformat.enable = true;
              nixfmt-rfc-style.enable = true;
              pre-commit-hook-ensure-sops.enable = true;
              pretty-format-json.enable = true;
            };
          };
        });

        devShells = nixpkgs.lib.genAttrs (import systems) (system: {
          default = nixpkgs.legacyPackages.${system}.mkShell {
            shellHook = ''
              ${self.checks.${system}.pre-commit-check.shellHook}

              # --- your additions below ---
              git config diff.sopsdiffer.textconv "sops decrypt"
              pre-commit install
              echo Shell setup
            '';
            buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
            packages = with (stable-nixpkgs system); [
              meld
              sops
            ];
          };
        });

        formatter = eachSystem (pkgs: pkgs.nixfmt-tree);
        images.raspberry = nixosConfigurations.aarch64-image.config.system.build.sdImage;
      };
}
