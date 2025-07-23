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
  inherit (playLib) toCliArgs getMonitorDefaults;

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

  # Base gamescope options derived from monitor configuration
  defaultBaseOptions = {
    backend = "sdl";
    fade-out-duration = 200;
    fullscreen = true;
    immediate-flips = true;
    nested-refresh = REFRESH_RATE;
    output-height = HEIGHT;
    output-width = WIDTH;
    rt = true;
  }
  // lib.optionalAttrs VRR {
    adaptive-sync = true;
  };

  # Merge user options with defaults - user options override defaults
  finalBaseOptions = defaultBaseOptions // cfg.baseOptions;

  # Base environment variables
  defaultEnvironment = {
    SDL_VIDEODRIVER = "wayland";
    AMD_VULKAN_ICD = "RADV";
    RADV_PERFTEST = "aco";
    DISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1 = 1;
    DISABLE_LAYER_NV_OPTIMUS_1 = 1;
    PROTON_ADD_CONFIG = "sdlinput,wayland";
    GAMESCOPE_WAYLAND_DISPLAY = "gamescope-0";
  }
  // lib.optionalAttrs finalWSI {
    ENABLE_GAMESCOPE_WSI = 1;
  }
  // lib.optionalAttrs finalHDR {
    ENABLE_HDR_WSI = 1;
    DXVK_HDR = 1;
    PROTON_ENABLE_HDR = 1;
  };

  # Merge user environment with defaults
  finalEnvironment = defaultEnvironment // cfg.environment;

  # Generate environment variable names for dynamic discovery
  # This ensures the environment display adapts to configuration changes
  baseEnvVars = lib.attrNames finalEnvironment;
  userEnvVars = lib.attrNames cfg.environment;
  allEnvVars = lib.unique (
    baseEnvVars
    ++ userEnvVars
    ++ [
      # Add wrapper communication variables
      "GAMESCOPE_USE_HDR"
      "GAMESCOPE_USE_WSI"
      "GAMESCOPE_USE_SYSTEMD"
      "GAMESCOPE_WRAPPER_ENV"
    ]
  );

  gamescoperun = pkgs.writeScriptBin "gamescoperun" ''
    #!${lib.getExe pkgs.fish}

    # Smart environment display function - dynamically discovers all relevant variables
    function show_environment
        echo -e "\033[1;36m[gamescoperun]\033[0m Environment:"
        
        # Dynamically check all configured environment variables
        for var in ${lib.concatStringsSep " " allEnvVars}
            if set -q $var
                set -l value (eval echo \$$var)
                if test -n "$value"
                    echo -e "    \033[1;33m$var\033[0m=\033[0;35m$value\033[0m"
                else
                    echo -e "    \033[1;33m$var\033[0m=\033[0;31m(empty/disabled)\033[0m"
                end
            end
        end
        
        # Show any additional environment variables that might be set by wrappers
        # but not in our known list (discovery mode)
        for var in (env | grep -E '^(GAMESCOPE_|ENABLE_|DXVK_|PROTON_|RADV_|AMD_|SDL_)' | cut -d= -f1 | sort -u)
            set -l already_shown false
            for known_var in ${lib.concatStringsSep " " allEnvVars}
                if test "$var" = "$known_var"
                    set already_shown true
                    break
                end
            end
            
            if not $already_shown
                if set -q $var
                    set -l value (eval echo \$$var)
                    echo -e "    \033[1;33m$var\033[0m=\033[0;35m$value\033[0m \033[0;90m(discovered)\033[0m"
                end
            end
        end
    end

    # Parse arguments early to handle -x flag properly
    argparse -i 'x/extra-args=' -- $argv
    if test $status -ne 0
        exit 1
    end

    # Early exit for nested gamescope sessions
    if set -q GAMESCOPE_WAYLAND_DISPLAY
        echo -e "\033[1;33m[gamescoperun]\033[0m Already inside Gamescope session ($GAMESCOPE_WAYLAND_DISPLAY), running command directly..."
        exec $argv
    end

    # Validate we have a command to run
    if test (count $argv) -eq 0
        echo "Usage: gamescoperun [-x|--extra-args \"<options>\"] <command> [args...]"
        echo ""
        echo "Examples:"
        echo "  gamescoperun heroic"
        echo "  gamescoperun -x \"--fsr-upscaling-sharpness 5\" steam"
        echo ""
        echo "Note: GAMESCOPE_EXTRA_OPTS is legacy - prefer using -x/--extra-args"
        exit 1
    end

    # Set base environment from Nix configuration
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: value: "set -gx ${name} ${lib.escapeShellArg (toString value)}"
      ) finalEnvironment
    )}

    # Process wrapper-specific environment overrides
    if set -q GAMESCOPE_WRAPPER_ENV
        for pair in (string split ';' -- "$GAMESCOPE_WRAPPER_ENV")
            if test -n "$pair"
                set parts (string split -m 1 '=' -- "$pair")
                if test (count $parts) -eq 2
                    set -gx $parts[1] "$parts[2]"
                end
            end
        end
    end

    function apply_wrapper_override
        set -l var_name $argv[1]
        set -l true_action $argv[2]
        set -l false_action $argv[3]
        
        if set -q $var_name
            set -l value (eval echo \$$var_name)
            switch "$value"
                case "true" "1"
                    eval $true_action
                case "false" "0"
                    eval $false_action
            end
        end
    end

    # HDR overrides
    apply_wrapper_override GAMESCOPE_USE_HDR \
        'set -gx ENABLE_HDR_WSI 1; set -gx DXVK_HDR 1; set -gx PROTON_ENABLE_HDR 1' \
        'set -gx ENABLE_HDR_WSI ""; set -gx DXVK_HDR ""; set -gx PROTON_ENABLE_HDR ""'

    # WSI overrides
    apply_wrapper_override GAMESCOPE_USE_WSI \
        'set -gx ENABLE_GAMESCOPE_WSI 1' \
        'set -gx ENABLE_GAMESCOPE_WSI ""'

    # Build gamescope arguments with proper precedence
    set -l final_args ${toCliArgs finalBaseOptions}

    # Add HDR args based on wrapper preference or global default
    set -l add_hdr_flags false
    if set -q GAMESCOPE_USE_HDR
        if test "$GAMESCOPE_USE_HDR" = "true"
            set add_hdr_flags true
        end
        # If GAMESCOPE_USE_HDR is "false", add_hdr_flags stays false
    else if test "${if finalHDR then "true" else "false"}" = "true"
        set add_hdr_flags true
    end

    if test "$add_hdr_flags" = "true"
        set -a final_args --hdr-enabled --hdr-debug-force-output --hdr-debug-force-support --hdr-itm-enable
    end

    # Add user-provided extra arguments (primary method)
    if set -q _flag_extra_args
        set -a final_args (string split ' ' -- $_flag_extra_args)
    end

    # Support legacy GAMESCOPE_EXTRA_OPTS (discouraged but functional)
    if set -q GAMESCOPE_EXTRA_OPTS
        echo -e "\033[1;33m[gamescoperun]\033[0m Warning: GAMESCOPE_EXTRA_OPTS is legacy, prefer -x/--extra-args"
        set -a final_args (string split ' ' -- $GAMESCOPE_EXTRA_OPTS)
    end

    # Determine systemd usage
    set -l use_systemd false
    if set -q GAMESCOPE_USE_SYSTEMD
        switch "$GAMESCOPE_USE_SYSTEMD"
            case "1" "true"
                set use_systemd true
            case "0" "false"
                set use_systemd false
        end
    else if test "${if cfg.defaultSystemd then "true" else "false"}" = "true"
        set use_systemd true
    end

    # Display final environment state for debugging
    show_environment

    # Execute gamescope with assembled configuration
    set -l gamescope_cmd ${lib.getExe gamescopePackages.gamescope}

    if test "$use_systemd" = "true"
        echo -e "\033[1;36m[gamescoperun]\033[0m Running: \033[1;34msystemd-run --user --quiet --same-dir --service-type=exec --setenv=DISPLAY --setenv=WAYLAND_DISPLAY\033[0m $gamescope_cmd $final_args \033[1;32m--\033[0m $argv"
        exec systemd-run --user --quiet --same-dir --service-type=exec --setenv=DISPLAY --setenv=WAYLAND_DISPLAY $gamescope_cmd $final_args -- $argv
    else
        echo -e "\033[1;36m[gamescoperun]\033[0m Running: \033[1;34m$gamescope_cmd\033[0m $final_args \033[1;32m--\033[0m $argv"
        exec $gamescope_cmd $final_args -- $argv
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
    home.packages = [
      cfg.package
    ]
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
