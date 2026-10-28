# Port of chezmoi/dot_config/tmux/tmux.conf. Plugins come from nixpkgs (no
# tpm); the catppuccin plugin's palette comes from the live theme pack.
{
  config,
  pkgs,
  ...
}:
let
  # Nerd Font glyphs, written as code points so no editor or tool can mangle
  # the private-use characters.
  glyph = code: builtins.fromJSON ''"\u${code}"'';
  roundLeft = glyph "e0b6"; # 
  roundRight = glyph "e0b4"; # 
  vimIcon = glyph "e615"; # 
  zoomIcon = builtins.fromJSON ''"\udb80\udc4c"''; # U+F004C 󰁌 (surrogate pair)
in
{
  stylix.targets.tmux.enable = false;

  # Used by the `theme` command: load the live pack's palette and re-run only
  # the catppuccin plugin (re-sourcing tmux.conf re-runs every plugin, ~1 s).
  xdg.configFile."tmux/theme-reload.conf".text = ''
    source-file ${config.my.themeState}/current/tmux.conf
    run-shell ${pkgs.tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin/catppuccin.tmux
  '';

  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    terminal = "tmux-256color";
    prefix = "C-a";
    mouse = true;
    baseIndex = 1;
    escapeTime = 10;
    historyLimit = 5000;
    keyMode = "vi";
    aggressiveResize = true;
    focusEvents = true;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      {
        plugin = catppuccin;
        extraConfig = ''
          source-file ${config.my.themeState}/current/tmux.conf

          set -g @catppuccin_window_flags "icon"
          set -g @catppuccin_window_current_text " #W"
          set -g @catppuccin_window_text " #W"
          set -g @catppuccin_window_flags_icon_zoom " ${zoomIcon}"
          set -g @catppuccin_application_icon "${vimIcon} "
          set -g @catppuccin_status_left_separator " ${roundLeft}"
          set -g @catppuccin_status_right_separator "${roundRight} "
          set -g @catppuccin_window_status_style "custom"
          set -g @catppuccin_window_left_separator "#[bg=default,fg=##{?window_bell_flag,#{@thm_yellow},#{@thm_surface_1}}]${roundLeft}#[bg=##{?window_bell_flag,#{@thm_yellow},#{@thm_surface_1}},fg=##{?window_bell_flag,#{@thm_crust},#{@thm_fg}}]"
          set -g @catppuccin_window_middle_separator "#[fg=##{?window_bell_flag,#{@thm_yellow},#{@thm_surface_1}}]█"
          set -g @catppuccin_window_right_separator "#[bg=default,fg=#{@thm_surface_0}]${roundRight}"
          set -g @catppuccin_window_flags_icon_format "##{?window_activity_flag,#{E:@catppuccin_window_flags_icon_activity},}##{?window_bell_flag,#{E:@catppuccin_window_flags_icon_bell},}##{?window_silence_flag,#{E:@catppuccin_window_flags_icon_silent},}##{?window_active,#{E:@catppuccin_window_flags_icon_current},}##{?window_marked_flag,#{E:@catppuccin_window_flags_icon_mark},}##{?window_zoomed_flag,#{E:@catppuccin_window_flags_icon_zoom},} "
          set -g @catppuccin_window_current_left_separator "#[bg=default,fg=#{@thm_lavender}]${roundLeft}#[bg=#{@thm_lavender},fg=#{@thm_bg}]"
          set -g @catppuccin_window_current_middle_separator "#[fg=#{@thm_lavender}]█"
          set -g @catppuccin_window_current_right_separator "#[bg=default,fg=#{@thm_surface_1}]${roundRight}"
          set -g @catppuccin_status_background "none"
          set -g @catppuccin_status_connect_separator "no"
        '';
      }
      {
        plugin = resurrect;
        extraConfig = "set -g @resurrect-processes '~nvim'";
      }
      {
        plugin = continuum;
        extraConfig = "set -g @continuum-restore 'on'";
      }
    ];

    extraConfig = ''
      bind-key C-a send-prefix

      set-option -sa terminal-overrides ',xterm-256color:RGB'
      set-option -sa terminal-overrides ',tmux-256color:RGB'
      # kitty reports TERM=xterm-kitty; without this tmux downsamples to 256 colors.
      set -as terminal-features 'xterm-kitty*:RGB'
      set -s extended-keys on
      set -as terminal-features 'xterm*:extkeys'
      set -as terminal-features 'xterm-kitty*:extkeys'

      set -g status-position top
      setw -g pane-base-index 1
      set-option -g automatic-rename on
      set-option -g renumber-windows on
      set -g allow-passthrough on
      set -ga update-environment TERM
      set -ga update-environment TERM_PROGRAM

      bind-key L last-window
      bind r source-file ~/.config/tmux/tmux.conf \; display "Reloaded!"
      bind | split-window -h -c "#{pane_current_path}"
      bind \\ split-window -v -c "#{pane_current_path}"
      bind C-p previous-window
      bind C-n next-window

      set-option -s set-clipboard off
      bind Enter copy-mode
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi Escape send -X cancel
      bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'wl-copy'

      # Seamless pane/split navigation with Neovim (vim-tmux-navigator)
      is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
          | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?(-wrapped)?$'"
      bind -n C-h if-shell "$is_vim" 'send-keys C-h' 'select-pane -L'
      bind -n C-j if-shell "$is_vim" 'send-keys C-j' 'select-pane -D'
      bind -n C-k if-shell "$is_vim" 'send-keys C-k' 'select-pane -U'
      bind -n C-l if-shell "$is_vim" 'send-keys C-l' 'select-pane -R'

      set -g status-left "#{E:@catppuccin_status_session}"
      set -g status-right "#{E:@catppuccin_status_application}#{E:@catppuccin_status_directory}#{E:@catppuccin_status_user}#{E:@catppuccin_status_host}"
      set -g status-right-length 100
      set -g status-left-length 100
      set -g window-status-bell-style "default"
      set -g window-status-current-style "default"
      set -g message-style "fill=#{@thm_surface_0},bg=#{@thm_surface_0},fg=#{@thm_fg}"
      set -g message-command-style "fill=#{@thm_surface_0},bg=#{@thm_surface_0},fg=#{@thm_fg}"
    '';
  };
}
