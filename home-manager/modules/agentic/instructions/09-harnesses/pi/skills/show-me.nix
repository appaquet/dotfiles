{
  nixantic.sources.harnesses.skills."show-me" = {
    kind = "directory";
    main = {
      description = "Use when the user explicitly asks to show, visualize, explain visually, mock, or design something, or asks to start or reuse a show-me server.";
      asCommand = {
        opencode = true;
      };
      arguments = [ { label = "request"; } ];
      content = ''
        # Show Me

        Create and serve a visual HTML artifact, or manage a show-me server without creating an artifact. Run the server lifecycle through this harness's background-process mechanism.

        ## Boundaries

        - Act only on explicit visual intent, direct skill invocation, or an explicit show-me server request.
        - Keep generated artifacts uncommitted unless the user separately asks to commit them.
        - Do not include unrequested secrets or sensitive repository content.
        - Run `agentic-show-me-serve` as a background process through this harness's background-process tools. Never use shell `&` or another unmanaged process.
        - `agentic-show-me-serve` serves the root on all interfaces with no authentication. It opens an anonymous cloudflared quick tunnel only when `--public` is passed, and that tunnel's random `trycloudflare.com` hostname is then the only access control.
        - Do not open a browser.

        ## Route the request

        - Serve privately by default. Pass `--public` only when the user asks to make the artifact public or share the link, and drop it again when the user asks to stop sharing.
        - For a visual artifact request, select the serving root, create the artifact, ensure that root has a live show-me server, and return its URL.
        - For a server-only request such as `start a show me server`, select the serving root, skip artifact creation, start or reuse its server, and return its root URL.

        ## Select the serving root

        - Prefer the canonical target of `proj/` when it exists.
        - Otherwise use the canonical target of `proj-adhoc/` when it exists.
        - Otherwise create and remember a dedicated directory under `/tmp/`. Name it with the current UTC timestamp, for example `show-me-20260924-184529`; use `mktemp -d` when a timestamp cannot be determined.
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

        - Remember the canonical root, background job ID, whether it was started with `--public`, and the URLs it printed, for servers started in the current session.
        - For the same root, check the background job status through the harness's mechanism. Reuse only a job that is still running and whose loopback URL passes a bounded readiness probe.
        - The mode is fixed at start. To turn public mode on, stop the running task and start a new one with `--public`; to turn it off, stop it and start a new one without the flag. Either switch restarts the command, so the port and both URLs change.
        - If the task is absent, ended, or uncertain after context loss, start a new managed server. Do not scan for or attach to unmanaged processes.

        ### Start a server

        - Start a background job with `cwd` set to the canonical root, a clear label, a 24-hour timeout when the harness supports one, and the command `agentic-show-me-serve .`, or `agentic-show-me-serve --public .` when the user asked for a public link.
        - The command picks a free port and serves the root with `simple-http-server`. Do not select a port or start a server yourself.
        - Read the URL sentences from the background job log. A private server prints the internal URL; a public one prints the public URL a few seconds later, so read the log again if it has not appeared.

        ### Verify readiness

        - The command prints the internal URL only after the server accepts connections, so a printed internal URL is readiness evidence. It prints the public URL as soon as cloudflared reports it, which may take a moment to become reachable.
        - If no URL appears, or the command exits, inspect the job status and logs through the harness's mechanism and report the actionable failure.

        ## Validate the served artifact

        - Only validate when the user explicitly requests it (for example `validate in a browser` or `check the rendering`) and a browser tool is available: check for console errors and failed requests, then check for horizontal page overflow.
        - Also emulate a ~375px mobile viewport and re-check for clipping or unexpected scroll.
        - Browser validation runs headless; it does not open a browser on the user's machine.

        ## Return the URLs

        - Always report the internal `http://<host>.n3x.net:<port>/` URL, which works from the user's own devices.
        - Report the public `https://<random>.trycloudflare.com/` URL only when the server was started with `--public`. It changes on every start and is not reachable from devices whose DNS blocks `trycloudflare.com`.
        - A server-only request returns the root URL. An artifact request percent-encodes the artifact path relative to the serving root and appends it.
        - Report the background job ID and that stopping the job through the same mechanism stops the server. Do not report a localhost URL or open the browser.
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
