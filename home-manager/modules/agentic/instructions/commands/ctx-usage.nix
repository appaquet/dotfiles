{ scope }:
{
  description = "Break down Messages portion of context window - turns, tools, large items, optimization hints...";

  content = ''
    Goal: analyze the **Messages** portion of context window in detail.

    ## Instructions

    1. 🔳 Verify `/context` was run
       - Look in conversation history for `/context` output (local-command-stdout with token breakdown)
       - If not found: **STOP** - tell user to run `/context` first, then re-run `/ctx-usage`

    2. 🔳 Analyze messages and report breakdown
       Scan the full conversation history. Estimate tokens as chars ÷ 4.

       **By Type**
       | Type | Count | Est. Tokens | % of Messages |
       |------|-------|-------------|---------------|
       | Tool results | | | |
       | Assistant msgs | | | |
       | User messages | | | |
       | System reminders | | | |
       | Tool calls | | | |
       | **Total** | | | 100% |

       **Tool Results by Tool** (aggregate)
       | Tool | Calls | Est. Tokens | Avg/call |
       |------|-------|-------------|----------|

       **Largest Individual Items** (top ~7, any type)
       | Turn | Type | Description | Est. Tokens |
       |------|------|-------------|-------------|

    3. 🔳 Optimization hints
       Give specific, actionable suggestions based on the breakdown:
       - Large Task agent results → use `/forked` to isolate agent work from parent context
       - Many Read results → stale reads accumulate; fresh session + `/ctx-load` if nearing limit
       - Repeated system reminder injections → note which memory files trigger most frequently
       - Long assistant messages with thinking → reduce if not needed
       - Messages > ~60k tokens → recommend fresh session with `/ctx-load`

    ${scope.blocks.pre-flight.reference}
  '';
}
