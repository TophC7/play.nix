{
  description = "Play - Gaming setup for Wayland with configurable options and working defaults";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mix-nix = {
      url = "github:tophc7/mix.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      mix-nix,
      chaotic,
      ...
    }@inputs:
    let
      # Use mix.nix's extended lib
      lib = mix-nix.lib;
    in
    {
      # Export play.nix specific lib utilities (gamescope helpers)
      lib = import ./lib { inherit lib; };

      nixosModules = {
        play = import ./modules/nixos self;
        procon2 = import ./modules/nixos/procon2.nix;
        default = self.nixosModules.play;
      };

      homeManagerModules = {
        play = import ./modules/home {
          inherit lib;
          flake = self;
        };
        default = self.homeManagerModules.play;
      };

      nixosConfigurations.test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./test-config.nix
          self.nixosModules.play
        ];
      };
    };
}
