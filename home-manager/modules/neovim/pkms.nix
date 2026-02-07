{ config, ... }:
let
  pkmsDir = "${config.home.homeDirectory}/pkms";

  # https://oxide.md/Configuration
  moxideConfig = ''
    # Daily notes date format (strftime). Creates daily/2026/02/2026-02-01-daily.md
    dailynote = "%Y/%m/%Y-%m-%d-daily"

    # Folder for daily notes (relative to vault root)
    daily_notes_folder = "${pkmsDir}/daily"

    # Default folder for new files created via code actions
    new_file_folder_path = "${pkmsDir}"

    # Fuzzy match file headings in completions
    heading_completions = true

    # Use first heading as note title in link display text
    # [](file) -> [first heading](file)
    title_headings = true

    # Show diagnostics for unresolved links
    unresolved_diagnostics = true

    # Enable semantic tokens for syntax highlighting
    semantic_tokens = true

    # Resolve tags/references in code blocks
    tags_in_codeblocks = false
    references_in_codeblocks = false

    # Include .md extension in links
    # [File](file.md) vs [File](file)
    include_md_extension_md_link = false
    # [[File.md]] vs [[File]]
    include_md_extension_wikilink = false

    # Enable hover info
    hover = true

    # Case matching in fuzzy search: Ignore | Smart | Respect
    case_matching = "Smart"

    # Inlay hints for backlinks count etc
    inlay_hints = true

    # Show transclusion content for ![[link]] embeds
    block_transclusion = true
    # Full or { partial = N } for N lines
    block_transclusion_length = "Full"

    # Complete by heading but link to filename only (for Zettelkasten)
    link_filenames_only = true
  '';
in
{
  xdg.configFile."moxide/settings.toml".text = moxideConfig;
}
