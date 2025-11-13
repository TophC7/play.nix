self: {
  imports = [
    ./amd.nix
    ./ananicy.nix
    ./gamemode.nix
    ./lutris.nix
    ./procon2.nix
    ./steam.nix
  ];

  # Pass inputs to all modules via _module.args
  _module.args = {
    inputs = self.inputs;
  };
}
