# Firefox and Zen: no "wants to access devices on your local network" prompt
# behind Zscaler. Zscaler hands out synthetic addresses in 100.64.0.0/10 for
# the sites it tunnels, which the browsers' Local Network Access takes for the
# local network. Chrome, Chromium and Edge are told the range is public
# (modules/system-manager/corporate.nix); Firefox's overrides take single
# address:port entries, not ranges, and skip-domains is by host name, so the
# check is switched off here instead.
{
  config,
  lib,
  ...
}:
let
  settings."network.lna.enabled" = false;
in
{
  config = lib.mkIf (config.my.corporate.enable && config.my.features.gui.enable) {
    programs.firefox.profiles.default.settings = settings;
    programs.zen-browser.profiles.default.settings = settings;
  };
}
