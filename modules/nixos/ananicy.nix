{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.play.ananicy;

  # Default extra rules for gaming processes
  defaultExtraRules = [
    {
      "name" = "gamescope";
      "nice" = -20;
    }
  ];

  # Combine defaults with user extras
  finalExtraRules = defaultExtraRules ++ cfg.extraRules;
in
{
  options.play.ananicy = {
    enable = lib.mkEnableOption "ananicy process scheduler optimization";

    extraRules = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      example = [
        {
          "name" = "steam";
          "nice" = -10;
        }
      ];
      description = "Additional ananicy rules for gaming processes (added to defaults)";
    };
  };

  config = lib.mkIf cfg.enable {
    services.ananicy = {
      enable = true;
      package = lib.mkDefault pkgs.ananicy-cpp;
      rulesProvider = lib.mkDefault pkgs.ananicy-cpp;
      extraRules = finalExtraRules;
    };
  };
}
