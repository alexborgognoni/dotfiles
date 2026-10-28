# Language servers and formatters (previously installed by Mason via
# chezmoi/dot_config/nvim/lua/plugins/mason.lua).
{ pkgs, ... }:
{
  programs.nixvim = {
    plugins.lspconfig.enable = true;

    lsp.servers = {
      bashls.enable = true;
      eslint.enable = true;
      jsonls.enable = true;
      lua_ls.enable = true;
      nixd.enable = true;
      pyright.enable = true;
      ts_ls.enable = true;
      yamlls.enable = true;
    };

    plugins.conform-nvim = {
      enable = true;
      settings = {
        format_on_save = {
          timeout_ms = 1000;
          lsp_format = "fallback";
        };
        formatters_by_ft = {
          lua = [ "stylua" ];
          nix = [ "nixfmt" ];
          python = [ "autopep8" ];
          sh = [ "shfmt" ];
          bash = [ "shfmt" ];
          javascript = [ "prettierd" ];
          javascriptreact = [ "prettierd" ];
          typescript = [ "prettierd" ];
          typescriptreact = [ "prettierd" ];
          json = [ "prettierd" ];
          jsonc = [ "prettierd" ];
          css = [ "prettierd" ];
          html = [ "prettierd" ];
          markdown = [ "prettierd" ];
          yaml = [ "yamlfmt" ];
        };
      };
    };

    plugins.lint = {
      enable = true;
      lintersByFt = {
        sh = [ "shellcheck" ];
        bash = [ "shellcheck" ];
      };
    };

    extraPackages = with pkgs; [
      stylua
      nixfmt
      python3Packages.autopep8
      shfmt
      shellcheck
      prettierd
      yamlfmt
    ];
  };
}
