{
  programs.nixvim.plugins = {
    treesitter = {
      enable = true;
      settings = {
        highlight.enable = true;
        indent.enable = true;
      };
    };

    nvim-autopairs.enable = true;
    nvim-surround.enable = true;
    guess-indent.enable = true;
    ts-autotag.enable = true;
    tmux-navigator.enable = true;

    markdown-preview = {
      enable = true;
      settings.filetypes = [ "markdown" ];
    };

    auto-session = {
      enable = true;
      settings = {
        log_level = "error";
        suppressed_dirs = [
          "~/"
          "~/Projects"
          "~/Downloads"
          "/"
        ];
        pre_save_cmds = [ "Neotree close" ];
        post_restore_cmds = [ "Neotree filesystem show" ];
      };
    };

    blink-cmp = {
      enable = true;
      settings = {
        keymap.preset = "default";
        completion.documentation.auto_show = true;
        signature.enabled = true;
        sources.default = [
          "lsp"
          "path"
          "snippets"
          "buffer"
        ];
      };
    };
    friendly-snippets.enable = true;
  };
}
