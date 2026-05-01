final: prev: {
  markdown-oxide = final.rustPlatform.buildRustPackage {
    pname = "markdown-oxide";
    version = "unstable-2026-03-10";

    src = final.fetchFromGitHub {
      owner = "Feel-ix-343";
      repo = "markdown-oxide";
      rev = "46ec5ca0cfdfc98c4e67395afa120cf6eb39743b";
      hash = "sha256-+IQmBxS+Roxt2cqypf51loNvvs4rMizXKVMr+o08rck=";
    };

    cargoHash = "sha256-Ts+nuQkeZYvp1p8A0mv9SC83Ft/MjQQZG9eOlBFCkIg=";

    meta = prev.markdown-oxide.meta;
  };
}
