# Cursor library: named entries a theme picks from (`cursor` in catalogue.nix).
# `name` is the directory under share/icons that the package installs.
{ pkgs }:
let
  catppuccin = flavor: accent: {
    package =
      pkgs.catppuccin-cursors."${flavor}${pkgs.lib.toUpper (builtins.substring 0 1 accent)}${
        builtins.substring 1 (-1) accent
      }";
    name = "catppuccin-${flavor}-${accent}-cursors";
  };
  afterglow = scheme: color: {
    package = pkgs.afterglow-cursors-recolored;
    name = "Afterglow-Recolored-${scheme}-${color}";
  };
in
{
  bibata = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
  };
  catppuccin-macchiato = catppuccin "macchiato" "mauve";
  catppuccin-mocha = catppuccin "mocha" "mauve";
  catppuccin-latte = catppuccin "latte" "mauve";
  phinger-dark = {
    package = pkgs.phinger-cursors;
    name = "phinger-cursors-dark";
  };
  rose-pine = {
    package = pkgs.rose-pine-cursor;
    name = "BreezeX-RosePine-Linux";
  };
  nordzy = {
    package = pkgs.nordzy-cursor-theme;
    name = "Nordzy-cursors";
  };
  everforest = {
    package = pkgs.everforest-cursors;
    name = "everforest-cursors";
  };
  layan = {
    package = pkgs.layan-cursors;
    name = "layan-cursors";
  };
  gruvbox-orange = afterglow "Gruvbox" "Orange";
  gruvbox-black = afterglow "Gruvbox" "Black";
  dracula-purple = afterglow "Dracula" "Purple";
  capitaine = {
    package = pkgs.capitaine-cursors;
    name = "capitaine-cursors";
  };
  capitaine-white = {
    package = pkgs.capitaine-cursors;
    name = "capitaine-cursors-white";
  };
}
