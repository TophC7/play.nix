# Wireless Nintendo Switch 2 controller bridge
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.play.switch2Controllers;
  system = pkgs.stdenv.hostPlatform.system;
  user = config.users.users.${cfg.user} or null;
  userHome = if user == null then "/var/empty" else user.home;
  userGroup = if user == null then "root" else user.group;

  bridgePackage = inputs.mix-nix.packages.${system}.switch2-controllers.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      # Replace upstream's broad passwordless-sudo assumption with the module's
      # single-purpose privileged helper.
      substituteInPlace ngc/bridge.py \
        --replace-fail \
          '["sudo", "-n", "btmgmt", "-i", idx, "stop-find", "-l"]' \
          '["/run/wrappers/bin/switch2-stop-discovery", idx]'
    '';
  });

  stopDiscoverySource = pkgs.writeText "switch2-stop-discovery.c" ''
    #include <string.h>
    #include <unistd.h>

    int main(int argc, char **argv) {
      if (argc != 2 || !argv[1][0] || strspn(argv[1], "0123456789") != strlen(argv[1]))
        return 64;

      execl(
        "${lib.getExe' config.hardware.bluetooth.package "btmgmt"}",
        "btmgmt", "-i", argv[1], "stop-find", "-l", (char *) 0
      );
      return 71;
    }
  '';

  stopDiscovery = pkgs.runCommandCC "switch2-stop-discovery" { } ''
    $CC -O2 -Wall -Werror ${stopDiscoverySource} -o $out
  '';

  serviceEnvironment = {
    HOME = userHome;
    XDG_CONFIG_HOME = "${userHome}/.config";
    PYTHONUNBUFFERED = "1";
  };

  commonServiceConfig = {
    User = cfg.user;
    SupplementaryGroups = [ "switch2-controllers" ];
    ProtectSystem = "strict";
    ProtectHome = "tmpfs";
    BindPaths = [ "${userHome}/.config/nso-gc" ];
    ReadWritePaths = [ "${userHome}/.config/nso-gc" ];
    PrivateTmp = true;
    ProtectControlGroups = true;
    ProtectKernelTunables = true;
    LockPersonality = true;
    UMask = "0077";
  };
in
{
  options.play.switch2Controllers = {
    enable = lib.mkEnableOption "wireless Nintendo Switch 2 controller support";

    user = lib.mkOption {
      type = lib.types.str;
      example = "toph";
      description = "User that owns the controller configuration and bridge process";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = user != null && (user.isNormalUser || user.isSystemUser);
        message = "play.switch2Controllers.user must name an existing NixOS user";
      }
    ];

    hardware = {
      bluetooth = {
        enable = lib.mkDefault true;
        powerOnBoot = lib.mkDefault true;
      };
      uinput.enable = true;
    };

    environment.systemPackages = [ bridgePackage ];
    users.groups.switch2-controllers = { };
    systemd.tmpfiles.rules = [
      "d ${userHome}/.config/nso-gc 0700 ${cfg.user} ${userGroup} - -"
    ];

    # Upstream needs one privileged operation to stop competing BLE discovery.
    # Keep it behind a compiled fixed-command helper instead of exposing btmgmt.
    security.wrappers.switch2-stop-discovery = {
      source = stopDiscovery;
      owner = "root";
      group = "switch2-controllers";
      permissions = "u+rx,g+rx,o-rwx";
      setuid = true;
    };

    systemd.services = {
      switch2-controllers = {
        description = "Nintendo Switch 2 wireless controller bridge";
        documentation = [ "https://github.com/trevlars/switch2-controllers-linux" ];
        wantedBy = [ "multi-user.target" ];
        wants = [ "bluetooth.service" ];
        after = [ "bluetooth.service" ];
        environment = serviceEnvironment;
        unitConfig.ConditionPathExists = "${userHome}/.config/nso-gc/config.json";
        serviceConfig = commonServiceConfig // {
          Type = "simple";
          SupplementaryGroups = [
            "switch2-controllers"
            "uinput"
          ];
          ExecStart = "${lib.getExe bridgePackage} run";
          Restart = "on-failure";
          RestartSec = 3;
        };
      };

      switch2-controllers-pair = {
        description = "Pair a Nintendo Switch 2 wireless controller";
        wants = [ "bluetooth.service" ];
        after = [ "bluetooth.service" ];
        environment = serviceEnvironment;
        serviceConfig = commonServiceConfig // {
          Type = "oneshot";
          ExecStartPre = "+${pkgs.systemd}/bin/systemctl stop switch2-controllers.service";
          ExecStart = "${lib.getExe bridgePackage} pair";
          ExecStopPost = "+${pkgs.systemd}/bin/systemctl start switch2-controllers.service";
        };
      };
    };
  };
}
