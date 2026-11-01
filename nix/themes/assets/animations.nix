# Animation presets a theme picks from (`animation.preset` in catalogue.nix).
# Hyprland speeds are in tenths of a second (lower is faster); `speed` in the
# theme scales them all (and Noctalia's own animations): 2.0 is twice as fast.
# Add a preset: a `leaves` list (Hyprland animation leaves) and the wallpaper
# transition Noctalia plays (effects: fade wipe disc stripes zoom honeycomb
# vortex pixel diamond golden melt).
{ lib }:
let
  bezier = x1: y1: x2: y2: {
    type = "bezier";
    points = [
      [
        x1
        y1
      ]
      [
        x2
        y2
      ]
    ];
  };

  curves = {
    easeOutQuint = bezier 0.23 1 0.32 1;
    linear = bezier 0 0 1 1;
    almostLinear = bezier 0.5 0.5 0.75 1;
    quick = bezier 0.15 0 0.1 1;
    overshoot = bezier 0.34 1.56 0.64 1;
  };

  on =
    leaf: speed: curve: extra:
    {
      inherit leaf speed;
      enabled = true;
      bezier = curve;
    }
    // extra;
  off = leaf: {
    inherit leaf;
    enabled = false;
    speed = 1;
    bezier = "default";
  };
in
{
  inherit curves;

  presets = {
    # Hyprland's own defaults: the baseline of the default theme
    smooth = {
      leaves = [
        (on "global" 10 "default" { })
        (on "border" 5.39 "easeOutQuint" { })
        (on "windows" 4.79 "easeOutQuint" { })
        (on "windowsIn" 4.1 "easeOutQuint" { style = "popin 87%"; })
        (on "windowsOut" 1.49 "linear" { style = "popin 87%"; })
        (on "fade" 3.03 "quick" { })
        (on "layers" 3.81 "easeOutQuint" { })
        (on "workspaces" 1.94 "almostLinear" { style = "fade"; })
      ];
      wallpaper = {
        transition = [ "fade" ];
        duration = 500;
      };
    };

    # Short and direct: windows and workspaces slide
    snappy = {
      leaves = [
        (on "global" 6 "default" { })
        (on "border" 3.5 "easeOutQuint" { })
        (on "windows" 3 "easeOutQuint" { })
        (on "windowsIn" 2.6 "easeOutQuint" { style = "slide"; })
        (on "windowsOut" 1.2 "linear" { style = "slide"; })
        (on "fade" 2 "quick" { })
        (on "layers" 2.5 "easeOutQuint" { })
        (on "workspaces" 1.4 "quick" { style = "slide"; })
      ];
      wallpaper = {
        transition = [ "wipe" ];
        duration = 400;
      };
    };

    # Long and gentle
    slow = {
      leaves = [
        (on "global" 14 "default" { })
        (on "border" 8 "easeOutQuint" { })
        (on "windows" 7 "easeOutQuint" { })
        (on "windowsIn" 6.5 "easeOutQuint" { style = "popin 90%"; })
        (on "windowsOut" 3.5 "almostLinear" { style = "popin 90%"; })
        (on "fade" 5 "quick" { })
        (on "layers" 6 "easeOutQuint" { })
        (on "workspaces" 3.5 "almostLinear" { style = "fade"; })
      ];
      wallpaper = {
        transition = [ "fade" ];
        duration = 1000;
      };
    };

    # Windows and workspaces overshoot a little before settling
    bouncy = {
      leaves = [
        (on "global" 10 "default" { })
        (on "border" 5.39 "easeOutQuint" { })
        (on "windows" 5 "overshoot" { })
        (on "windowsIn" 4.5 "overshoot" { style = "popin 80%"; })
        (on "windowsOut" 2 "easeOutQuint" { style = "popin 80%"; })
        (on "fade" 3 "quick" { })
        (on "layers" 4 "easeOutQuint" { })
        (on "workspaces" 3 "overshoot" { style = "slide"; })
      ];
      wallpaper = {
        transition = [ "disc" ];
        duration = 700;
      };
    };

    # Only fades: nothing moves
    minimal = {
      leaves = [
        (on "global" 10 "default" { })
        (off "border")
        (off "windows")
        (off "windowsIn")
        (off "windowsOut")
        (on "fade" 2.5 "quick" { })
        (off "layers")
        (off "workspaces")
      ];
      wallpaper = {
        transition = [ "fade" ];
        duration = 250;
      };
    };

    # No animations at all
    none = {
      leaves = [ ];
      disabled = true;
      wallpaper = {
        transition = [ "fade" ];
        duration = 0;
      };
    };
  };

  # What a theme gets: the preset's leaves with speeds divided by the scale
  # (a faster theme has shorter durations), and the curves they use.
  resolve =
    preset: scale:
    let
      p = lib.removeAttrs preset [ "leaves" ];
      leaves = map (l: l // { speed = l.speed / scale; }) preset.leaves;
      used = lib.unique (lib.filter (c: c != "default") (map (l: l.bezier) leaves));
    in
    p
    // {
      inherit leaves;
      curves = lib.genAttrs used (name: curves.${name});
      enabled = !(preset.disabled or false);
    };
}
