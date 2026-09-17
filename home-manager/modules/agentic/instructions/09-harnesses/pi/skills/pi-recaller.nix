{
  nixantic.sources.harnesses.skills."pi-recaller" = {
    kind = "directory";
    main = {
      harnesses = [ "pi" ];
      description = "Use when a user asks to find, list, recall, query, filter, or inspect persisted Pi sessions or session transcripts.";
      content = ''
        # Pi Session Recall

        Use `pi-session-query` immediately when the user asks to find, list, filter, or recall a historical Pi session, or names a Pi session, session ID, or session JSONL path. It reads persisted transcripts without resuming, switching, or changing the session.

        ## Method

        1. Run `pi-session-query --help` with the shell tool immediately. Treat its stdout as the authoritative reference for the complete `list`, `resolve`, `query`, and `inspect` syntax and maintained examples.

        2. If no precise session reference was supplied, use the `list` subcommand with the relevant filters to identify candidate sessions. Keep the result bounded and ask the user to choose when multiple candidates remain. Do not manually search session directories.

        3. If a session reference was supplied or selected, resolve it before querying. A reference can be an absolute JSONL path, full session ID, unique session-ID prefix, or validated filename alias. If resolution is ambiguous or missing, report the command's candidates or error and ask the user for a precise reference.

        4. Use `inspect` when the question is about the session or one entry rather than a topic. It returns bounded metadata and counts on its own, one entry with structured evidence when `--entry-id` is given, and parent and child session links when `--related` is given. Triage with `inspect` before querying large volumes of records.

        5. Query the resolved reference. The default result is user and assistant text only. Use the help reference to select filters, context, output format, and pagination; `next_offset` continues a paginated result set.

        6. Select explicit record kinds when the question needs non-conversation evidence:

           - User requests or decisions: `--kind user`
           - Assistant conclusions: `--kind assistant-text`
           - Model reasoning: `--kind thinking`
           - Agent tool invocations: `--kind assistant-tool-call`
           - Tool output: `--kind tool-result`
           - User shell executions: `--kind bash`
           - Compaction or branch summaries: `--kind compaction-summary` or `--kind branch-summary`
           - Extension-injected text: `--kind custom-message`

           Repeat `--kind` to include multiple kinds. Add `--tool '<name>'` for a specific tool. Use `--match` for literal text and `--regex` only when a regular expression is needed.

        7. Request structured payload evidence only when the question needs tool arguments, call linkage, error state, or model and usage metadata. Use `--include-payload` with `--format jsonl`, or `inspect --entry-id`. Thinking signatures, image bytes, and encrypted reasoning payloads are never returned.

        8. Keep evidence focused. Use bounded limits, offsets, record sizes, and context rather than reading a full transcript. Keep reasoning or payload content out of the answer unless the question requires it, and never paste large payloads to the user.

        9. Answer from the returned records. Cite the entry ID and JSONL line shown by the command, distinguish direct transcript evidence from inference, and say when no matching evidence was found.
      '';
    };
    files = { };
  };
}
