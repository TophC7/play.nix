{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.play.gamemode;
in
{
  options.play.gamemode = {
    enable = lib.mkEnableOption "gamemode configuration for gaming optimization";

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {
        general = {
          softrealtime = "auto";
          inhibit_screensaver = 1;
          renice = 15;
        };
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 1;
          amd_performance_level = "high";
        };
        custom = {
          start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
          end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
        };
      };
      description = "Gamemode configuration settings";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.gamemode = {
      enable = true;
      enableRenice = true;
      settings = lib.mkDefault cfg.settings;
    };
  };
}
