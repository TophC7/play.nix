inputs: {
  imports = [
    ./monitors.nix
    ./gamescoperun.nix
    ./wrappers.nix
  ];

  # Pass inputs to all modules via _module.args
  _module.args = { inherit inputs; };
}
