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

  getPrimaryMonitor = monitors: lib.findFirst (m: m.primary) null monitors;

  # Ensure a value is an integer, ceiling floats
  toInt = value:
    if builtins.isInt value then value
    else builtins.ceil value;

  getMonitorDefaults =
    monitors:
    let
      getPrimary = getPrimaryMonitor monitors;
    in
    {
      WIDTH = if getPrimary != null then getPrimary.width else 1920;
      HEIGHT = if getPrimary != null then getPrimary.height else 1080;
      REFRESH_RATE = if getPrimary != null then toInt getPrimary.refreshRate else 60;
      VRR = if getPrimary != null then getPrimary.vrr else false;
      HDR = if getPrimary != null then getPrimary.hdr else false;
    };
}
