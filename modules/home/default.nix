{ lib, flake }:
{ config, pkgs, ... }:
{
  imports = [
    # Use mix.nix monitors module instead of local monitors.nix
    flake.inputs.mix-nix.homeManagerModules.monitors
    ./gamescoperun.nix
    ./wrappers.nix
  ];

  options = {
    # Deprecated option for migration warning
    play.monitors = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [ ];
      visible = false;
      description = "DEPRECATED: Use 'monitors' instead of 'play.monitors'";
    };
  };

  config = {
    # Migration warning for users still using play.monitors
    assertions = [
      {
        assertion = config.play.monitors == [ ];
        message = ''
          'play.monitors' has been removed in favor of 'monitors' from mix.nix.

          Please update your configuration:

            # Before
            play.monitors = [ ... ];

            # After
            monitors = [ ... ];

          The option schema remains the same, only the namespace changed.
        '';
      }
    ];

    # Pass play.nix's inputs to all modules via _module.args
    _module.args = {
      inputs = flake.inputs;
      playLib = flake.lib;
    };
  };
}
