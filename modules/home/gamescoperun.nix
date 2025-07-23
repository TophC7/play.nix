{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
## Test the package
# nix build .#proton-cachyos --no-link
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

  # Determine final HDR and WSI settings
  finalHDR = cfg.defaultHDR || HDR;
  finalWSI = cfg.defaultWSI;

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
    // lib.optionalAttrs finalHDR {
      hdr-enabled = true;
      hdr-debug-force-output = true;
      hdr-debug-force-support = true;
      hdr-itm-enable = true;
    }
    // lib.optionalAttrs VRR {
      adaptive-sync = true;
    };

  # Merge user options with defaults - user options override defaults
  finalBaseOptions = defaultBaseOptions // cfg.baseOptions;

  defaultEnvironment =
    {
      SDL_VIDEODRIVER = "wayland";
      AMD_VULKAN_ICD = "RADV";
      RADV_PERFTEST = "aco";
      DISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1 = 1;
      DISABLE_LAYER_NV_OPTIMUS_1 = 1;
      PROTON_ADD_CONFIG = "sdlinput,wayland";
    }
    // lib.optionalAttrs finalWSI {
      ENABLE_GAMESCOPE_WSI = 1;
      GAMESCOPE_WAYLAND_DISPLAY = "gamescope-0";
    }
    // lib.optionalAttrs finalHDR {
      ENABLE_HDR_WSI = 1;
      DXVK_HDR = 1;
      PROTON_ENABLE_HDR = 1;
    };

  # Merge user environment with defaults
  finalEnvironment = defaultEnvironment // cfg.environment;

  toEchoCommands =
    env:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: ''
        echo -e "    \033[1;33m${name}\033[0m=\033[0;35m${toString value}\033[0m"
      '') env
    );

  gamescoperun = pkgs.writeScriptBin "gamescoperun" ''
    #!${lib.getExe pkgs.fish}

    # Function to display the wrapper environment state
    function show_environment
        echo -e "\033[1;36m[gamescoperun]\033[0m Environment:"
        # Display environment from the module
        ${toEchoCommands finalEnvironment}

        # Display environment from the calling wrapper, if any
        if set -q GAMESCOPE_WRAPPER_ENV
            echo -e "    \033[1;36m(from wrapper)\033[0m"
            for pair in (string split ';' -- "$GAMESCOPE_WRAPPER_ENV")
                set parts (string split -m 1 '=' -- "$pair")
                if test (count $parts) -eq 2
                    echo -e "        \033[1;33m$parts[1]\033[0m=\033[0;35m$parts[2]\033[0m"
                end
            end
        end
    end

    # Check if we're already inside a Gamescope session
    if set -q GAMESCOPE_WAYLAND_DISPLAY
      echo "Already inside Gamescope session ($GAMESCOPE_WAYLAND_DISPLAY), running command directly..."
      exec $argv
    end

    # Set base environment variables from the module
    ${toEnvCommands finalEnvironment}

    # Process wrapper-specific settings and override base environment if needed
    if set -q GAMESCOPE_WRAPPER_ENV
        for pair in (string split ';' -- "$GAMESCOPE_WRAPPER_ENV")
            set parts (string split -m 1 '=' -- "$pair")
            if test (count $parts) -eq 2
                set -gx $parts[1] "$parts[2]"
            end
        end
    end

    # Handle wrapper-specific HDR settings
    if set -q GAMESCOPE_USE_HDR
        if test "$GAMESCOPE_USE_HDR" = "true"
            set -gx ENABLE_HDR_WSI 1
            set -gx DXVK_HDR 1
            set -gx PROTON_ENABLE_HDR 1
        else if test "$GAMESCOPE_USE_HDR" = "false"
            set -e ENABLE_HDR_WSI
            set -e DXVK_HDR
            set -e PROTON_ENABLE_HDR
        end
    end

    # Handle wrapper-specific WSI settings
    if set -q GAMESCOPE_USE_WSI
        if test "$GAMESCOPE_USE_WSI" = "true"
            set -gx ENABLE_GAMESCOPE_WSI 1
            set -gx GAMESCOPE_WAYLAND_DISPLAY "gamescope-0"
        else if test "$GAMESCOPE_USE_WSI" = "false"
            set -e ENABLE_GAMESCOPE_WSI
            set -e GAMESCOPE_WAYLAND_DISPLAY
        end
    end

    # Handle wrapper-specific HDR options in gamescope args
    if set -q GAMESCOPE_USE_HDR
        if test "$GAMESCOPE_USE_HDR" = "true"
            set -a final_args --hdr-enabled --hdr-debug-force-output --hdr-debug-force-support --hdr-itm-enable
        end
    else if test "${if finalHDR then "true" else "false"}" = "true"
        # Use default HDR settings if wrapper doesn't specify
        set -a final_args --hdr-enabled --hdr-debug-force-output --hdr-debug-force-support --hdr-itm-enable
    end

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

    # Show the environment and command being executed
    show_environment

    # Build and display the actual command being executed
    set -l use_systemd false

    # Check wrapper preference first (explicit 1 or 0), then fall back to default
    if set -q GAMESCOPE_USE_SYSTEMD
        if test "$GAMESCOPE_USE_SYSTEMD" = "1"
            set use_systemd true
        else if test "$GAMESCOPE_USE_SYSTEMD" = "0"
            set use_systemd false
        end
    else if test "${if cfg.defaultSystemd then "true" else "false"}" = "true"
        set use_systemd true
    end

    if test "$use_systemd" = "true"
      echo -e "\033[1;36m[gamescoperun]\033[0m Running: \033[1;34msystemd-run --user --quiet --same-dir --service-type=exec --setenv=DISPLAY --setenv=WAYLAND_DISPLAY\033[0m (with current env) \033[1;34m${lib.getExe gamescopePackages.gamescope}\033[0m $final_args \033[1;32m--\033[0m $argv"
      exec systemd-run --user --quiet --same-dir --service-type=exec --setenv=DISPLAY --setenv=WAYLAND_DISPLAY ${lib.getExe gamescopePackages.gamescope} $final_args -- $argv
    else
      echo -e "\033[1;36m[gamescoperun]\033[0m Running: \033[1;34m${lib.getExe gamescopePackages.gamescope}\033[0m $final_args \033[1;32m--\033[0m $argv"
      exec ${lib.getExe gamescopePackages.gamescope} $final_args -- $argv
    end
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

    defaultSystemd = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Default systemd-run setting for wrappers that don't specify useSystemd.";
    };

    defaultHDR = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Default HDR setting for wrappers that don't specify useHDR. Also applies when monitor HDR is false but you want to override it globally.";
    };

    defaultWSI = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Default WSI (Wayland Surface Interface) setting for wrappers that don't specify useWSI.";
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
