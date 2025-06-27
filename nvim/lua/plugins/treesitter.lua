-- if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- Customize Treesitter

---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = {
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
    },
  },
}
