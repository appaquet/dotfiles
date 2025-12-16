{
  pkgs,
  fetchFromGitHub,
  python,
  pythonPackages,
  iterfzf,
}:
let
  version = "2.5.0";

  src = fetchFromGitHub {
    owner = "Realiserad";
    repo = "fish-ai";
    rev = "v${version}";
    sha256 = "sha256-PuCYaNpKr9vk+AKfDg0YYQtepyjcHFvgwKLZMwTRb8c=";
  };

  # Build fish-ai as a Python package
  fishAiPython = pythonPackages.buildPythonApplication {
    pname = "fish-ai";
    inherit version src;
    pyproject = true;

    build-system = [ pythonPackages.setuptools ];

    dependencies =
      with pythonPackages;
      [
        openai
        anthropic
        keyring
        groq
        cohere
        binaryornot
        google-genai
        simple-term-menu
      ]
      ++ [ iterfzf ];

    # Skip tests - they require network
    doCheck = false;

    # Skip runtime deps check - nixpkgs versions are close enough
    dontCheckRuntimeDeps = true;
  };

  # Create a venv-like structure that fish-ai expects at ~/.local/share/fish-ai
  fishAiEnv = pkgs.runCommand "fish-ai-env" { } ''
    mkdir -p $out/bin

    # Link all entry point scripts from fish-ai
    for f in ${fishAiPython}/bin/*; do
      ln -s "$f" "$out/bin/$(basename "$f")"
    done

    # Link python3 for compatibility
    ln -sf ${python}/bin/python3 $out/bin/python3
  '';

  # Fish plugin
  fishPlugin = pkgs.fishPlugins.buildFishPlugin {
    pname = "fish-ai";
    inherit version src;
  };
in
fishPlugin.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    env = fishAiEnv;
  };
})
