# Neovim, fully declared with nixvim: an AstroNvim-like setup rebuilt from
# chezmoi/dot_config/nvim. Plugins, language servers, formatters and
# treesitter grammars are all pinned through flake.lock (no lazy.nvim, no Mason).
{ inputs, pkgs, ... }:
{
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./options.nix
    ./keymaps.nix
    ./ui.nix
    ./editing.nix
    ./lsp.nix
    ./theme.nix
  ];

  stylix.targets.nixvim.enable = false;

  # Tools used by Snacks: trash for the explorer, ImageMagick for image previews.
  programs.nixvim.extraPackages = with pkgs; [
    glib
    imagemagick
  ];

  programs.nixvim = {
    enable = true;
    nixpkgs.source = inputs.nixpkgs;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Noice loads after Snacks and would otherwise own these prompts.
    extraConfigLuaPost = ''
      vim.ui.input = Snacks.input.input
      vim.ui.select = Snacks.picker.select
    '';
  };
}
