# Neovim: AstroNvim v6 with your own config (./config), every piece of it
# built by Nix:
#   - the AstroNvim distribution: flake input `astronvim` (pinned in flake.lock)
#   - its plugins: nixpkgs vimPlugins, collected in one directory that
#     lazy.nvim loads as "dev" plugins (it never downloads or updates)
#   - treesitter grammars, language servers, formatters: Nix (Mason is off);
#     which ones: languages.nix
# Neovim, the plugins and the tools come from nixpkgs-unstable (latest), like
# the other applications. They are updated with the rest: `nh home switch
# --update` (AstroNvim's own :AstroUpdate and lazy.nvim's updates are switched
# off: the plugin directory is read-only).
# Same technique as lazyvim-nix and nixCats' lazy.nvim wrapper.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  vp = pkgs.unstable.vimPlugins;

  # Languages (languages.nix): tools on PATH, and what nix.lua switches on
  languages = import ./languages.nix { pkgs = pkgs.unstable; };
  all = lib.attrValues languages;
  merged = key: lib.foldl' (acc: language: acc // (language.${key} or { })) { } all;
  servers = merged "servers";
  formatters = merged "formatters";
  linters = merged "linters";
  tools = lib.unique (
    lib.attrValues servers
    ++ lib.attrValues formatters
    ++ lib.attrValues linters
    ++ lib.concatMap (language: language.extra or [ ]) all
  );

  # The names must exist in the plugins that use them: a typo fails the build,
  # not Neovim at startup. (autopep8 is a custom source in nix.lua.)
  languagesCheck = pkgs.runCommand "astronvim-languages-check" { } ''
    missing() { echo "languages.nix: $1 $2 does not exist" >&2; exit 1; }
    ${lib.concatMapStrings (name: ''
      [ -e ${vp.nvim-lspconfig}/lsp/${name}.lua ] || missing "language server" ${name}
    '') (lib.attrNames servers)}
    ${lib.concatMapStrings (name: ''
      [ -e ${vp.none-ls-nvim}/lua/null-ls/builtins/formatting/${name}.lua ] || missing "formatter" ${name}
    '') (lib.remove "autopep8" (lib.attrNames formatters))}
    ${lib.concatMapStrings (name: ''
      [ -e ${vp.none-ls-nvim}/lua/null-ls/builtins/diagnostics/${name}.lua ] || missing "linter" ${name}
    '') (lib.attrNames linters)}
    touch $out
  '';

  # What nix.lua reads (vim.g.nix_languages)
  languagesJson = builtins.toJSON {
    servers = lib.attrNames servers;
    formatters = lib.attrNames formatters;
    linters = lib.attrNames linters;
    formattingDisabled = lib.concatMap (language: language.formattingDisabled or [ ]) all;
    formatterFiletypes = merged "formatterFiletypes";
    serverCommands = merged "serverCommands";
  };

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
    inherit (vp)
      astrocore
      astrolsp
      astrotheme
      astroui
      ;
    LuaSnip = vp.luasnip;
    "aerial.nvim" = vp.aerial-nvim;
    "better-escape.nvim" = vp.better-escape-nvim;
    "blink.cmp" = vp.blink-cmp;
    "blink.compat" = vp.blink-compat;
    inherit (vp) cmp-dap friendly-snippets;
    "gitsigns.nvim" = vp.gitsigns-nvim;
    "guess-indent.nvim" = vp.guess-indent-nvim;
    "heirline.nvim" = vp.heirline-nvim;
    "lazydev.nvim" = vp.lazydev-nvim;
    "mini.icons" = vp.mini-icons;
    "neo-tree.nvim" = vp.neo-tree-nvim;
    "none-ls.nvim" = vp.none-ls-nvim;
    "nui.nvim" = vp.nui-nvim;
    inherit (vp)
      nvim-autopairs
      nvim-dap
      nvim-dap-ui
      nvim-highlight-colors
      nvim-lspconfig
      nvim-nio
      ;
    nvim-treesitter = treesitter;
    inherit (vp) nvim-treesitter-textobjects nvim-ts-autotag nvim-window-picker;
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
    inherit (vp) nvim-notify;
    "markdown-preview.nvim" = vp.markdown-preview-nvim;
    inherit (vp) auto-session vim-tmux-navigator;
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
    package = pkgs.unstable.neovim-unwrapped;
    withRuby = false;
    withPython3 = false;

    # Mason's job: language servers, formatters and linters on nvim's PATH
    extraPackages = tools;

    initLua = ''
      -- Paths from Nix (modules/home/editor/astronvim); the rest is ./config
      vim.g.nix_lazy_plugins = "${pluginDir}"
      vim.g.nix_theme_file = "${config.my.themeState}/current/nvim.lua"
      vim.g.nix_languages = vim.json.decode [==[${languagesJson}]==]
      vim.g.nix_languages_check = "${languagesCheck}"
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
