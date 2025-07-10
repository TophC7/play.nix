{
  description = "Play - Gaming setup for Wayland with configurable options and working defaults";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      flake-utils,
      chaotic,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };

        # Extend lib with play utilities
        lib = nixpkgs.lib.extend (
          final: prev: {
            play = import ./lib { lib = final; };
          }
        );

      in
      {
        packages = {
          proton-cachyos = pkgs.callPackage ./pkgs/proton-cachyos { };
          default = self.packages.${system}.proton-cachyos;
        };

        # Expose the extended lib
        lib = lib;
      }
    )
    // {
      homeManagerModules.play = import ./modules/home;
      nixosModules.play = {
        imports = [
          (import ./modules/nixos { inherit chaotic; })
        ];
      };

      # Default module (home-manager)
      homeManagerModules.default = self.homeManagerModules.play;

      # Overlay for packages
      overlays.default = final: prev: {
        proton-cachyos = final.callPackage ./pkgs/proton-cachyos { };
        # Add other packages here as needed
      };
    };
}
