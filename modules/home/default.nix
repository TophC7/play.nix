{ flake, ... }:
{ ... }:
{
  imports = [
    # Use mix.nix monitors module instead of local monitors.nix
    flake.inputs.mix-nix.homeManagerModules.monitors
    ./gamescoperun.nix
    ./wrappers.nix
  ];

  config = {
    # Pass play.nix's inputs to all modules via _module.args
    _module.args = {
      playInputs = flake.inputs;
      playLib = flake.lib;
    };
  };
}
