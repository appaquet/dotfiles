{ inputs', ... }:
{
  imports = [ ./module.nix ];

  config = {
    dotfiles.nono.package = inputs'.llm-agents.packages.nono;

    # Per machine profile
    dotfiles.nono.profiles.machine = {
      meta.version = "1.0.0";
    };

    dotfiles.nono.profiles.coding-agent = {
      meta.version = "1.0.0";
      extends = [ "machine" ];
      workdir.access = "readwrite";
      filesystem = {
        read = [
          "/proc"
          "/nix"

          "$HOME/dotfiles"

          "$HOME/.config/git"
          "$HOME/.gitignore"

          "$HOME/.nix-profile/bin"
          "$HOME/.local/state/nix"
          "$HOME/.local/share/nix"
          "$HOME/.nix-defexpr"

          "$HOME/.local/utils"
        ];
        allow = [
          "$HOME/.config/jj"

          "$HOME/.config/fish"
          "$HOME/.local/share/fish"

          "$HOME/.cache/nix"

          "$HOME/.cache/go-build"
          "$HOME/.cache/golangci-lint"
          "$HOME/.cargo/registry"
          "$HOME/.cache/buf"
          "$HOME/.npm"

          "/tmp"
        ];
        read_file = [ "$HOME/.profile" ];
        write_file = [ ];
      };
    };
  };
}
