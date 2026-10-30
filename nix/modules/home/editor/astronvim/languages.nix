# Languages for Neovim: language servers, formatters and linters, one place
# (default.nix puts the tools on nvim's PATH and tells config/lua/nix.lua which
# ones to switch on; Mason, which used to do both, is off).
#
#   servers      <nvim-lspconfig server name> = package
#   formatters   <none-ls formatting builtin> = package   (formats on save)
#   linters      <none-ls diagnostics builtin> = package
#   extra        tools others need (no name to switch on)
#   serverCommands       <server> = absolute path: for a server whose name on
#                        PATH is taken by something else (rustup's proxy)
#   formatterFiletypes   <formatter> = [ filetypes ]: where that formatter applies
#                        (its default is wider than we want)
#   formattingDisabled   servers whose own formatting is switched off
#
# One formatter per language: a server that formats well (gopls, rust-analyzer,
# clangd with clang-format, jdtls, omnisharp, terraform-ls, taplo, lemminx) does
# it itself; where a dedicated formatter is used instead, the server's own is
# switched off (formattingDisabled), or both would run on every save. The names
# are checked when the configuration is built, so a typo fails the build
# instead of Neovim.
#
# Major languages and the formats everyone writes. Left out on purpose:
# niche and domain-specific languages, and toolchains of several GB (Haskell,
# Swift, Scala, Dart, ...): add one here when a project needs it.
{ pkgs }:
{
  bash = {
    servers.bashls = pkgs.bash-language-server; # runs shellcheck itself
    formatters.shfmt = pkgs.shfmt;
    formattingDisabled = [ "bashls" ];
    extra = [ pkgs.shellcheck ];
  };

  c-cpp.servers.clangd = pkgs.clang-tools; # formats with clang-format itself

  cmake.servers.cmake = pkgs.cmake-language-server;

  csharp.servers.omnisharp = pkgs.omnisharp-roslyn;

  docker = {
    servers = {
      dockerls = pkgs.dockerfile-language-server;
      docker_compose_language_service = pkgs.docker-compose-language-service;
    };
    linters.hadolint = pkgs.hadolint;
  };

  go.servers.gopls = pkgs.gopls; # formats (gofmt) and organizes imports

  java.servers.jdtls = pkgs.jdt-language-server;

  # JavaScript, TypeScript and the web
  web = {
    servers = {
      ts_ls = pkgs.typescript-language-server;
      eslint = pkgs.vscode-langservers-extracted;
      html = pkgs.vscode-langservers-extracted;
      cssls = pkgs.vscode-langservers-extracted;
      jsonls = pkgs.vscode-langservers-extracted;
      tailwindcss = pkgs.tailwindcss-language-server;
      svelte = pkgs.svelte-language-server;
    };
    formatters.prettierd = pkgs.prettierd;
    # not yaml (yamlfmt) and not the languages whose server formats
    formatterFiletypes.prettierd = [
      "javascript"
      "javascriptreact"
      "typescript"
      "typescriptreact"
      "css"
      "scss"
      "less"
      "html"
      "json"
      "jsonc"
      "markdown"
      "svelte"
    ];
    formattingDisabled = [
      "ts_ls"
      "html"
      "cssls"
      "jsonls"
      "svelte"
    ];
  };

  kotlin.servers.kotlin_language_server = pkgs.kotlin-language-server;

  latex.servers.texlab = pkgs.texlab;

  lua = {
    servers.lua_ls = pkgs.lua-language-server;
    formatters.stylua = pkgs.stylua;
    formattingDisabled = [ "lua_ls" ];
  };

  markdown.servers.marksman = pkgs.marksman;

  nix = {
    servers.nixd = pkgs.nixd;
    formatters.nixfmt = pkgs.nixfmt;
    formattingDisabled = [ "nixd" ];
    linters = { inherit (pkgs) statix deadnix; };
  };

  php.servers.phpactor = pkgs.phpactor;

  python = {
    servers = { inherit (pkgs) pyright ruff; }; # pyright: types, ruff: lint
    formatters.autopep8 = pkgs.python3Packages.autopep8; # (a custom source in nix.lua)
    formattingDisabled = [ "ruff" ];
  };

  ruby.servers.ruby_lsp = pkgs.ruby-lsp;

  rust = {
    servers.rust_analyzer = pkgs.rust-analyzer; # formats with rustfmt (rustup)
    # rustup's own `rust-analyzer` comes first on PATH, wants a component that is
    # not installed and then calls itself ("infinite recursion detected")
    serverCommands.rust_analyzer = "${pkgs.rust-analyzer}/bin/rust-analyzer";
  };

  terraform = {
    servers.terraformls = pkgs.terraform-ls;
    extra = [ pkgs.tflint ]; # a command-line tool (none-ls has no builtin for it)
  };

  toml.servers.taplo = pkgs.taplo;

  xml.servers.lemminx = pkgs.lemminx;

  yaml = {
    servers.yamlls = pkgs.yaml-language-server;
    formatters.yamlfmt = pkgs.yamlfmt;
    formattingDisabled = [ "yamlls" ];
  };

  # The grammars are built by Nix (all of them); the CLI is what
  # :checkhealth nvim-treesitter looks for, and for `tree-sitter parse` etc.
  treesitter.extra = [ pkgs.tree-sitter ];

  # snacks.nvim: pickers (ripgrep, fd), trash (glib), images
  snacks.extra = with pkgs; [
    glib
    imagemagick
    ripgrep
    fd
  ];
}
