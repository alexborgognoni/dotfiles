return {
  -- {
  --   "kelly-lin/ranger.nvim",
  --   config = function()
  --     require("ranger-nvim").setup { replace_netrw = true }
  --     vim.api.nvim_set_keymap("n", "<leader>r", "", {
  --       noremap = true,
  --       callback = function() require("ranger-nvim").open(true) end,
  --     })
  --   end,
  -- },
  -- {
  --   "lukas-reineke/indent-blankline.nvim",
  --   main = "ibl",
  --   ---@module "ibl"
  --   ---@type ibl.config
  --   config = function() require("ibl").setup() end,
  -- },
  -- {
  --   "hrsh7th/nvim-cmp",
  --   opts = function(_, opts)
  --     require("cmp").setup {
  --       view = {
  --         entries = {
  --           vertical_positioning = "below",
  --         },
  --       },
  --     }
  --   end,
  -- },
  {
    "ray-x/lsp_signature.nvim",
    lazy = true,
    event = "VeryLazy",
    opts = {},
    config = function()
      require("lsp_signature").setup {
        floating_window_above_cur_line = true,
        hint_enable = false,
      }
    end,
  },
  {
    "rmagatti/auto-session",
    lazy = false,
    config = function()
      require("auto-session").setup {
        log_level = "error",
        cwd_change_handling = {
          post_cwd_changed_hook = function() -- example refreshing the lualine status line _after_ the cwd changes
            require("lualine").refresh() -- refresh lualine so the new session name is displayed in the status bar
            require("neo-tree").refresh() -- refresh neotree so the new session name is displayed in the status bar
          end,
        },
        auto_session_suppress_dirs = {
          "~/",
          "~/Projects",
          "~/Downloads",
          "/",
        },
        post_restore_cmds = { "Neotree toggle" },
      }
    end,
  },
  {
    "folke/zen-mode.nvim",
    lazy = false,
    config = function()
      require("zen-mode").setup {
        window = {
          backdrop = 0.95,
          width = 80, -- width of the Zen window
          height = 1, -- height of the Zen window
          options = {
            signcolumn = "no", -- disable signcolumn
            number = false, -- disable number column
            relativenumber = false, -- disable relative numbers
            -- cursorline = false, -- disable cursorline
            cursorcolumn = false, -- disable cursor column
            foldcolumn = "0", -- disable fold column
            list = false, -- disable whitespace characters
          },
        },
        plugins = {
          -- disable some global vim options (vim.o...)
          options = {
            enabled = true,
            ruler = false, -- disables the ruler text in the cmd line area
            showcmd = false, -- disables the command in the last line of the screen
            -- you may turn on/off statusline in zen mode by setting 'laststatus'
            -- statusline will be shown only if 'laststatus' == 3
            laststatus = 0, -- turn off the statusline in zen mode
          },
          twilight = { enabled = true }, -- enable to start Twilight when zen mode opens
          gitsigns = { enabled = false }, -- disables git signs
          tmux = { enabled = true }, -- disables the tmux statusline
          wezterm = {
            enabled = true,
            font = "+20", -- (10% increase per step)
          },
        },
      }
    end,
  },
  { "preservim/vim-pencil", lazy = false },
  {
    "iamcco/markdown-preview.nvim",
    cmd = {
      "MarkdownPreviewToggle",
      "MarkdownPreview",
      "MarkdownPreviewStop",
    },
    build = "cd app && npm install",
    init = function() vim.g.mkdp_filetypes = { "markdown" } end,
    ft = { "markdown" },
  },
  {
    "OXY2DEV/markview.nvim",
    dependencies = {
      -- You may not need this if you don't lazy load
      -- Or if the parsers are in your $RUNTIMEPATH
      "nvim-treesitter/nvim-treesitter",

      "nvim-tree/nvim-web-devicons",
    },
    init = function()
      require("markview").setup {
        modes = { "n", "no", "c" },
        hybrid_modes = { "n" },
        callbacks = {
          on_enable = function(_, win)
            vim.wo[win].conceallevel = 3
            vim.wo[win].concealcursor = "c"
          end,
        },
      }
    end,
  },
  { -- override treesitter
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = {
        "bash",
        "css",
        "html",
        "javascript",
        "jsonc",
        "lua",
        "markdown",
        "regex",
        "tsx",
        "typescript",
        "yaml",
      }
    end,
  },
  { -- override mason-null-ls ensure installed
    "jay-babu/mason-null-ls.nvim",
    opts = function(_, opts)
      local mason_null_ls = require "mason-null-ls"
      opts.ensure_installed = {
        "autopep8",
        "beautysh",
        "eslint-lsp",
        "eslint_d",
        "lua-language-server",
        "prettierd",
        "pyright",
        "shellcheck",
        "stylua",
        "typescript-language-server",
        "yamlfmt",
      }
      mason_null_ls.setup(opts)
    end,
  },
  { -- override nvim-cmp to disable <Tab> and <S-Tab> mappings
    "hrsh7th/nvim-cmp",
    opts = function(_, opts)
      local cmp = require "cmp"
      opts.mapping["<Tab>"] = cmp.config.disable
      opts.mapping["<S-Tab>"] = cmp.config.disable
      return opts
    end,
  },
  { "christoomey/vim-tmux-navigator" },
  -- {
  --   "github/copilot.vim",
  --   lazy = false,
  --   init = function() vim.g.copilot_assume_mapped = true end,
  -- },
  {
    "catppuccin/nvim",
    config = function() require("catppuccin").setup { flavour = "macchiato" } end,
  },
  {
    "folke/noice.nvim",
    lazy = false,
    event = "VeryLazy",
    opts = {
      -- add any options here
    },
    dependencies = {
      -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
      "MunifTanjim/nui.nvim", -- OPTIONAL:
      --   `nvim-notify` is only needed, if you want to use the notification view.
      --   If not available, we use `mini` as the fallback
      "rcarriga/nvim-notify",
    },
    config = function()
      require("noice").setup {
        lsp = {
          -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
          hover = { enabled = false },
          signature = { enabled = false },
        },
        -- you can enable a preset for easier configuration
        presets = {
          command_palette = false, -- position the cmdline and popupmenu together
          long_message_to_split = true, -- long messages will be sent to a split
          inc_rename = false, -- enables an input dialog for inc-rename.nvim
          lsp_doc_border = false, -- add a border to hover docs and signature help
        },
        routes = {
          {
            filter = {
              event = "msg_show",
              kind = "",
              find = "written",
            },
            opts = { skip = true },
          },
          {
            filter = {
              event = "msg_show",
              kind = "",
              find = "before",
            },
            opts = { skip = true },
          },
        },
      }
    end,
  },
}
