# Steam module with gaming optimizations
# Automatically includes proton-cachyos and proton-cachyos-v3 packages (from mix.nix)
{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  cfg = config.play.steam;
  system = pkgs.stdenv.hostPlatform.system;

  # Packages come directly from mix.nix (no overlay needed for users)
  proton-cachyos = inputs.mix-nix.packages.${system}.proton-cachyos;
  proton-cachyos-v3 = inputs.mix-nix.packages.${system}.proton-cachyos.v3;

  defaultCompatPackages = [
    proton-cachyos
    proton-cachyos-v3
    pkgs.proton-ge-bin
  ];

  finalCompatPackages = defaultCompatPackages ++ cfg.extraCompatPackages;

  defaultExtraPkgs = with pkgs; [
    # X11 libraries
    libxcursor
    libxi
    libxinerama
    libxscrnsaver

    # System libraries
    stdenv.cc.cc.lib
    gamemode
    gperftools
    keyutils
    libkrb5
    libpng
    libpulseaudio
    libvorbis
  ];

  configuredSteam = pkgs.steam.override {
    extraPkgs = pkgs: defaultExtraPkgs ++ cfg.extraPkgs;
  };
in {
  options.play.steam = {
    enable = lib.mkEnableOption "Steam with gaming optimizations";

    extraCompatPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional Proton compatibility packages to add to the defaults";
    };

    extraPkgs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      example = with pkgs; [
        gamescope
      ];
      description = "Additional extra packages for Steam runtime (added to defaults)";
    };

    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = configuredSteam;
      description = "The configured Steam package with extra packages";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = lib.mkDefault false;
      dedicatedServer.openFirewall = lib.mkDefault false;

      protontricks = {
        enable = lib.mkDefault true;
        package = lib.mkDefault pkgs.protontricks;
      };

      package = lib.mkDefault cfg.package;

      # Use the combined list of default + user extras
      extraCompatPackages = finalCompatPackages;
    };
  };
}
