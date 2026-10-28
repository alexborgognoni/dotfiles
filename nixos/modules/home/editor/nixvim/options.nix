{
  programs.nixvim = {
    globals = {
      mapleader = " ";
      maplocalleader = ",";
    };

    opts = {
      number = true;
      relativenumber = true;
      signcolumn = "yes";
      wrap = false;
      spell = false;
      cursorline = true;
      mouse = "a";
      clipboard = "unnamedplus";
      undofile = true;
      ignorecase = true;
      smartcase = true;
      splitbelow = true;
      splitright = true;
      termguicolors = true;
      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
      softtabstop = 2;
      scrolloff = 8;
      updatetime = 300;
      timeoutlen = 500;
      showmode = false;
      laststatus = 3;
      fillchars = "eob: ";
    };

    diagnostic.settings = {
      virtual_text = true;
      underline = true;
      severity_sort = true;
      float.border = "rounded";
    };
  };
}
