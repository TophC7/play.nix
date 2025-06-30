# 🎮 play.nix

A NixOS flake for gaming on Wayland with Gamescope integration and declarative configuration.

## Features

- **Gamescope Integration**: Intelligent wrapper with monitor-aware defaults (HDR, VRR, resolution)
- **Application Wrappers**: Create custom game launchers that run through Gamescope
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
play = {
  # Configure monitors for automatic gamescope settings
  monitors = [{
    name = "DP-1";
    primary = true;
    width = 2560;
    height = 1440;
    refreshRate = 165;
    hdr = true;
    vrr = true;
  }];

  # Enable gamescope wrapper
  gamescoperun.enable = true;
  
  # Create application wrappers
  wrappers = {
    # If you wish to override the "steam" command/bin, remove "-gamescope"
    # Overriding the executables makes it so already existing .desktop launchers use the new wrapper
    steam-gamescope = {
      enable = true;
      # Note: Special case for steam, this is the pkg you should use
      # Also sas of 06/25, steam does not open in normal "desktop mode" with gamescope
      # You can however exit big picture mode once already open to access the normal ui
      command = "${lib.getExe osConfig.programs.steam.package} -tenfoot -bigpicture";
      extraOptions = {
        "steam" = true;
      };
    };
    
    lutris-gamescope = {
      enable = true;
      package = osConfig.play.lutris.package; # play.nix provides readonly packages
      extraOptions."force-windows-fullscreen" = true;
    };

    heroic-gamescope = { 
      enable = true;
      package = pkgs.heroic;
      extraOptions."fsr-upscaling" = true;
    };
  };
};

# Recomendation: Override desktop entries to use gamescope wrappers
xdg.desktopEntries = {
  steam = {
    name = "Steam";
    comment = "Steam Big Picture (Gamescope Session)";
    exec = "${lib.getExe config.play.wrappers.steam.wrappedPackage}";
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
      bigpicture = {
        name = "Steam Client (No Gamescope)";
        exec = "${lib.getExe (config.play.steam.package or pkgs.steam)}";
      };
    };
  };
  
  heroic = {
    name = "Heroic (Gamescope)";
    exec = "${lib.getExe config.play.wrappers.heroic-gaming.wrappedPackage}";
    icon = "com.heroicgameslauncher.hgl";
    type = "Application";
    categories = [ "Game" ];
  };
};
```

## Usage

```bash
# Basic usage
gamescoperun heroic

# With custom options
gamescoperun -x "--fsr-upscaling-sharpness 5" heroic

# Legacy environment variable support
GAMESCOPE_EXTRA_OPTS="--steam" gamescoperun steam
```

The `gamescoperun` script automatically configures resolution, refresh rate, HDR, and VRR based on your primary monitor settings.

## Requirements

- NixOS with Home Manager
- Chaotic Nix (for latest Gamescope)
- Wayland desktop environment

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.