return {
  -- UI & UX
  {
    "catppuccin/nvim",
    config = function() require("catppuccin").setup { flavour = "macchiato" } end,
  },
  {
    "folke/noice.nvim",
    lazy = false,
    event = "VeryLazy",
    opts = {},
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    config = function()
      require("noice").setup {
        lsp = {
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
          hover = { enabled = false },
          signature = { enabled = false },
        },
        presets = {
          command_palette = false,
          long_message_to_split = true,
          inc_rename = false,
          lsp_doc_border = false,
        },
        routes = {
          {
            filter = { event = "msg_show", kind = "", find = "written" },
            opts = { skip = true },
          },
          {
            filter = { event = "msg_show", kind = "", find = "before" },
            opts = { skip = true },
          },
        },
      }
    end,
  },

  -- LSP & Coding Assistance
  -- {
  --   "ray-x/lsp_signature.nvim",
  --   lazy = true,
  --   event = "VeryLazy",
  --   opts = {},
  --   config = function()
  --     require("lsp_signature").setup {
  --       floating_window_above_cur_line = true,
  --       hint_enable = false,
  --     }
  --   end,
  -- },

  -- {
  --   "hrsh7th/nvim-cmp",
  --   opts = function(_, opts)
  --     local cmp = require "cmp"
  --     opts.mapping["<Tab>"] = cmp.config.disable
  --     opts.mapping["<S-Tab>"] = cmp.config.disable
  --     return opts
  --   end,
  -- },

  -- Markdown & Documentation
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

  -- {
  --   "OXY2DEV/markview.nvim",
  --   dependencies = {
  --     "nvim-treesitter/nvim-treesitter",
  --     "nvim-tree/nvim-web-devicons",
  --   },
  --   init = function()
  --     require("markview").setup {
  --       modes = { "n", "no", "c" },
  --       hybrid_modes = { "n" },
  --       callbacks = {
  --         on_enable = function(_, win)
  --           vim.wo[win].conceallevel = 3
  --           vim.wo[win].concealcursor = "c"
  --         end,
  --       },
  --     }
  --   end,
  -- },

  -- Session & Workflow
  {
    "rmagatti/auto-session",
    lazy = false,
    config = function()
      require("auto-session").setup {
        log_level = "error",
        cwd_change_handling = {
          post_cwd_changed_hook = function()
            require("lualine").refresh()
            require("neo-tree").refresh()
          end,
        },
        auto_session_suppress_dirs = {
          "~/",
          "~/Projects",
          "~/Downloads",
          "/",
        },
        pre_save_cmds = { "Neotree close" },
        post_restore_cmds = { "Neotree filesystem show" },
      }
    end,
  },

  -- Navigation
  { "christoomey/vim-tmux-navigator" },

  -- GitHub Copilot (optional)
  -- {
  --   "github/copilot.vim",
  --   lazy = false,
  --   init = function()
  --     vim.g.copilot_assume_mapped = true
  --   end,
  -- },
}

-- if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- You can also add or configure plugins by creating files in this `plugins/` folder
-- PLEASE REMOVE THE EXAMPLES YOU HAVE NO INTEREST IN BEFORE ENABLING THIS FILE
-- Here are some examples:

-- ---@type LazySpec
-- return {

--   -- == Examples of Adding Plugins ==

--   "andweeb/presence.nvim",
--   {
--     "ray-x/lsp_signature.nvim",
--     event = "BufRead",
--     config = function() require("lsp_signature").setup() end,
--   },

--   -- == Examples of Overriding Plugins ==

--   -- customize dashboard options
--   {
--     "folke/snacks.nvim",
--     opts = {
--       dashboard = {
--         preset = {
--           header = table.concat({
--             " █████  ███████ ████████ ██████   ██████ ",
--             "██   ██ ██         ██    ██   ██ ██    ██",
--             "███████ ███████    ██    ██████  ██    ██",
--             "██   ██      ██    ██    ██   ██ ██    ██",
--             "██   ██ ███████    ██    ██   ██  ██████ ",
--             "",
--             "███    ██ ██    ██ ██ ███    ███",
--             "████   ██ ██    ██ ██ ████  ████",
--             "██ ██  ██ ██    ██ ██ ██ ████ ██",
--             "██  ██ ██  ██  ██  ██ ██  ██  ██",
--             "██   ████   ████   ██ ██      ██",
--           }, "\n"),
--         },
--       },
--     },
--   },

--   -- You can disable default plugins as follows:
--   { "max397574/better-escape.nvim", enabled = false },

--   -- You can also easily customize additional setup of plugins that is outside of the plugin's setup call
--   {
--     "L3MON4D3/LuaSnip",
--     config = function(plugin, opts)
--       require "astronvim.plugins.configs.luasnip"(plugin, opts) -- include the default astronvim config that calls the setup call
--       -- add more custom luasnip configuration such as filetype extend or custom snippets
--       local luasnip = require "luasnip"
--       luasnip.filetype_extend("javascript", { "javascriptreact" })
--     end,
--   },

--   {
--     "windwp/nvim-autopairs",
--     config = function(plugin, opts)
--       require "astronvim.plugins.configs.nvim-autopairs"(plugin, opts) -- include the default astronvim config that calls the setup call
--       -- add more custom autopairs configuration such as custom rules
--       local npairs = require "nvim-autopairs"
--       local Rule = require "nvim-autopairs.rule"
--       local cond = require "nvim-autopairs.conds"
--       npairs.add_rules(
--         {
--           Rule("$", "$", { "tex", "latex" })
--             -- don't add a pair if the next character is %
--             :with_pair(cond.not_after_regex "%%")
--             -- don't add a pair if  the previous character is xxx
--             :with_pair(
--               cond.not_before_regex("xxx", 3)
--             )
--             -- don't move right when repeat character
--             :with_move(cond.none())
--             -- don't delete if the next character is xx
--             :with_del(cond.not_after_regex "xx")
--             -- disable adding a newline when you press <cr>
--             :with_cr(cond.none()),
--         },
--         -- disable for .vim files, but it work for another filetypes
--         Rule("a", "a", "-vim")
--       )
--     end,
--   },
-- }
