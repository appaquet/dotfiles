{ ... }:
{
  home.file.".pi/agent/mcp.json".text = builtins.toJSON {
    mcpServers.chrome = {
      command = "mcp-npx";
      args = [
        "-y"
        "chrome-devtools-mcp@latest"
        "--browser-url=http://127.0.0.1:9222"
        "--experimentalPageIdRouting"
      ];
      exposure = "codemode";
    };
  };
}
