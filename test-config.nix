{ pkgs, lib, ... }:
{
  # Minimal system config
  system.stateVersion = "25.05";
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Minimal filesystem config
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # Modules
  play = {
    amd.enable = true; # AMD GPU optimization
    steam.enable = true; # Steam with Proton-CachyOS
    lutris.enable = true; # Lutris game manager
    gamemode.enable = true; # Performance optimization
    ananicy.enable = true; # Process scheduling
  };

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "steam"
      "steam-unwrapped"
      "steam-run"
    ];
}
