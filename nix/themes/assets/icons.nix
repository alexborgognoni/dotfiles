# Icon library: named entries a theme picks from (`icons` in catalogue.nix).
# `dark` and `light` are the theme names the package installs (Stylix picks by
# the theme's polarity). Nautilus and every GTK/Qt app draw their folder and
# file icons from this set.
{ pkgs }:
let
  papirus = color: {
    package = pkgs.papirus-icon-theme.override { inherit color; };
    dark = "Papirus-Dark";
    light = "Papirus-Light";
  };
  catppuccinPapirus = flavor: {
    package = pkgs.catppuccin-papirus-folders.override {
      inherit flavor;
      accent = "mauve";
    };
    dark = "Papirus-Dark";
    light = "Papirus-Light";
  };
  tela = color: {
    package = pkgs.tela-circle-icon-theme.override { colorVariants = [ color ]; };
    dark = "Tela-circle-${color}-dark";
    light = "Tela-circle-${color}-light";
  };
  colloid = scheme: Scheme: {
    package = pkgs.colloid-icon-theme.override { schemeVariants = [ scheme ]; };
    dark = "Colloid-${Scheme}-Dark";
    light = "Colloid-${Scheme}-Light";
  };
in
{
  papirus = {
    package = pkgs.papirus-icon-theme;
    dark = "Papirus-Dark";
    light = "Papirus-Light";
  };
  papirus-blue = papirus "blue";
  papirus-teal = papirus "teal";
  catppuccin-macchiato = catppuccinPapirus "macchiato";
  catppuccin-mocha = catppuccinPapirus "mocha";
  catppuccin-latte = catppuccinPapirus "latte";
  tela-blue = tela "blue";
  tela-purple = tela "purple";
  gruvbox-plus = {
    package = pkgs.gruvbox-plus-icons;
    dark = "Gruvbox-Plus-Dark";
    light = "Gruvbox-Plus-Light";
  };
  rose-pine = {
    package = pkgs.rose-pine-icon-theme;
    dark = "rose-pine";
    light = "rose-pine-dawn";
  };
  nordzy = {
    package = pkgs.nordzy-icon-theme;
    dark = "Nordzy-dark";
    light = "Nordzy";
  };
  everforest = colloid "everforest" "Everforest";
  kanagawa = {
    package = pkgs.kanagawa-icon-theme;
    dark = "Kanagawa";
    light = "Kanagawa";
  };
  dracula = colloid "dracula" "Dracula";
}
