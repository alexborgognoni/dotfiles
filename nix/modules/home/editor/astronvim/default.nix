# Neovim: AstroNvim v6 with your own config (./config), every piece of it
# built by Nix:
#   - the AstroNvim distribution: flake input `astronvim` (pinned in flake.lock)
#   - its plugins: nixpkgs vimPlugins, collected in one directory that
#     lazy.nvim loads as "dev" plugins (it never downloads or updates)
#   - treesitter grammars, language servers, formatters: Nix (Mason is off)
# Same technique as lazyvim-nix and nixCats' lazy.nvim wrapper.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  vp = pkgs.vimPlugins;

  # nvim-treesitter with every grammar (parsers and queries of matching
  # versions) merged into one directory, which is also its install_dir
  # (config/lua/nix.lua), so it reports them all as installed.
  treesitter = pkgs.symlinkJoin {
    name = "nvim-treesitter";
    paths = [ vp.nvim-treesitter ] ++ vp.nvim-treesitter.withAllGrammars.dependencies;
  };

  # lazy.nvim name (the repository name) -> plugin: everything AstroNvim v6
  # loads (lua/astronvim/plugins) plus your own plugins.
  plugins = {
    AstroNvim = pkgs.runCommand "astronvim" { } "cp -r ${inputs.astronvim} $out";
    "lazy.nvim" = vp.lazy-nvim;
    astrocore = vp.astrocore;
    astrolsp = vp.astrolsp;
    astrotheme = vp.astrotheme;
    astroui = vp.astroui;
    LuaSnip = vp.luasnip;
    "aerial.nvim" = vp.aerial-nvim;
    "better-escape.nvim" = vp.better-escape-nvim;
    "blink.cmp" = vp.blink-cmp;
    "blink.compat" = vp.blink-compat;
    cmp-dap = vp.cmp-dap;
    friendly-snippets = vp.friendly-snippets;
    "gitsigns.nvim" = vp.gitsigns-nvim;
    "guess-indent.nvim" = vp.guess-indent-nvim;
    "heirline.nvim" = vp.heirline-nvim;
    "lazydev.nvim" = vp.lazydev-nvim;
    "mini.icons" = vp.mini-icons;
    "neo-tree.nvim" = vp.neo-tree-nvim;
    "none-ls.nvim" = vp.none-ls-nvim;
    "nui.nvim" = vp.nui-nvim;
    nvim-autopairs = vp.nvim-autopairs;
    nvim-dap = vp.nvim-dap;
    nvim-dap-ui = vp.nvim-dap-ui;
    nvim-highlight-colors = vp.nvim-highlight-colors;
    nvim-lspconfig = vp.nvim-lspconfig;
    nvim-nio = vp.nvim-nio;
    nvim-treesitter = treesitter;
    nvim-treesitter-textobjects = vp.nvim-treesitter-textobjects;
    nvim-ts-autotag = vp.nvim-ts-autotag;
    nvim-window-picker = vp.nvim-window-picker;
    "plenary.nvim" = vp.plenary-nvim;
    "resession.nvim" = vp.resession-nvim;
    "smart-splits.nvim" = vp.smart-splits-nvim;
    "snacks.nvim" = vp.snacks-nvim;
    "todo-comments.nvim" = vp.todo-comments-nvim;
    "toggleterm.nvim" = vp.toggleterm-nvim;
    "which-key.nvim" = vp.which-key-nvim;
    # your plugins (config/lua/plugins/user.lua)
    nvim = vp.catppuccin-nvim;
    "noice.nvim" = vp.noice-nvim;
    nvim-notify = vp.nvim-notify;
    "markdown-preview.nvim" = vp.markdown-preview-nvim;
    auto-session = vp.auto-session;
    vim-tmux-navigator = vp.vim-tmux-navigator;
    # live theme (config/colors/theme.lua)
    "mini.base16" = vp.mini-base16;
  };

  pluginDir = pkgs.linkFarm "astronvim-plugins" (lib.mapAttrs (_: p: "${p}") plugins);
in
{
  stylix.targets.neovim.enable = false;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;

    # Mason's job: language servers and formatters on nvim's PATH
    extraPackages = with pkgs; [
      # language servers (config/lua/nix.lua)
      bash-language-server
      vscode-langservers-extracted # eslint, jsonls
      lua-language-server
      nixd
      pyright
      typescript-language-server
      yaml-language-server
      # formatters and linters
      python3Packages.autopep8
      nixfmt
      prettierd
      shellcheck
      shfmt
      stylua
      yamlfmt
      # used by snacks.nvim: pickers (ripgrep, fd), trash (glib), images
      glib
      imagemagick
      ripgrep
      fd
    ];

    initLua = ''
      -- Paths from Nix (modules/home/editor/astronvim); the rest is ./config
      vim.g.nix_lazy_plugins = "${pluginDir}"
      vim.g.nix_theme_file = "${config.my.themeState}/current/nvim.lua"
      vim.opt.rtp:prepend "${pluginDir}/lazy.nvim"
      require "lazy_setup"
      require "polish"
    '';
  };

  # Your AstroNvim config (lua/, colors/, tool configs), linked file by file
  # so lazy.nvim and neoconf can still write their state elsewhere.
  xdg.configFile = lib.mapAttrs' (
    name: _: lib.nameValuePair "nvim/${name}" { source = ./config/${name}; }
  ) (builtins.readDir ./config);
}
