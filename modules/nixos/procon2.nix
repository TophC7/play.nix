# Nintendo Switch 2 Pro Controller support
# Package (procon2-init) comes directly from mix.nix
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  cfg = config.play.procon2;
  # Package provided directly by mix.nix (no overlay needed for users)
  procon2-init = inputs.mix-nix.packages.${pkgs.system}.procon2-init;
in
{
  options.play.procon2 = {
    enable = mkEnableOption "Nintendo Switch 2 Pro Controller support";
  };

  config = mkIf cfg.enable {
    # Add the initialization tool to system packages
    environment.systemPackages = [ procon2-init ];

    # Udev rules for Nintendo Pro Controller 2
    services.udev.extraRules = ''
      # Nintendo Pro Controller 2 (USB mode) - idVendor: 057e, idProduct: 2069
      SUBSYSTEM=="usb", ATTR{idVendor}=="057e", ATTR{idProduct}=="2069", MODE="0666"

      # Auto-initialize when plugged in
      SUBSYSTEM=="usb", ATTR{idVendor}=="057e", ATTR{idProduct}=="2069", ACTION=="add", RUN+="${procon2-init}/bin/procon2-init"
    '';

    # Ensure users are in the input group for gamepad access
    users.groups.input = { };
  };
}
