-- if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- Customize Mason

---@type LazySpec
return {
  -- use mason-tool-installer for automatically installing Mason packages
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    -- overrides `require("mason-tool-installer").setup(...)`
    opts = {
      -- Make sure to use the names found in `:Mason`
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
    },
  },
}
