{ lib }:

{
  # Helper to convert Nix attrs to gamescope command-line arguments
  toCliArgs =
    attrs:
    let
      argToString =
        name: value:
        if builtins.isBool value then
          lib.optionalString value "--${name}"
        else
          "--${name} ${toString value}";
    in
    lib.concatStringsSep " " (lib.mapAttrsToList argToString attrs);

  # Helper to convert Nix attrs to fish 'set -x' commands
  toEnvCommands =
    attrs:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "set -x ${name} '${toString value}'") attrs
    );

  getPrimaryMonitor = monitors: lib.findFirst (m: m.primary) null monitors;

  getMonitorDefaults = monitors: {
    WIDTH =
      let
        pm = lib.wayming.getPrimaryMonitor monitors;
      in
      if pm != null then pm.width else 1920;
    HEIGHT =
      let
        pm = lib.wayming.getPrimaryMonitor monitors;
      in
      if pm != null then pm.height else 1080;
    REFRESH_RATE =
      let
        pm = lib.wayming.getPrimaryMonitor monitors;
      in
      if pm != null then pm.refreshRate else 60;
    VRR =
      let
        pm = lib.wayming.getPrimaryMonitor monitors;
      in
      if pm != null then pm.vrr else false;
    HDR =
      let
        pm = lib.wayming.getPrimaryMonitor monitors;
      in
      if pm != null then pm.hdr else false;
  };
}
