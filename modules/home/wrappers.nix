{
  lib,
  config,
  pkgs,
  ...
}:
let
  # Extend lib with play utilities
  playLib = import ../../lib { inherit lib; };

  cfg = config.play.wrappers;

  # Use shared lib function
  inherit (playLib) toCliArgs;

  # Function to create a wrapper for an application
  mkWrapper =
    name: wrapperCfg:
    let
      # Determine the command to execute
      baseCommand =
        if wrapperCfg.command != null then wrapperCfg.command else lib.getExe wrapperCfg.package;

      # Convert wrapper-specific environment to a single string for gamescoperun
      gamescopeWrapperEnv = lib.optionalString (wrapperCfg.environment != { }) (
        let
          envList = lib.mapAttrsToList (name: value: "${name}=${toString value}") wrapperCfg.environment;
        in
        # Set as a global exported variable so gamescoperun can see it
        "set -gx GAMESCOPE_WRAPPER_ENV '${lib.concatStringsSep ";" envList}'"
      );

      # Set systemd flag - always set it to communicate wrapper preference to gamescoperun
      systemdEnv = "set -gx GAMESCOPE_USE_SYSTEMD ${if wrapperCfg.useSystemd then "1" else "0"}";

      # Set HDR flag if specified for this wrapper
      hdrEnv =
        lib.optionalString (wrapperCfg.useHDR != null)
          "set -gx GAMESCOPE_USE_HDR ${if wrapperCfg.useHDR then "true" else "false"}";

      # Set WSI flag if specified for this wrapper
      wsiEnv =
        lib.optionalString (wrapperCfg.useWSI != null)
          "set -gx GAMESCOPE_USE_WSI ${if wrapperCfg.useWSI then "true" else "false"}";

      # Convert extraOptions to CLI args
      extraArgs = lib.optionalString (
        wrapperCfg.extraOptions != { }
      ) "-x \"${toCliArgs wrapperCfg.extraOptions}\"";

      wrapperScript = pkgs.writeScriptBin name ''
        #!${lib.getExe pkgs.fish}

        # Set environment for gamescoperun to consume
        ${gamescopeWrapperEnv}
        ${systemdEnv}
        ${hdrEnv}
        ${wsiEnv}

        # Execute with gamescoperun
        exec ${lib.getExe config.play.gamescoperun.package} ${extraArgs} ${baseCommand} $argv
      '';

    in
    wrapperScript;
in
{
  options.play.wrappers = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            enable = lib.mkEnableOption "wrapper for this application";

            package = lib.mkOption {
              type = lib.types.nullOr lib.types.package;
              default = null;
              description = "The package to wrap (used with lib.getExe if command is not specified)";
            };

            command = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "\${lib.getExe osConfig.programs.steam.package} -tenfoot -bigpicture";
              description = ''
                The exact command to execute after gamescoperun and its options.
                If specified, this takes precedence over the package option.
                Can include arguments and flags.
              '';
            };

            extraOptions = lib.mkOption {
              type =
                with lib.types;
                attrsOf (oneOf [
                  str
                  int
                  bool
                ]);
              default = { };
              example = {
                "fsr-upscaling" = true;
                "force-windows-fullscreen" = true;
                "fsr-upscaling-sharpness" = 5;
              };
              description = ''
                Additional gamescope command-line options for this specific wrapper.
                Option names must match gamescope's flags exactly (e.g., "hdr-enabled").
                These will be passed via the -x flag to gamescoperun.
              '';
            };

            environment = lib.mkOption {
              type =
                with lib.types;
                attrsOf (oneOf [
                  str
                  int
                ]);
              default = { };
              example = {
                STEAM_FORCE_DESKTOPUI_SCALING = 1;
                STEAM_GAMEPADUI = 1;
              };
              description = "Additional environment variables for this specific wrapper";
            };

            useSystemd = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable systemd-run for this specific wrapper. Takes precedence over global defaultSystemd. When true, wraps the gamescope execution with systemd-run for better process isolation.";
            };

            useHDR = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = "Enable or disable HDR for this specific wrapper. Takes precedence over global defaultHDR and monitor settings. If null, uses global defaults.";
            };

            useWSI = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = "Enable or disable WSI (Wayland Surface Interface) for this specific wrapper. Takes precedence over global defaultWSI. If null, uses global defaults.";
            };

            # Readonly package option that exposes the configured wrapper
            wrappedPackage = lib.mkOption {
              type = lib.types.package;
              readOnly = true;
              default = mkWrapper name config.play.wrappers.${name};
              description = "The configured wrapper package for this application";
            };
          };
        }
      )
    );
    default = { };
    description = "Application wrappers that run through gamescoperun";
  };

  config = {
    home.packages = lib.mapAttrsToList mkWrapper (
      lib.filterAttrs (name: wrapperCfg: wrapperCfg.enable) cfg
    );

    # Ensure gamescoperun is enabled if any wrappers are enabled
    play.gamescoperun.enable = lib.mkIf (
      lib.length (lib.attrNames (lib.filterAttrs (name: wrapperCfg: wrapperCfg.enable) cfg)) > 0
    ) true;

    assertions = lib.mapAttrsToList (name: wrapperCfg: {
      assertion = wrapperCfg.enable -> (wrapperCfg.command != null || wrapperCfg.package != null);
      message = "play.wrappers.${name}: Either 'command' or 'package' must be specified when enabled";
    }) cfg;
  };
}
