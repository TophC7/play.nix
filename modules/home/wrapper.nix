{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.play.wrappers;

  # Use shared lib function
  inherit (lib.play) toCliArgs;

  # Function to create a wrapper for an application
  mkWrapper =
    name: wrapperCfg:
    let
      # Get the original package
      originalPackage = wrapperCfg.package;

      # Create environment variable exports
      envExports = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: value: "set -x ${name} '${toString value}'") wrapperCfg.environment
      );

      # Convert extraOptions to CLI args
      extraArgs = lib.optionalString (
        wrapperCfg.extraOptions != { }
      ) "-x \"${toCliArgs wrapperCfg.extraOptions}\"";

      # The wrapper script
      wrapperScript = pkgs.writeScriptBin name ''
        #!${lib.getExe pkgs.fish}

        # Set additional environment variables
        ${envExports}

        # Execute with gamescoperun
        exec ${lib.getExe config.play.gamescoperun.package} ${extraArgs} ${lib.getExe originalPackage} $argv
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
              type = lib.types.package;
              description = "The package to wrap";
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
    play.gamescoperun.enable = lib.mkIf (lib.length (lib.attrNames cfg) > 0) true;
  };
}
