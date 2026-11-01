# How every application follows the theme: one table for the whole system.
# `nix flake check` (check `app-coverage`) fails when an installed graphical
# application, or a terminal tool that draws its own colors, is missing here, so
# a new app cannot be added without deciding how it is themed. `theme apps`
# prints this table.
#
#   how      what makes the app follow the theme
#     pack      reads the live theme pack: changes while previewing (needs `file`)
#     stylix    Stylix writes its config when the theme is applied (needs `target`,
#               the Stylix target; `program` when the Home Manager program differs)
#     toolkit   draws with GTK or Qt (`toolkit`): colors from the GTK/Kvantum
#               theme, plus the icon set, cursor, fonts and light/dark mode
#     terminal  uses the terminal's ANSI palette (kitty, from the pack)
#     portal    follows only light/dark (desktop portal, GTK setting); its
#               accent colors are its own
#     own       has its own theming that is not synced (say why in `note`)
#     none      nothing to theme (say why in `note`)
#   match    ERE for the desktop file ids of the app (without ".desktop"), for GUI apps
#   bins     executables of terminal tools
#
# `watch` lists terminal tools that draw their own colors (TUIs, pagers, prompts):
# when one of them is installed it must have a `bins` entry above. Add a name
# there when you install a tool of that kind that is not listed yet.
{
  apps = {
    # Compositor, shell and terminal stack: instant, from the pack
    hyprland = {
      match = "(hyprland|hyprland-uwsm)";
      how = "pack";
      file = "hyprland.lua";
    };
    noctalia = {
      match = "dev\\.noctalia\\.Noctalia(\\.Annotator)?";
      bins = [ "noctalia" ];
      how = "pack";
      file = "noctalia.json";
    };
    kitty = {
      match = "kitty(-open)?";
      bins = [ "kitty" ];
      how = "pack";
      file = "kitty.conf";
    };
    tmux = {
      bins = [ "tmux" ];
      how = "pack";
      file = "tmux.conf";
    };
    neovim = {
      match = "nvim";
      bins = [
        "nvim"
        "vim"
      ];
      how = "pack";
      file = "nvim.lua";
    };
    neovide = {
      match = "neovide";
      bins = [ "neovide" ];
      how = "stylix";
      target = "neovide";
      note = "colors from Neovim (the pack); Stylix sets the font";
    };
    readest = {
      match = "readest";
      bins = [ "readest" ];
      how = "pack";
      file = "readest.json";
      note = "a custom theme synced before every start; select 'Theme' once in Readest";
    };

    # Terminal tools with their own colors, written by Stylix
    bat = {
      bins = [ "bat" ];
      how = "stylix";
      target = "bat";
    };
    btop = {
      match = "btop";
      bins = [ "btop" ];
      how = "stylix";
      target = "btop";
    };
    fzf = {
      bins = [ "fzf" ];
      how = "stylix";
      target = "fzf";
    };
    lazygit = {
      bins = [ "lazygit" ];
      how = "stylix";
      target = "lazygit";
    };
    starship = {
      bins = [ "starship" ];
      how = "stylix";
      target = "starship";
    };
    yazi = {
      match = "yazi";
      bins = [ "yazi" ];
      how = "stylix";
      target = "yazi";
    };
    k9s = {
      bins = [ "k9s" ];
      how = "stylix";
      target = "k9s";
    };
    kubecolor = {
      bins = [ "kubecolor" ];
      how = "stylix";
      target = "kubecolor";
    };

    # Terminal tools that take the terminal's palette
    terminal-tools = {
      bins = [
        "eza"
        "fastfetch"
        "nvtop"
        "htop"
        "delta"
        "glow"
        "gitui"
        "tig"
        "ranger"
        "mc"
        "ncdu"
        "gdu"
        "btm"
        "zellij"
        "lazydocker"
      ];
      match = "(nvtop)";
      how = "terminal";
    };

    # AI terminal apps: each has its own theme setting
    ai-agents = {
      bins = [
        "opencode"
        "claude"
        "codex"
        "copilot"
        "herdr"
        "forge"
      ];
      how = "own";
      note = "no theme hook: they draw with the terminal's ANSI palette and their own /theme choice";
    };

    # Browsers
    firefox = {
      match = "firefox";
      how = "stylix";
      target = "firefox";
    };
    zen = {
      match = "zen(-beta|-twilight)?";
      how = "stylix";
      target = "zen-browser";
      program = "zen-browser";
    };
    chromium-family = {
      match = "(chromium-browser|chromium|com\\.google\\.Chrome|google-chrome|microsoft-edge|com\\.microsoft\\.Edge)";
      how = "portal";
      note = "Chromium follows the system light/dark; its own accent color is set in the browser";
    };

    # Editors
    vscode = {
      match = "code(-url-handler)?";
      how = "stylix";
      target = "vscode";
    };

    # GTK and Qt applications
    nautilus-and-gnome = {
      match = "(org\\.gnome\\..*|nautilus.*|eog|totem|gedit|file-roller|evince|simple-scan|baobab)";
      how = "toolkit";
      toolkit = "gtk";
    };
    gtk-apps = {
      match = "(org\\.pulseaudio\\.pavucontrol|nm-connection-editor|blueman-manager|virt-manager|org\\.inkscape\\.Inkscape|fr\\.handbrake\\.ghb|org\\.audacityteam\\.Audacity|com\\.github\\.johnfactotum\\.Foliate|transmission-gtk|remmina.*|org\\.remmina\\..*)";
      how = "toolkit";
      toolkit = "gtk";
    };
    qt-apps = {
      match = "(vlc|vlc-open.*|com\\.obsproject\\.Studio|qt5ct|qt6ct|kvantummanager)";
      how = "toolkit";
      toolkit = "qt";
    };
    libreoffice = {
      match = "(libreoffice-.*|startcenter)";
      how = "portal";
      note = "LibreOffice draws with its own VCL theme; it follows the system light/dark only";
    };
    obsidian = {
      match = "md\\.obsidian\\.Obsidian";
      how = "own";
      note = "the theme is chosen inside Obsidian (Appearance); it can follow the system light/dark";
    };

    portal-dialogs = {
      match = "xdg-desktop-portal-gtk";
      how = "toolkit";
      toolkit = "gtk";
      note = "the file chooser and other dialogs apps open through the portal";
    };

    # Nothing to theme
    browser-pages = {
      match = "(cups|nixos-manual)";
      how = "none";
      note = "open a page in the default browser, which follows the theme";
    };
    uwsm-menu = {
      match = "uuctl";
      how = "none";
      note = "uwsm's unit menu runs in a dmenu-style launcher";
    };
    smartcard-notify = {
      match = "org\\.opensc\\.notify";
      how = "none";
      note = "smart card notices: shown by Noctalia's notifications";
    };
    wine = {
      match = "(wine|org\\.freedesktop\\.Xwayland)";
      how = "none";
      note = "Windows programs draw themselves; Xwayland has no window";
    };
  };

  watch = [
    "bat"
    "btm"
    "btop"
    "codex"
    "claude"
    "copilot"
    "delta"
    "eza"
    "fastfetch"
    "forge"
    "fzf"
    "gdu"
    "gitui"
    "glow"
    "helix"
    "herdr"
    "htop"
    "hx"
    "k9s"
    "kubecolor"
    "lazydocker"
    "lazygit"
    "mc"
    "micro"
    "ncdu"
    "neofetch"
    "neovide"
    "nvim"
    "nvtop"
    "opencode"
    "ranger"
    "starship"
    "tig"
    "tmux"
    "vim"
    "yazi"
    "zellij"
  ];
}
