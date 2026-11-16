# Agent skills for herdr-core (hc) and herdr-app, rendered by nixantic for every agent harness.
{ inputs', ... }:

{
  nixantic = {
    # The upstream skill carries its own frontmatter; it is split off so nixantic can regenerate it, which
    # lets the body take an extra pointer to the herdr-app skill that holds AP's setup notes.
    sources.harnesses.skills."herdr-core".main =
      let
        upstream = builtins.readFile "${inputs'.llm-agents.packages.herdr-core.src}/skills/herdr-core/SKILL.md";
        parts = builtins.match "---\nname: [^\n]*\ndescription: ([^\n]*)\n---\n((.|\n)*)" upstream;
      in
      {
        description = builtins.fromJSON (builtins.elemAt parts 0);
        content =
          builtins.elemAt parts 1
          + "\nFor mods, layouts and themes in AP's setup, use the installed `herdr-app` skill (it carries AP's setup notes) rather than `herdr-app --skill`.\n";
      };

    # The herdr-app source ships its skill without frontmatter, so the body is wrapped here.
    sources.harnesses.skills."herdr-app".main = {
      description = "Control the Herdr window with herdr-app: show, arrange or focus spaces, tabs and panes. Use only to change what the person sees; use herdr-core (hc) to start, read, message or clean up agents and programs.";
      content = builtins.readFile "${inputs'.llm-agents.packages.herdr-app.src}/src/SKILL.md" + ''

        ## AP's setup

        * Own mods, layouts and themes live in `home-manager/modules/hc/app/<package>/{mods,layouts,themes}/` (dotfiles repo). Edit and create them there
        * `~/.config/herdr-app` holds links only. A new package or mod needs a home switch: ask AP to run it
        * Move `mod.clone` and `layout.clone` output into a package; do not leave it under `~/.config/herdr-app`
        * Links into `/nix/store` are pinned third-party content: read-only. Clone to customize
        * Shipped names are reserved; the build rejects them
        * Editing a linked mod does not hot-reload: run `touch -h ~/.config/herdr-app/mods/<name>`
        * `herdr-app check` works on a linked folder
      '';
    };
  };
}
