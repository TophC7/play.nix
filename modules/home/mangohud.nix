{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.play.mangohud;

  settingsType = with lib.types;
    oneOf [
      bool
      int
      float
      str
      path
      (listOf (oneOf [
        int
        str
      ]))
    ];

  presets = {
    minimal = {
      fps = true;
      frametime = true;
      frame_timing = true;
      position = "top-left";
      toggle_hud = "Shift_R+F12";
    };

    full = {
      fps = true;
      frametime = true;
      frame_timing = true;
      gpu_stats = true;
      cpu_stats = true;
      ram = true;
      vram = true;
      gamemode = true;
      position = "top-left";
      toggle_hud = "Shift_R+F12";
    };

    debug = {
      fps = true;
      frametime = true;
      frame_timing = true;
      histogram = true;
      gpu_stats = true;
      gpu_temp = true;
      cpu_stats = true;
      cpu_temp = true;
      ram = true;
      vram = true;
      gamemode = true;
      winesync = true;
      position = "top-left";
      toggle_hud = "Shift_R+F12";
      toggle_logging = "Shift_L+F2";
    };
  };
in {
  options.play.mangohud = {
    enable = lib.mkEnableOption "MangoHud overlay configuration";

    package = lib.mkPackageOption pkgs "mangohud" {};

    enableSessionWide = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable MangoHud for every supported application in the user session";
    };

    preset = lib.mkOption {
      type = lib.types.enum (lib.attrNames presets);
      default = "minimal";
      description = "Built-in MangoHud settings preset";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf settingsType;
      default = {};
      example = {
        fps_limit = [165];
        no_display = true;
      };
      description = "Additional MangoHud settings merged over the selected preset";
    };

    settingsPerApplication = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf settingsType);
      default = {};
      example = {
        mpv = {
          no_display = true;
        };
      };
      description = "MangoHud settings for specific applications";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.mangohud = {
      enable = true;
      inherit (cfg) package enableSessionWide settingsPerApplication;
      settings = presets.${cfg.preset} // cfg.settings;
    };
  };
}
