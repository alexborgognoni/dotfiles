-- if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- Customize Treesitter (AstroNvim v6: configured through AstroCore)
-- With Nix every grammar is already installed (modules/home/editor/astronvim),
-- so this list is informational there.

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    treesitter = {
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
  },
}
