# Steam module with gaming optimizations
# Automatically includes proton-cachyos package
{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.play.steam;

  # Import proton-cachyos package directly, some users wont chaotics overlay
  proton-cachyos = pkgs.callPackage ../../pkgs/proton-cachyos { };

  defaultCompatPackages = [
    pkgs.proton-ge-custom
    proton-cachyos
  ];

  finalCompatPackages = defaultCompatPackages ++ cfg.extraCompatPackages;

  configuredSteam = pkgs.steam.override {
    extraPkgs = cfg.extraPkgs;
  };
in
{
  options.play.steam = {
    enable = lib.mkEnableOption "Steam with gaming optimizations";

    extraCompatPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = with pkgs; [ proton-ge-bin ];
      description = "Additional Proton compatibility packages to add to the defaults";
    };

    extraPkgs = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default =
        pkgs: with pkgs; [
          # X11 libraries
          xorg.libXcursor
          xorg.libXi
          xorg.libXinerama
          xorg.libXScrnSaver

          # System libraries
          stdenv.cc.cc.lib
          gamemode
          gperftools
          keyutils
          libkrb5
          libpng
          libpulseaudio
          libvorbis
          mangohud
        ];
      description = "Extra packages to include in Steam's runtime";
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
