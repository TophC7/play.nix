{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

let
  # Extend lib with play utilities
  playLib = import ../../lib { inherit lib; };

  cfg = config.play.gamescoperun;

  # Use shared lib functions
  inherit (playLib) toCliArgs toEnvCommands getMonitorDefaults;

  monitorDefaults = getMonitorDefaults config.play.monitors;
  inherit (monitorDefaults)
    WIDTH
    HEIGHT
    REFRESH_RATE
    VRR
    HDR
    ;

  # Select gamescope packages based on useGit option
  gamescopePackages =
    if cfg.useGit then
      {
        gamescope = inputs.chaotic.legacyPackages.${pkgs.system}.gamescope_git;
        gamescope-wsi = inputs.chaotic.legacyPackages.${pkgs.system}.gamescope-wsi_git;
      }
    else
      {
        gamescope = pkgs.gamescope;
        gamescope-wsi = pkgs.gamescope-wsi or null;
      };

  defaultBaseOptions =
    {
      backend = "sdl";
      fade-out-duration = 200;
      fullscreen = true;
      immediate-flips = true;
      nested-refresh = REFRESH_RATE;
      output-height = HEIGHT;
      output-width = WIDTH;
      rt = true;
    }
    // lib.optionalAttrs HDR {
      hdr-enabled = true;
      hdr-debug-force-output = true;
      hdr-itm-enable = true;
    }
    // lib.optionalAttrs VRR {
      adaptive-sync = true;
    };

  # Merge user options with defaults - user options override defaults
  finalBaseOptions = defaultBaseOptions // cfg.baseOptions;

  defaultEnvironment =
    {
      ENABLE_GAMESCOPE_WSI = 1;
      GAMESCOPE_WAYLAND_DISPLAY = "gamescope-0";
      PROTON_USE_SDL = 1;
      PROTON_USE_WAYLAND = 1;
      SDL_VIDEODRIVER = "wayland";
      AMD_VULKAN_ICD = "RADV";
      RADV_PERFTEST = "aco";
      DISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1 = 1;
      DISABLE_LAYER_NV_OPTIMUS_1 = 1;
    }
    // lib.optionalAttrs HDR {
      ENABLE_HDR_WSI = 1;
      DXVK_HDR = 1;
      PROTON_ENABLE_HDR = 1;
    };

  # Merge user environment with defaults
  finalEnvironment = defaultEnvironment // cfg.environment;

  gamescoperun = pkgs.writeScriptBin "gamescoperun" ''
    #!${lib.getExe pkgs.fish}

    # Check if we're already inside a Gamescope session
    if set -q GAMESCOPE_WAYLAND_DISPLAY
      echo "Already inside Gamescope session ($GAMESCOPE_WAYLAND_DISPLAY), running command directly..."
      exec $argv
    end

    # Set environment variables for the gamescope session
    ${toEnvCommands finalEnvironment}

    # Define and parse arguments using fish's built-in argparse
    argparse -i 'x/extra-args=' -- $argv
    if test $status -ne 0
      exit 1
    end

    # Check if we have a command to run
    if test (count $argv) -eq 0
      echo "Usage: gamescoperun [-x|--extra-args \"<options>\"] <command> [args...]"
      echo ""
      echo "Examples:"
      echo "  gamescoperun heroic"
      echo "  gamescoperun -x \"--fsr-upscaling-sharpness 5\" steam"
      echo "  GAMESCOPE_EXTRA_OPTS=\"--fsr\" gamescoperun steam (legacy)"
      exit 1
    end

    # Combine base args, extra args from CLI, and extra args from env (for legacy)
    set -l final_args ${toCliArgs finalBaseOptions}

    # Add args from -x/--extra-args flag, splitting the string into a list
    if set -q _flag_extra_args
        set -a final_args (string split ' ' -- $_flag_extra_args)
    end

    # For legacy support, add args from GAMESCOPE_EXTRA_OPTS if it exists
    if set -q GAMESCOPE_EXTRA_OPTS
        set -a final_args (string split ' ' -- $GAMESCOPE_EXTRA_OPTS)
    end

    # Show the command being executed
    echo -e "\033[1;36m[gamescoperun]\033[0m Running: \033[1;34m${lib.getExe gamescopePackages.gamescope}\033[0m $final_args \033[1;32m--\033[0m $argv"

    # Execute gamescope with the final arguments and the command
    exec ${lib.getExe gamescopePackages.gamescope} $final_args -- $argv
  '';
in
{
  options.play.gamescoperun = {
    enable = lib.mkEnableOption "gamescoperun, a wrapper for gamescope";

    useGit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use git versions of gamescope from chaotic-nyx for latest features";
    };

    baseOptions = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          str
          int
          bool
        ]);
      default = { };
      example = {
        "fsr-upscaling" = true;
        "output-width" = 2560;
      };
      description = ''
        Base command-line options to always pass to gamescope.
        Option names must match gamescope's flags exactly (e.g., "hdr-enabled").
        Monitor-derived options (width, height, refresh rate, HDR, VRR) are set automatically
        but can be overridden here.
      '';
    };

    environment = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          str
          int
        ]);
      default = { };
      description = ''
        Environment variables to set within the gamescoperun script.
        HDR-related variables are set automatically based on monitor configuration
        but can be overridden here.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = gamescoperun;
      description = "The configured gamescoperun package";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      [ cfg.package ]
      ++ [ gamescopePackages.gamescope ]
      ++ lib.optionals (gamescopePackages.gamescope-wsi != null) [ gamescopePackages.gamescope-wsi ];

    # Assertion to ensure monitors are configured if gamescoperun is enabled
    assertions = [
      {
        assertion = cfg.enable -> (lib.length config.play.monitors > 0);
        message = "play.gamescoperun requires at least one monitor to be configured in play.monitors";
      }
      {
        assertion = cfg.enable -> (lib.length (lib.filter (m: m.primary) config.play.monitors) == 1);
        message = "play.gamescoperun requires exactly one primary monitor to be configured";
      }
    ];
  };
}
