# Hyprland animation curves and timings (Hyprland's defaults).
{ config, lib, ... }:
{
  config = lib.mkIf config.my.features.desktop.enable {
    wayland.windowManager.hyprland.settings = {
      curve = [
        {
          _args = [
            "easeOutQuint"
            {
              type = "bezier";
              points = [
                [
                  0.23
                  1
                ]
                [
                  0.32
                  1
                ]
              ];
            }
          ];
        }
        {
          _args = [
            "linear"
            {
              type = "bezier";
              points = [
                [
                  0
                  0
                ]
                [
                  1
                  1
                ]
              ];
            }
          ];
        }
        {
          _args = [
            "almostLinear"
            {
              type = "bezier";
              points = [
                [
                  0.5
                  0.5
                ]
                [
                  0.75
                  1
                ]
              ];
            }
          ];
        }
        {
          _args = [
            "quick"
            {
              type = "bezier";
              points = [
                [
                  0.15
                  0
                ]
                [
                  0.1
                  1
                ]
              ];
            }
          ];
        }
      ];

      animation = map (a: { leaf = builtins.head a; } // builtins.elemAt a 1) [
        [
          "global"
          {
            enabled = true;
            speed = 10;
            bezier = "default";
          }
        ]
        [
          "border"
          {
            enabled = true;
            speed = 5.39;
            bezier = "easeOutQuint";
          }
        ]
        [
          "windows"
          {
            enabled = true;
            speed = 4.79;
            bezier = "easeOutQuint";
          }
        ]
        [
          "windowsIn"
          {
            enabled = true;
            speed = 4.1;
            bezier = "easeOutQuint";
            style = "popin 87%";
          }
        ]
        [
          "windowsOut"
          {
            enabled = true;
            speed = 1.49;
            bezier = "linear";
            style = "popin 87%";
          }
        ]
        [
          "fade"
          {
            enabled = true;
            speed = 3.03;
            bezier = "quick";
          }
        ]
        [
          "layers"
          {
            enabled = true;
            speed = 3.81;
            bezier = "easeOutQuint";
          }
        ]
        [
          "workspaces"
          {
            enabled = true;
            speed = 1.94;
            bezier = "almostLinear";
            style = "fade";
          }
        ]
      ];
    };
  };
}
