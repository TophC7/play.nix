# 🎮 play.nix

> A NixOS flake for gaming on Wayland with Gamescope integration and declarative configuration.
> 
> [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/TophC7/play.nix)

## Features

- **Gamescope Integration**: Intelligent wrapper with monitor-aware defaults (HDR, VRR, resolution)
- **Advanced Configuration**: Global HDR/WSI/systemd defaults with per-wrapper overrides
- **Precedence System**: Wrapper-specific settings override global defaults and monitor configuration
- **Application Wrappers**: Create custom game launchers that run through Gamescope
- **Environment Control**: Dynamic environment variable discovery and display
- **Nested Session Detection**: Intelligent handling when already inside Gamescope
- **AMD GPU Support**: LACT daemon and performance optimizations
- **Gaming Stack**: Steam with Proton-CachyOS and GE-Proton, Lutris, Heroic (sharing Steam's Proton builds), Gamemode, and process scheduling
- **Nintendo Switch 2 Controllers**: Wireless Pro Controller 2 and NSO GameCube support with rumble, motion, and battery reporting

## Installation

Add to your `flake.nix`:

```nix
{
  inputs = {
    play-nix.url = "github:TophC7/play.nix";
  };

  outputs = { play-nix, ... }: {
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      modules = [
        play-nix.nixosModules.play
      ];
    };
  };
}
```

> **Note**: play.nix uses [mix.nix](https://github.com/tophc7/mix.nix) internally for packages and monitor utilities. You don't need to add mix.nix to your inputs - it's handled automatically.

## Configuration

### NixOS Configuration

```nix
play = {
  amd.enable = true;           # AMD GPU optimization
  steam.enable = true;         # Steam with Proton-CachyOS and GE-Proton
  lutris.enable = true;        # Lutris game manager
  heroic.enable = true;        # Heroic, with Steam's Proton builds linked into
                               # ~/.config/heroic/tools/proton for every user
                               # under stable names (e.g. proton-cachyos)
  gamemode.enable = true;      # Performance optimization
  ananicy.enable = true;       # Process scheduling

  switch2Controllers = {
    enable = true;             # Wireless Nintendo Switch 2 controllers
    user = "toph";             # User that pairs and owns the controller config
  };
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
    inputs.play-nix.homeManagerModules.play
  ];

  # Configure monitors for automatic gamescope settings
  # Note: This is a top-level option, not under 'play'
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

  play = {
    # Enable gamescope wrapper
    gamescoperun = {
      enable = true;

      # Global defaults for all wrappers (can be overridden per-wrapper)
      defaultHDR = null;      # null = auto-detect monitor HDR (default), true/false = force on/off
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
        package = osConfig.play.heroic.package; # play.nix NixOS option

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

### Nintendo Switch 2 Controller Support

Enable the wireless bridge for the user who will pair controllers:

```nix
play.switch2Controllers = {
  enable = true;
  user = "toph";
};
```

After rebuilding, hold the controller's sync button, then run the one-shot
pairing service. It pauses the bridge while pairing and restarts it afterward:

```fish
sudo systemctl start switch2-controllers-pair
```

The service starts automatically on later boots once
`~/.config/nso-gc/config.json` exists.

**Supported hardware and features:**
- Nintendo Switch 2 Pro Controller and NSO GameCube controller are tested
- Buttons, sticks, rumble, gyro/accelerometer, and battery reporting
- Joy-Con 2 support remains experimental upstream
- Bluetooth LE only; the retired USB initializer is no longer provided

Inspect runtime state with:

```fish
switch2-controllers list
systemctl status switch2-controllers
journalctl -u switch2-controllers-pair -u switch2-controllers -f
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
  - `defaultHDR = null` (default): Auto-detects monitor HDR capability
  - `defaultHDR = true/false`: Forces HDR on/off globally
- **Per-Wrapper Overrides**: Use `useHDR`, `useWSI`, and `useSystemd` in individual wrappers
- **Environment Variables**: When HDR is enabled, sets `ENABLE_HDR_WSI=1` and `PROTON_ENABLE_HDR=1`
- **Environment Communication**: Wrappers communicate with `gamescoperun` via environment variables

### Nested Session Detection

If you're already inside a Gamescope session, `gamescoperun` intelligently detects this and runs commands directly without nesting.

## Troubleshooting

- **Environment Variables**: Run any wrapper to see current configuration displayed at startup
- **Precedence**: Check wrapper-specific → global defaults → monitor settings
- **Nested Sessions**: Commands run directly if already in Gamescope (check `$GAMESCOPE_WAYLAND_DISPLAY`)
- **Configuration**: Ensure exactly one monitor has `primary = true` and `inputs` is available
- **Steam Issues**: WSI and HDR can cause problems with Steam - try disabling them per-wrapper or globally

## Current Versions

- **Proton-CachyOS**: 10.0-20251107
- **Gamescope**: Latest from Chaotic Nix
- **Switch 2 Controllers**: Pinned from trevlars/switch2-controllers-linux

## Requirements

- **NixOS** with Home Manager (as a NixOS module)
- **Chaotic Nix** (for latest Gamescope and Proton-GE) - optional but recommended
- **Wayland** desktop environment
- **Fish Shell** (used internally by wrappers and gamescoperun)
- At least one monitor configured with `primary = true`

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.
