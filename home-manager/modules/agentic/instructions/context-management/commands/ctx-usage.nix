{
  nixantic.sources.context-management.commands."ctx-usage" = {
    description = "Analyze context window, breakdown messages by turns, tools, large items. Give optimization hints...";

    harnesses = [ "claude" ];

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
         - Large Task agent results
         - Many Read results
         - Repeated system reminder injections
         - Long assistant messages with thinking
         - Messages > ~60k tokens
    '';
  };
}
