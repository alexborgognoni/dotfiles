# AstroNvim-style key mappings.
let
  map = mode: key: action: desc: {
    inherit mode key action;
    options.desc = desc;
  };
  lua = code: "<cmd>lua ${code}<cr>";
in
{
  programs.nixvim.keymaps = [
    (map "n" "<leader>w" "<cmd>w<cr>" "Save")
    (map "n" "<leader>q" "<cmd>confirm q<cr>" "Quit window")
    (map "n" "<leader>Q" "<cmd>confirm qall<cr>" "Quit Neovim")
    (map "n" "<leader>n" "<cmd>enew<cr>" "New file")
    (map "n" "<Esc>" "<cmd>nohlsearch<cr>" "Clear search highlight")

    # Explorer
    (map "n" "<leader>e" "<cmd>Neotree toggle<cr>" "Toggle explorer")
    (map "n" "<leader>o" "<cmd>Neotree focus<cr>" "Focus explorer")

    # Buffers
    (map "n" "]b" "<cmd>BufferLineCycleNext<cr>" "Next buffer")
    (map "n" "[b" "<cmd>BufferLineCyclePrev<cr>" "Previous buffer")
    (map "n" "<leader>c" (lua "Snacks.bufdelete()") "Close buffer")
    (map "n" "<leader>bd" "<cmd>BufferLinePickClose<cr>" "Close buffer from tabline")
    (map "n" "<leader>bc" (lua "Snacks.bufdelete.other()") "Close other buffers")

    # Find
    (map "n" "<leader>ff" (lua "Snacks.picker.files()") "Find files")
    (map "n" "<leader>fw" (lua "Snacks.picker.grep()") "Find words")
    (map "n" "<leader>fb" (lua "Snacks.picker.buffers()") "Find buffers")
    (map "n" "<leader>fo" (lua "Snacks.picker.recent()") "Find old files")
    (map "n" "<leader>fh" (lua "Snacks.picker.help()") "Find help")
    (map "n" "<leader>fk" (lua "Snacks.picker.keymaps()") "Find keymaps")
    (map "n" "<leader>fc" (lua "Snacks.picker.grep_word()") "Find word under cursor")
    (map "n" "<leader>ft" (lua "Snacks.picker.todo_comments()") "Find TODOs")
    (map "n" "<leader><leader>" (lua "Snacks.picker.smart()") "Smart find")

    # Git
    (map "n" "<leader>gg" (lua "Snacks.lazygit()") "Lazygit")
    (map "n" "<leader>gb" (lua "Snacks.picker.git_branches()") "Git branches")
    (map "n" "<leader>gl" (lua "Snacks.picker.git_log()") "Git log")
    (map "n" "<leader>gp" "<cmd>Gitsigns preview_hunk<cr>" "Preview hunk")
    (map "n" "<leader>gr" "<cmd>Gitsigns reset_hunk<cr>" "Reset hunk")
    (map "n" "]g" "<cmd>Gitsigns next_hunk<cr>" "Next hunk")
    (map "n" "[g" "<cmd>Gitsigns prev_hunk<cr>" "Previous hunk")

    # LSP
    (map "n" "gd" (lua "Snacks.picker.lsp_definitions()") "Go to definition")
    (map "n" "gD" (lua "vim.lsp.buf.declaration()") "Go to declaration")
    (map "n" "gr" (lua "Snacks.picker.lsp_references()") "References")
    (map "n" "gI" (lua "Snacks.picker.lsp_implementations()") "Implementation")
    (map "n" "<leader>la" (lua "vim.lsp.buf.code_action()") "Code action")
    (map "n" "<leader>lr" (lua "vim.lsp.buf.rename()") "Rename symbol")
    (map "n" "<leader>lf" (lua "require('conform').format({ lsp_format = 'fallback' })") "Format buffer")
    (map "n" "<leader>ld" (lua "vim.diagnostic.open_float()") "Line diagnostics")
    (map "n" "<leader>lD" (lua "Snacks.picker.diagnostics()") "All diagnostics")
    (map "n" "<leader>ls" (lua "Snacks.picker.lsp_symbols()") "Document symbols")

    # Terminal
    (map "n" "<leader>tf" "<cmd>ToggleTerm direction=float<cr>" "Floating terminal")
    (map "n" "<leader>th" "<cmd>ToggleTerm direction=horizontal<cr>" "Horizontal terminal")
    (map "n" "<leader>tv" "<cmd>ToggleTerm direction=vertical size=80<cr>" "Vertical terminal")

    # UI
    (map "n" "<leader>uw" "<cmd>set wrap!<cr>" "Toggle wrap")
    (map "n" "<leader>un" (lua "require('notify').dismiss({ silent = true, pending = true })") "Dismiss notifications")
    (map "n" "<leader>h" (lua "Snacks.dashboard()") "Home screen")

    # Comments (Neovim's built-in commenting)
    {
      mode = "n";
      key = "<leader>/";
      action = "gcc";
      options = {
        remap = true;
        desc = "Toggle comment";
      };
    }
    {
      mode = "v";
      key = "<leader>/";
      action = "gc";
      options = {
        remap = true;
        desc = "Toggle comment";
      };
    }
  ];
}
