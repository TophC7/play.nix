{ chaotic }:
{
  imports = [
    ./amd.nix
    ./ananicy.nix
    ./gamemode.nix
    ./lutris.nix
    (import ./steam.nix { inherit chaotic; })
  ];
}
