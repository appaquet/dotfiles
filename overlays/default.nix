{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config = {
          permittedInsecurePackages = [ ];
          allowUnfree = true;
        };
        overlays = [
          (final: prev: {
            exo = final.callPackage ./exo { };
            claude-code = final.callPackage ./claude-code { };
            fish-ai = final.callPackage ./fish-ai {
              python = prev.python312;
              pythonPackages = prev.python312Packages;
              iterfzf = prev.python312Packages.iterfzf.overridePythonAttrs (old: {
                doCheck = false; # Fails on MacOS
                # Patch to use system fzf instead of bundled (which doesn't exist in nixpkgs)
                postPatch =
                  (old.postPatch or "")
                  + ''
                    substituteInPlace iterfzf/__init__.py \
                      --replace-fail "Path(__file__).parent / EXECUTABLE_NAME" "None"
                  '';
              });
            };
          })

          (import ../home-manager/modules/neovim/plugins-overlay.nix)
        ];
      };
    };
}
