{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.play.heroic;

  defaultExtraPkgs = with pkgs; [
    winePackages.waylandFull
    winetricks
  ];

  configuredHeroic = pkgs.heroic.override {
    extraPkgs = pkgs: defaultExtraPkgs ++ cfg.extraPkgs;
  };
in
{
  options.play.heroic = {
    enable = lib.mkEnableOption "Install Heroic games launcher";

    extraPkgs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional extra packages for Heroic runtime (added to defaults)";
    };

    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = configuredHeroic;
      description = "The configured Heroic package with extra packages";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
