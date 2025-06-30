{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.play.amd;
in
{
  options.play.amd = {
    enable = lib.mkEnableOption "AMD GPU configuration with LACT (Linux AMD Control Tool)";
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics = {
      enable = lib.mkDefault true;
      enable32Bit = lib.mkDefault true;
    };

    # Install LACT for AMD GPU control
    environment.systemPackages = with pkgs; [ lact ];

    # Enable LACT daemon
    systemd = {
      packages = with pkgs; [ lact ];
      services.lactd.wantedBy = [ "multi-user.target" ];
    };
  };
}
