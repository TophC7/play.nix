{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.play.lutris;

  # Default extra packages
  defaultExtraPkgs = with pkgs; [
    wineWowPackages.waylandFull
    winetricks
    vulkan-tools
    xterm
  ];

  # Create the configured lutris package
  configuredLutris = pkgs.lutris.override {
    extraPkgs = pkgs: defaultExtraPkgs ++ cfg.extraPkgs;
  };
in
{
  options.play.lutris = {
    enable = lib.mkEnableOption "Install Lutris game manager";

    extraPkgs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = with pkgs; [
        mangohud
        gamemode
      ];
      description = "Additional extra packages for Lutris runtime (added to defaults)";
    };

    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = configuredLutris;
      description = "The configured Lutris package with extra packages";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
