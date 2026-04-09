{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    package = pkgs.tmux;
    prefix = "C-a";
    mouse = true;
    keyMode = "vi";
    historyLimit = 100000;
    baseIndex = 1;
    escapeTime = 10;
    terminal = "xterm-256color";
    aggressiveResize = true;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      resurrect
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor 'mocha'
          set -g @catppuccin_window_status_style 'rounded'
          set -g @catppuccin_window_text ' #W'
          set -g @catppuccin_window_current_text ' #W'
        '';
      }
      {
        plugin = tmux-fzf;
        extraConfig = ''
          set-environment -g TMUX_FZF_LAUNCH_KEY "W"
          set-environment -g TMUX_FZF_OPTIONS "-p -w 62% -h 38% -m"
          set-environment -g TMUX_FZF_PREVIEW "0"
          set-environment -g TMUX_FZF_ORDER "session|window|pane|command|keybinding|clipboard|process"

          # Flat fuzzy list of all windows across all sessions.
          # "switch" arg skips the action picker and jumps straight to the list.
          bind w run-shell -b "${pkgs.tmuxPlugins.tmux-fzf}/share/tmux-plugins/tmux-fzf/scripts/window.sh switch"
        '';
      }
    ];

    extraConfig = ''
      # Renumber windows when one is closed
      set -g renumber-windows on

      # Report session/window to outer terminal title
      set -g set-titles on
      set -g set-titles-string "#H: #S: #W"

      # Truecolor passthrough
      set -sg terminal-overrides ',*:RGB'

      # Resize to most recent client
      set -g window-size latest

      # macOS: keep login shell behavior working inside tmux
      # See https://github.com/tmux/tmux/issues/4162
      set -gu default-command
      set -g default-shell "${pkgs.fish}/bin/fish"

      # Shorter repeat window than default 500ms
      set -sg repeat-time 300

      # Inherit cwd on split / new window
      bind '"' split-window -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      # Vim-style pane navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Vim-style pane resize (repeatable)
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Navigate windows left / right
      bind -r C-h previous-window
      bind -r C-l next-window

      # Swap current window left / right
      bind -r C-y swap-window -t -1 \; select-window -t -1
      bind -r C-u swap-window -t +1 \; select-window -t +1

      # Toggle mouse mode
      bind M set -g mouse\; display-message "Mouse is now #{?mouse,on,off}"

      # Toggle synchronized panes
      bind S setw synchronize-panes\; display-message "Synchronized pane is now #{?synchronize-panes,on,off}"

      # Clear screen across synced panes
      bind C-k setw synchronize-panes\; send-keys C-l \; setw synchronize-panes

      bind C-c command-prompt -p "New session name:" "new-session -s '%%'"

      # Reload config
      unbind r
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded"

      # Kill without confirmation
      bind x kill-pane
      bind "&" kill-window
      bind X kill-session

      # Catppuccin status line configuration
      set -g status-position top
      set -g status-left-length 100
      set -g status-right-length 100
      set -g status-left "#{E:@catppuccin_status_host}"
      set -ag status-left "#{E:@catppuccin_status_session}"
      set -ag status-left "#[default] "
      set -g status-right "#{E:@catppuccin_status_application}"
      set -agF status-right "#{E:@catppuccin_status_cpu}"
      set -ag status-right "#{E:@catppuccin_status_uptime}"
      set -agF status-right "#{E:@catppuccin_status_battery}"

      run-shell ${pkgs.tmuxPlugins.cpu}/share/tmux-plugins/cpu/cpu.tmux
      run-shell ${pkgs.tmuxPlugins.battery}/share/tmux-plugins/battery/battery.tmux
    '';
  };

  home.packages = [ pkgs.tmux ];
}
