# 🎮 play.nix

A NixOS flake for gaming on Wayland with Gamescope integration and declarative configuration.

## Features

- **Gamescope Integration**: Intelligent wrapper with monitor-aware defaults (HDR, VRR, resolution)
- **Advanced Configuration**: Global HDR/WSI/systemd defaults with per-wrapper overrides
- **Precedence System**: Wrapper-specific settings override global defaults and monitor configuration
- **Application Wrappers**: Create custom game launchers that run through Gamescope
- **Environment Control**: Dynamic environment variable discovery and display
- **Nested Session Detection**: Intelligent handling when already inside Gamescope
- **AMD GPU Support**: LACT daemon and performance optimizations  
- **Gaming Stack**: Steam with Proton-CachyOS, Lutris, Gamemode, and process scheduling

## Installation

Add to your `flake.nix`:

```nix
{
  inputs = {
    play-nix.url = "github:TophC7/play.nix";
    # chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable"; # Not needed, but useful
  };

  outputs = { play-nix, chaotic, ... }: {
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      modules = [
        play-nix.nixosModules.play
        # chaotic.nixosModules.default
      ];
    };
  };
}
```

## Configuration

### NixOS Configuration

```nix
play = {
  amd.enable = true;           # AMD GPU optimization
  steam.enable = true;         # Steam with Proton-CachyOS
  lutris.enable = true;        # Lutris game manager
  gamemode.enable = true;      # Performance optimization
  ananicy.enable = true;       # Process scheduling
};
```

### Home Manager Configuration

```nix
{
  config,
  osConfig, # This config only works with home-manager as a nixos module
  lib,
  pkgs,
  inputs, # Ensure inputs is available to your home-manager configuration
  ...
}:
{
  imports = [
    inputs.play.homeManagerModules.play
  ];

  play = {
    # Configure monitors for automatic gamescope settings
    monitors = [
      {
        name = "DP-1";
        primary = true;
        width = 2560;
        height = 1440;
        refreshRate = 144;
        hdr = true;
        vrr = true;
      }
    ];

    # Enable gamescope wrapper
    gamescoperun = {
      enable = true;
      
      # Global defaults for all wrappers (can be overridden per-wrapper)
      defaultHDR = false;     # Global HDR setting (overrides monitor HDR if needed)
      defaultWSI = true;      # Global WSI (Wayland Surface Interface) setting
      defaultSystemd = false; # Global systemd-run setting
      
      # Optional: Override base gamescope options
      baseOptions = {
        "fsr-upscaling" = true;
        "output-width" = 2560;   # Overrides monitor-derived width
      };
      
      # Optional: Override environment variables
      environment = {
        CUSTOM_VAR = "value";
      };
    };

    # Create application wrappers
    wrappers = {
      # If you wish to override the "steam" command/bin, remove "-gamescope"
      # Overriding the executables makes it so already existing .desktop launchers use the new wrapper
      steam-gamescope = {
        enable = true;
        # Note: Special case for steam, this is the pkg you should use
        # Also as of 07/23, steam does not open in normal "desktop mode" with gamescope
        # You can however exit big picture mode once already open to access the normal ui
        command = "${lib.getExe osConfig.programs.steam.package} -bigpicture -tenfoot";
        
        # Per-wrapper overrides (null = use global defaults)
        useHDR = true;        # Override: force HDR for Steam
        useWSI = null;        # Use global defaultWSI setting
        useSystemd = true;    # Override: use systemd-run for Steam
        
        extraOptions = {
          "steam" = true; # equivalent to --steam flag
        };
        environment = {
          STEAM_FORCE_DESKTOPUI_SCALING = 1;
          STEAM_GAMEPADUI = 1;
        };
      };

      lutris-gamescope = {
        enable = true;
        package = osConfig.play.lutris.package; # play.nix provides readonly packages
        
        # Per-wrapper configuration
        useHDR = false;       # Override: disable HDR for Lutris
        useWSI = true;        # Override: ensure WSI is enabled
        useSystemd = null;    # Use global defaultSystemd setting
        
        extraOptions = {
          "force-windows-fullscreen" = true;
        };
        environment = {
          LUTRIS_SKIP_INIT = 1;
        };
      };

      heroic-gamescope = {
        enable = true;
        package = pkgs.heroic;
        
        # Use all global defaults by omitting override options
        extraOptions."fsr-upscaling" = true;
      };
    };
  };

  # Recommendation: Override desktop entries to use gamescope wrappers
  xdg.desktopEntries = {
    steam = lib.mkDefault {
      name = "Steam";
      comment = "Steam Big Picture (Gamescope Session)";
      exec = "${lib.getExe config.play.wrappers.steam-gamescope.wrappedPackage}";
      icon = "steam";
      type = "Application";
      terminal = false;
      categories = [ "Game" ];
      mimeType = [
        "x-scheme-handler/steam"
        "x-scheme-handler/steamlink"
      ];
      settings = {
        StartupNotify = "true";
        StartupWMClass = "Steam";
        PrefersNonDefaultGPU = "true";
        X-KDE-RunOnDiscreteGpu = "true";
        Keywords = "gaming;";
      };
      actions = {
        client = {
          name = "Steam Client (No Gamescope)";
          exec = "${lib.getExe osConfig.programs.steam.package}";
        };
        steamdeck = {
          name = "Steam Deck (Gamescope)";
          exec = "${lib.getExe config.play.wrappers.steam-gamescope.wrappedPackage} -steamdeck -steamos3";
        };
      };
    };

    heroic = {
      name = "Heroic (Gamescope)";
      exec = "${lib.getExe config.play.wrappers.heroic-gamescope.wrappedPackage}";
      icon = "com.heroicgameslauncher.hgl";
      type = "Application";
      categories = [ "Game" ];
    };
  };
}
```

