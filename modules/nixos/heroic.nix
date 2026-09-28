# Heroic Games Launcher with Steam's Proton builds made discoverable.
# Heroic only scans per-user folders for Proton; it never sees
# programs.steam.extraCompatPackages, so we link them into its tools dir
# for every user via user tmpfiles (applied at login).
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.play.heroic;
in
{
  options.play.heroic = {
    enable = lib.mkEnableOption "Heroic Games Launcher";

    package = lib.mkPackageOption pkgs "heroic" { };

    protonPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = config.programs.steam.extraCompatPackages;
      defaultText = lib.literalExpression "config.programs.steam.extraCompatPackages";
      description = ''
        Steam compatibility tools linked into each user's Heroic Proton folder.
        Links are named by package name (not version), so per-game Proton
        choices in Heroic survive updates.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # ponytail: links for removed packages dangle until deleted by hand;
    # tmpfiles can't prune them without also wiping Heroic-downloaded Protons.
    systemd.user.tmpfiles.rules = map (
      proton:
      "L+ %h/.config/heroic/tools/proton/${lib.getName proton} - - - - ${lib.getOutput "steamcompattool" proton}"
    ) cfg.protonPackages;
  };
}
