inputs: {
  imports = [
    ./amd.nix
    ./ananicy.nix
    ./gamemode.nix
    ./lutris.nix
    ./steam.nix
  ];

  # Pass inputs to all modules via _module.args
  _module.args = { inherit inputs; };
}