## Usage

```bash
# Basic usage
gamescoperun heroic

# With custom gamescope options
gamescoperun -x "--fsr-upscaling-sharpness 5" heroic

# Environment variables for wrapper communication
GAMESCOPE_USE_HDR=true gamescoperun steam     # Force HDR for this run
GAMESCOPE_USE_WSI=false gamescoperun lutris   # Disable WSI for this run
GAMESCOPE_USE_SYSTEMD=true gamescoperun heroic # Use systemd-run for this run

# Legacy environment variable support (discouraged)
GAMESCOPE_EXTRA_OPTS="--steam" gamescoperun steam
```

### Precedence System

The configuration follows a clear precedence hierarchy:

1. **Wrapper-specific settings** (`useHDR`, `useWSI`, `useSystemd`) - highest priority
2. **Global defaults** (`defaultHDR`, `defaultWSI`, `defaultSystemd`) 
3. **Monitor configuration** (HDR, VRR settings) - lowest priority

### Environment Display

The `gamescoperun` script automatically displays all relevant environment variables when starting and configures resolution, refresh rate, HDR, and VRR based on your primary monitor settings. It provides intelligent environment variable management with dynamic discovery and precedence-based overrides.

## Advanced Features

### HDR/WSI/Systemd Configuration

- **Global Defaults**: Set `defaultHDR`, `defaultWSI`, and `defaultSystemd` in `gamescoperun` configuration
- **Per-Wrapper Overrides**: Use `useHDR`, `useWSI`, and `useSystemd` in individual wrappers
- **Environment Communication**: Wrappers communicate with `gamescoperun` via environment variables

### Nested Session Detection  

If you're already inside a Gamescope session, `gamescoperun` intelligently detects this and runs commands directly without nesting.

## Troubleshooting

- **Environment Variables**: Run any wrapper to see current configuration displayed at startup
- **Precedence**: Check wrapper-specific → global defaults → monitor settings
- **Nested Sessions**: Commands run directly if already in Gamescope (check `$GAMESCOPE_WAYLAND_DISPLAY`)
- **Configuration**: Ensure exactly one monitor has `primary = true` and `inputs` is available
- **Steam Issues**: WSI and HDR can cause problems with Steam - try disabling them per-wrapper

## Requirements

- **NixOS** with Home Manager (as a NixOS module)
- **Chaotic Nix** (for latest Gamescope and Proton-GE) - optional but recommended
- **Wayland** desktop environment
- **Fish Shell** (used internally by wrappers and gamescoperun)
- At least one monitor configured with `primary = true`

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.