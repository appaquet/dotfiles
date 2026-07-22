{ pkgs, ... }:

{
  home.packages = [
    pkgs.tmux
    (pkgs.writeShellScriptBin "tmux-statusline" ''
      tmux="tmux"
      managed_option="@tmux-statusline-indicator"

      fail() {
        printf 'tmux-statusline: %s\n' "$*" >&2
        exit 1
      }

      rename_window() {
        "$tmux" rename-window -t "$target" "$1" \
          || fail "could not update title for tmux window '$target'"
      }

      update_title_and_indicator() {
        local action="$1"
        local title="$2"
        shift 2

        "$tmux" rename-window -t "$target" "$title" \; "$@" \
          || fail "could not $action title and managed prefix for tmux window '$target'"
      }

      resolve_invoking_window() {
        target="$("$tmux" display-message -p '#{window_id}')" \
          || fail "could not resolve the invoking tmux window"
        [ -n "$target" ] || fail "tmux returned an empty invoking window ID"
      }

      resolve_target() {
        if [ -n "$TMUX_WINDOW_ID" ]; then
          target="$TMUX_WINDOW_ID"
        else
          resolve_invoking_window
        fi
      }

      read_window_state() {
        current_title="$("$tmux" display-message -p -t "$target" '#{window_name}')" \
          || fail "could not read title for tmux window '$target'"

        if managed_indicator="$("$tmux" show-options -wqv -t "$target" "$managed_option")"; then
          if [ -n "$managed_indicator" ]; then
            has_managed_indicator=1
          else
            has_managed_indicator=0
          fi
        else
          fail "could not read managed prefix for tmux window '$target'"
        fi

        prefix="$managed_indicator: "
        if [ -n "$managed_indicator" ] \
          && [ "''${current_title:0:''${#prefix}}" = "$prefix" ]; then
          base_title="''${current_title:''${#prefix}}"
        else
          base_title="$current_title"
        fi
      }

      set_indicator() {
        local indicator="$1"

        read_window_state
        next_title="$indicator: $base_title"
        if [ "$managed_indicator" != "$indicator" ] || [ "$has_managed_indicator" -eq 0 ]; then
          update_title_and_indicator set "$next_title" \
            set-window-option -t "$target" "$managed_option" "$indicator"
        elif [ "$current_title" != "$next_title" ]; then
          rename_window "$next_title"
        fi
      }

      clear_indicator() {
        read_window_state
        if [ "$has_managed_indicator" -eq 1 ]; then
          update_title_and_indicator clear "$base_title" \
            set-window-option -u -t "$target" "$managed_option"
        elif [ "$current_title" != "$base_title" ]; then
          rename_window "$base_title"
        fi
      }

      case "$#:$1" in
        1:init)
          operation=init
          ;;
        2:set)
          operation=set
          indicator="$2"
          [ -n "$indicator" ] || fail "set requires a non-empty indicator"
          ;;
        1:clear)
          operation=clear
          ;;
        *)
          fail "usage: tmux-statusline init | tmux-statusline set <indicator> | tmux-statusline clear"
          ;;
      esac

      # Valid calls outside tmux intentionally have no observable effect.
      [ -n "$TMUX" ] || exit 0

      case "$operation" in
        init)
          # Initialization always discovers the invoking window, ignoring any
          # inherited target so callers receive a new process-start pin.
          resolve_invoking_window
          clear_indicator
          printf '%s\n' "$target"
          ;;
        set)
          resolve_target
          set_indicator "$indicator"
          ;;
        clear)
          resolve_target
          clear_indicator
          ;;
      esac
    '')
  ];
}
