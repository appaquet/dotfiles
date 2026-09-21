{
  nixantic.sources.harnesses.skills."show-me" = {
    kind = "directory";
    main = {
      harnesses = [ "pi" ];
      description = "Use when the user explicitly asks to show, visualize, explain visually, mock, or design something, or asks to start or reuse a show-me server.";
      content = ''
        # Show Me

        Create and serve a visual HTML artifact, or manage a show-me server without creating an artifact. Use Pi's managed background Bash tools for the server lifecycle.

        ## Boundaries

        - Act only on explicit visual intent, direct skill invocation, or an explicit show-me server request.
        - Keep generated artifacts uncommitted unless the user separately asks to commit them.
        - Do not include unrequested secrets or sensitive repository content.
        - Use `background_bash_start` for the server. Never use shell `&` or another unmanaged process.
        - Preserve `simple-http-server`'s default all-interface binding. There is no application authentication.
        - Do not open a browser.

        ## Route the request

        - For a visual artifact request, select the serving root, create the artifact, ensure that root has a live show-me server, and return the artifact URL.
        - For a server-only request such as `start a show me server`, select the serving root, skip artifact creation, start or reuse its server, and return the root URL.

        ## Select the serving root

        - Prefer the canonical target of `proj/` when it exists.
        - Otherwise use the canonical target of `proj-adhoc/` when it exists.
        - Otherwise create and remember a dedicated directory under `/tmp/`. Use `PI_SESSION_ID` in its name when available; use `mktemp -d` when it is unavailable.
        - Canonicalize the root before comparing it with a remembered server root.

        ## Create a visual artifact

        Use this section only for artifact requests.

        - Use the user's filename when supplied. Otherwise choose a concise descriptive kebab-case `.html` filename.
        - Keep the artifact inside the selected root. Reject path traversal or an absolute destination outside that root.
        - Start from `template.html` in this skill's directory. Preserve its document structure, pinned dependency notes, focus treatment, and reduced-motion guard; drop every unused dependency and sample section.
        - Treat the template's dark expressive theme as a high-quality fallback, not a mandatory layout. Establish a visual thesis suited to the subject, then adapt the accent palette, composition, and content-specific components instead of mechanically filling placeholder sections.
        - Use hierarchy, depth, and restrained semantic color to explain relationships, status, or emphasis. Avoid a generic grayscale document or a repetitive grid of interchangeable cards when a diagram, timeline, comparison, annotated system view, or focused data display communicates better.
        - Add lightweight interaction when it materially improves understanding or exploration, such as filters, toggles, expandable detail, hover or focus inspection, or controlled animation. Keep the artifact useful without interaction; make controls keyboard-operable, show the current state, and provide a predictable initial or reset state.
        - Use a further pinned CDN dependency only when it materially improves the requested result.
        - When the user gives explicit design direction, replace or remove the template defaults instead of layering around them.

        - Use semantic markup, responsive layout, keyboard-accessible interaction, visible focus, adequate contrast, and reduced-motion handling.

        ## Manage a show-me server

        Use this section independently for a server-only request or after creating an artifact.

        ### Reuse a live server

        - Remember the canonical root, background task ID, and concrete port for servers started in the current Pi session.
        - For the same root, call `background_bash_status`. Reuse only a task that is still running and whose loopback URL passes a bounded readiness probe.
        - If the task is absent, ended, or uncertain after context loss, start a new managed server. Do not scan for or attach to unmanaged processes.

        ### Start a server

        - Select a concrete free high port. A short Node `net.Server` bound to port `0` may select and print a candidate before closing; do not pass port `0` to `simple-http-server`.
        - Call `background_bash_start` with `cwd` set to the canonical root, a clear label, `timeoutSeconds: 86400`, and a command shaped as `simple-http-server -i --port PORT .`.
        - Preserve the default bind address. Do not pass `--ip`, `--open`, authentication, upload, or redirect options.

        ### Verify readiness

        - Probe the requested loopback path through `127.0.0.1` for at most five seconds. Startup text alone is not readiness evidence.
        - If readiness fails, inspect it with `background_bash_status` and `background_bash_logs`.
        - Retry allocation and launch once only when the failure is a confirmed bind collision. Otherwise report the actionable failure.

        ## Validate the served artifact

        - When a chrome MCP server is available, validate the served artifact before reporting the URL: check for console errors and failed requests, then check for horizontal page overflow.
        - Also emulate a ~375px mobile viewport and re-check for clipping or unexpected scroll.
        - Chrome MCP validation runs headless; it does not open a browser on the user's machine.

        ## Return the public URL

        - Build the public hostname from the current Tailscale `Self.DNSName`: strip its trailing dot, take the first label as the machine name, and use `<machine>.n3x.net`. Use that FQDN directly; do not substitute localhost or another hostname.
        - A server-only request returns `http://<machine>.n3x.net:<port>/`.
        - An artifact request percent-encodes the artifact path relative to the serving root and returns `http://<machine>.n3x.net:<port>/<encoded-path>`.
        - Report the public URL, managed task ID, and that `background_bash_stop` stops the server. Do not report a localhost URL or open the browser.
      '';
    };
    files = {
      "template.html" = {
        kind = "md";
        content = builtins.readFile ./show-me.template.html;
      };
    };
  };
}
