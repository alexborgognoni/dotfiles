return {
    colorscheme = "catppuccin",

    plugins = {
        {
            "github/copilot.vim",
            lazy = false,
            init = function() vim.g.copilot_assume_mapped = true end
        }, {
            "catppuccin/nvim",
            config = function()
                require("catppuccin").setup({flavour = "macchiato"})
            end
        }, -- lazy.nvim
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
                "rcarriga/nvim-notify"
            },
            config = function()
                require("noice").setup({
                    lsp = {
                        -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
                        override = {
                            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                            ["vim.lsp.util.stylize_markdown"] = true,
                            ["cmp.entry.get_documentation"] = true
                        },
                        hover = {enabled = false},
                        signature = {enabled = false}
                    },
                    -- you can enable a preset for easier configuration
                    presets = {
                        command_palette = false, -- position the cmdline and popupmenu together
                        long_message_to_split = true, -- long messages will be sent to a split
                        inc_rename = false, -- enables an input dialog for inc-rename.nvim
                        lsp_doc_border = false -- add a border to hover docs and signature help
                    },
                    routes = {
                        {
                            filter = {
                                event = "msg_show",
                                kind = "",
                                find = "written"
                            },
                            opts = {skip = true}
                        }, {
                            filter = {
                                event = "msg_show",
                                kind = "",
                                find = "before"
                            },
                            opts = {skip = true}
                        }

                    }
                })
            end
        }
    }
}
