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
      chaotic,
      ...
    }@inputs:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      lib = import ./lib { inherit (nixpkgs) lib; };

      nixosModules = {
        play = import ./modules/nixos self;
        procon2 = import ./modules/nixos/procon2.nix;
        default = self.nixosModules.play;
      };

      homeManagerModules = {
        play = import ./modules/home self;
        default = self.homeManagerModules.play;
      };

      nixosConfigurations.test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./test-config.nix
          self.nixosModules.play
        ];
      };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          proton-cachyos = pkgs.callPackage ./pkgs/proton-cachyos { };
          procon2-init = pkgs.callPackage ./pkgs/procon2 { };
          default = self.packages.${system}.proton-cachyos;
        }
      );

      # Overlay for packages
      overlays.default = final: prev: {
        proton-cachyos = final.callPackage ./pkgs/proton-cachyos { };
        procon2-init = final.callPackage ./pkgs/procon2 { };
        # Add other packages here as needed
      };
    };
}
