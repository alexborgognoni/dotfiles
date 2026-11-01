# Font library: named entries a theme picks from (`mono`, `ui` in catalogue.nix).
# Add one: `key = { package = ...; name = "<family name>"; };` - the name is
# what `fc-list` shows (Nerd Fonts install "<Family> Nerd Font").
{ pkgs }:
let
  nerd = package: name: {
    inherit package;
    name = "${name} Nerd Font";
  };
  plain = package: name: { inherit package name; };
in
{
  # Terminal and editor
  mono = {
    jetbrains = nerd pkgs.nerd-fonts.jetbrains-mono "JetBrainsMono";
    monaspace = nerd pkgs.nerd-fonts.monaspace "MonaspiceNe";
    fira-code = nerd pkgs.nerd-fonts.fira-code "FiraCode";
    iosevka = nerd pkgs.nerd-fonts.iosevka-term "IosevkaTerm";
    commit = nerd pkgs.nerd-fonts.commit-mono "CommitMono";
    mononoki = nerd pkgs.nerd-fonts.mononoki "Mononoki";
    victor = nerd pkgs.nerd-fonts.victor-mono "VictorMono";
    meslo = nerd pkgs.nerd-fonts.meslo-lg "MesloLGL";
    lilex = nerd pkgs.nerd-fonts.lilex "Lilex";
    zed = nerd pkgs.nerd-fonts.zed-mono "ZedMono";
    fantasque = nerd pkgs.nerd-fonts.fantasque-sans-mono "FantasqueSansM";
    caskaydia = nerd pkgs.nerd-fonts.caskaydia-cove "CaskaydiaCove";
    sauce-code = nerd pkgs.nerd-fonts.sauce-code-pro "SauceCodePro";
  };

  # Applications and the desktop
  ui = {
    inter = plain pkgs.inter "Inter";
    geist = plain pkgs.geist-font "Geist";
    nunito = plain pkgs.nunito "Nunito";
    figtree = plain pkgs.figtree "Figtree";
    work-sans = plain pkgs.work-sans "Work Sans";
    overpass = plain pkgs.overpass "Overpass";
    quicksand = plain pkgs.quicksand "Quicksand";
    source-sans = plain pkgs.source-sans "Source Sans 3";
    noto-sans = plain pkgs.noto-fonts "Noto Sans";
    poppins = plain pkgs.poppins "Poppins";
    roboto = plain pkgs.roboto "Roboto";
  };

  serif = {
    noto-serif = plain pkgs.noto-fonts "Noto Serif";
  };
}
