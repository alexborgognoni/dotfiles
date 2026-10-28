let
  # Nerd Font glyphs as code points (private-use characters are easily lost).
  glyph = code: builtins.fromJSON ''"\u${code}"'';
in
{
  programs.nixvim.plugins = {
    lualine = {
      enable = true;
      settings.options = {
        theme = "auto";
        globalstatus = true;
        component_separators = "";
        section_separators = {
          left = glyph "e0b4";
          right = glyph "e0b6";
        };
      };
    };

    bufferline = {
      enable = true;
      settings.options = {
        diagnostics = "nvim_lsp";
        offsets = [
          {
            filetype = "neo-tree";
            text = "Explorer";
            highlight = "Directory";
            separator = true;
          }
        ];
      };
    };

    neo-tree = {
      enable = true;
      settings = {
        close_if_last_window = true;
        filesystem = {
          follow_current_file.enabled = true;
          use_libuv_file_watcher = true;
          filtered_items.hide_dotfiles = false;
        };
      };
    };

    which-key = {
      enable = true;
      settings.spec = [
        {
          __unkeyed-1 = "<leader>b";
          group = "Buffers";
        }
        {
          __unkeyed-1 = "<leader>f";
          group = "Find";
        }
        {
          __unkeyed-1 = "<leader>g";
          group = "Git";
        }
        {
          __unkeyed-1 = "<leader>l";
          group = "LSP";
        }
        {
          __unkeyed-1 = "<leader>t";
          group = "Terminal";
        }
        {
          __unkeyed-1 = "<leader>u";
          group = "UI";
        }
      ];
    };

    snacks = {
      enable = true;
      settings = {
        bigfile.enabled = true;
        # Explicit sections: the default preset's "startup" section needs lazy.nvim.
        dashboard = {
          enabled = true;
          sections = [
            { section = "header"; }
            {
              section = "keys";
              gap = 1;
              padding = 1;
            }
            {
              icon = glyph "f15b";
              title = "Recent Files";
              section = "recent_files";
              indent = 2;
              padding = 1;
            }
            {
              icon = glyph "f07b";
              title = "Projects";
              section = "projects";
              indent = 2;
              padding = 1;
            }
          ];
        };
        indent.enabled = true;
        input.enabled = true;
        picker = {
          enabled = true;
          ui_select = true;
        };
        quickfile.enabled = true;
        scope.enabled = true;
        words.enabled = true;
        lazygit.enabled = true;
      };
    };

    notify = {
      enable = true;
      settings.background_colour = "#000000";
    };

    # Settings carried over from chezmoi/dot_config/nvim/lua/plugins/user.lua
    noice = {
      enable = true;
      settings = {
        lsp = {
          override = {
            "vim.lsp.util.convert_input_to_markdown_lines" = true;
            "vim.lsp.util.stylize_markdown" = true;
            "cmp.entry.get_documentation" = true;
          };
          hover.enabled = false;
          signature.enabled = false;
        };
        presets = {
          command_palette = false;
          long_message_to_split = true;
          inc_rename = false;
          lsp_doc_border = false;
        };
        routes = [
          {
            filter = {
              event = "msg_show";
              kind = "";
              find = "written";
            };
            opts.skip = true;
          }
          {
            filter = {
              event = "msg_show";
              kind = "";
              find = "before";
            };
            opts.skip = true;
          }
        ];
      };
    };

    gitsigns.enable = true;
    todo-comments.enable = true;
    toggleterm = {
      enable = true;
      settings = {
        open_mapping = "[[<C-\\>]]";
        direction = "float";
      };
    };
  };
}
