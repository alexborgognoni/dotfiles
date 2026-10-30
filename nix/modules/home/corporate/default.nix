# Corporate settings of the work profile (the company's laptop). Switched on by
# the profile; the root-level counterpart is modules/system-manager/corporate.nix.
#
#   zscaler.nix         Zscaler Client Connector tray: unit, launcher, sign-in links
#   entra-sso.nix       Entra ID single sign-on in Chrome
#   artifactory.nix     pip through the company's Artifactory mirror
#   network-rescue.nix  fix-zscaler, net-diag, net-rescue (scripts/)
#   identity.nix        the work identity (git email, keys, GitHub Enterprise)
#   claude.nix          Claude Code against the company's Vertex AI / Copilot
{ config, lib, ... }:
{
  imports = [
    ./artifactory.nix
    ./claude.nix
    ./entra-sso.nix
    ./identity.nix
    ./network-rescue.nix
    ./zscaler.nix
  ];

  options.my.corporate.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.my.profile == "work";
    defaultText = lib.literalExpression ''config.my.profile == "work"'';
    description = "The corporate settings (Zscaler, Entra SSO, Artifactory, company tools).";
  };
}
