{
  nixantic.sources.harnesses.skills."pi-recaller" = {
    kind = "directory";
    main = {
      harnesses = [ "pi" ];
      description = "Use when a user asks to find, list, recall, query, filter, inspect, or measure persisted Pi sessions or session transcripts.";
      content = ''
        # Pi Session Recall

        Use `pi-session-query` immediately when the user asks to find, list, filter, recall, or measure persisted Pi sessions, or names a Pi session, session ID, or session JSONL path. It reads persisted transcripts without resuming, switching, or changing the session.

        ## Method

        1. **Load the command reference**
           - Run `pi-session-query --help` with the shell tool immediately
           - Treat stdout as authoritative for complete `list`, `resolve`, `query`, `inspect`, and `stats` syntax and maintained examples

        2. **Measure the corpus**
           - Use `stats` for corpus-wide reviewer and sub-agent measurements instead of listing sessions individually
           - Bound comparisons with `--since` and `--until`
           - Exclude unrelated repositories with repeatable `--exclude-cwd-prefix`
           - Add `--classify-targets` only for the planning or phase-doc review bucket

        3. **Find candidate sessions**
           - If no precise reference was supplied, use `list` with relevant filters
           - Keep results bounded
           - Ask the user to choose when multiple candidates remain
           - Do not manually search session directories

        4. **Resolve the session reference**
           - Resolve a supplied or selected reference before querying
           - Accept an absolute JSONL path, full session ID, unique session-ID prefix, or validated filename alias
           - If resolution is ambiguous or missing, report the candidates or error and ask for a precise reference

        5. **Inspect session structure**
           - Use `inspect` when the question is about the session or one entry rather than a topic
           - Use default output for bounded metadata and counts
           - Add `--entry-id` for one entry with structured evidence
           - Add `--related` for parent and child session links
           - Triage with `inspect` before querying large record volumes

        6. **Query session records**
           - Query the resolved reference
           - Expect user and assistant text only by default
           - Use the help reference to select filters, context, output format, and pagination
           - Continue pagination with `next_offset`

        7. **Select explicit record kinds**
           - User requests or decisions: `--kind user`
           - Assistant conclusions: `--kind assistant-text`
           - Model reasoning: `--kind thinking`
           - Agent tool invocations: `--kind assistant-tool-call`
           - Tool output: `--kind tool-result`
           - User shell executions: `--kind bash`
           - Compaction or branch summaries: `--kind compaction-summary` or `--kind branch-summary`
           - Extension-injected text: `--kind custom-message`
           - Repeat `--kind` to include multiple kinds
           - Add `--tool '<name>'` for a specific tool
           - Use `--match` for literal text and `--regex` only for regular expressions

        8. **Request structured payloads only when needed**
           - Use them for tool arguments, call linkage, error state, or model and usage metadata
           - Use `--include-payload` with `--format jsonl`, or `inspect --entry-id`
           - Never return thinking signatures, image bytes, or encrypted reasoning payloads

        9. **Keep evidence focused**
           - Use bounded limits, offsets, record sizes, and context instead of reading a full transcript
           - Keep reasoning and payload content out of the answer unless required
           - Never paste large payloads to the user

        10. **Answer from returned evidence**
            - Cite the entry ID and JSONL line shown by the command
            - Distinguish direct transcript evidence from inference
            - Say when no matching evidence was found
      '';
    };
    files = { };
  };
}
