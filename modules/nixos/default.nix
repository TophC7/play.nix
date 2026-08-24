self: {
  imports = [
    ./amd.nix
    ./ananicy.nix
    ./gamemode.nix
    ./lutris.nix
    ./steam.nix
    ./switch2-controllers.nix
  ];

  # Pass inputs to all modules via _module.args
  _module.args = {
    inputs = self.inputs;
  };
}
