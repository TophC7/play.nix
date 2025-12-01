# Gamescope-specific utilities for play.nix
#
# These utilities are specific to gamescope configuration and build on
# the general monitor utilities from mix.nix (lib.desktop.monitors.*)
#
{ lib, ... }:
rec {
  # Helper to convert Nix attrs to gamescope command-line arguments
  toCliArgs =
    attrs:
    let
      argToString =
        name: value:
        if builtins.isBool value then if value then "--${name}" else "" else "--${name} ${toString value}";

      # Filter out empty strings to avoid extra spaces
      nonEmptyArgs = lib.filter (s: s != "") (lib.mapAttrsToList argToString attrs);
    in
    lib.concatStringsSep " " nonEmptyArgs;

  # Helper to convert Nix attrs to fish 'set -x' commands
  toEnvCommands =
    attrs:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "set -x ${name} '${toString value}'") attrs
    );

  # Ensure a value is an integer, ceiling floats
  toInt = value: if builtins.isInt value then value else builtins.ceil value;

  # Get monitor defaults for gamescope (uppercase convention)
  # Transforms lib.desktop.monitors.getDefaults output to gamescope format
  getMonitorDefaults =
    monitors:
    let
      defaults = lib.desktop.monitors.getDefaults monitors;
    in
    {
      WIDTH = defaults.width;
      HEIGHT = defaults.height;
      REFRESH_RATE = defaults.refreshRate;
      VRR = defaults.vrr;
      HDR = defaults.hdr;
    };
}
