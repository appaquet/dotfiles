{ pkgs, piSessionQuery }:

# Smoke test for the packaged command seam: the wrapper, its Python runtime, real
# transcript JSONL, the privacy boundary, and the exit-code contract. Behavior-level
# coverage lives in the pi-session-query-unit check.
pkgs.runCommand "pi-session-query-check"
  {
    nativeBuildInputs = [
      piSessionQuery
      pkgs.coreutils
      pkgs.gnugrep
    ];
  }
  ''
    set -eu

    session_dir="$TMPDIR/sessions"
    mkdir -p "$session_dir/project-a"

    primary="$session_dir/project-a/2026-09-15T12-00-00-000Z_aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa.jsonl"
    child="$session_dir/project-a/2026-09-15T12-01-00-000Z_smoke-child.jsonl"

    cat >"$primary" <<'EOF'
    {"type":"session","version":3,"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","timestamp":"2026-09-15T12:00:00.000Z","cwd":"/work/project-a"}
    {"type":"session_info","name":"Smoke session"}
    {"type":"message","id":"user-request","parentId":null,"timestamp":"2026-09-15T12:00:01.000Z","message":{"role":"user","content":[{"type":"text","text":"Smoke request"},{"type":"image","data":"IMAGEBASE64SECRET","mimeType":"image/png"}],"timestamp":1}}
    {"type":"message","id":"assistant-turn","parentId":"user-request","timestamp":"2026-09-15T12:00:02.000Z","message":{"role":"assistant","content":[{"type":"thinking","thinking":"Smoke thinking needle","thinkingSignature":"SIGNATURE-SECRET"},{"type":"text","text":"Smoke answer"},{"type":"toolCall","id":"call-smoke","name":"bash","arguments":{"command":"agentic-proj-docs"}}],"provider":"smoke-provider","model":"smoke-model","stopReason":"toolUse","timestamp":2}}
    {"type":"message","id":"tool-error","parentId":"assistant-turn","timestamp":"2026-09-15T12:00:03.000Z","message":{"role":"toolResult","toolCallId":"call-smoke","toolName":"bash","content":[{"type":"text","text":"Smoke tool failure"},{"type":"image","data":"IMAGEBASE64SECRET","mimeType":"image/png"}],"isError":true,"timestamp":3}}
    EOF

    cat >"$child" <<EOF
    {"type":"session","version":3,"id":"smoke-child","timestamp":"2026-09-15T12:01:00.000Z","cwd":"/work/project-a","parentSession":"$primary"}
    {"type":"session_info","name":"architecture-reviewer#smoke"}
    {"type":"message","id":"child-user","timestamp":"2026-09-15T12:01:01.000Z","message":{"role":"user","content":"Review the technical plan in README.md"}}
    EOF

    assert_contains() {
      expected="$1"
      actual="$2"
      if ! grep -F -- "$expected" "$actual" >/dev/null; then
        echo "Expected '$expected' in $actual" >&2
        cat "$actual" >&2
        exit 1
      fi
    }

    assert_not_contains() {
      unexpected="$1"
      actual="$2"
      if grep -F -- "$unexpected" "$actual" >/dev/null; then
        echo "Did not expect '$unexpected' in $actual" >&2
        cat "$actual" >&2
        exit 1
      fi
    }

    COLUMNS=80 pi-session-query --help >help.out
    assert_contains "usage: pi-session-query [-h] {list,resolve,query,inspect,stats} ..." help.out
    assert_contains "Privacy: assistant thinking is returned only by an explicit --kind thinking" help.out

    pi-session-query query "$primary" --session-dir "$session_dir" --kind assistant-tool-call --kind tool-result --include-payload --format jsonl >payload.out
    test "$(wc -l <payload.out)" = 3
    assert_contains '"arguments":{"command":"agentic-proj-docs"}' payload.out
    assert_contains '"toolCallId":"call-smoke"' payload.out
    assert_contains '"isError":true' payload.out
    assert_contains '"images":1' payload.out
    assert_not_contains "IMAGEBASE64SECRET" payload.out
    assert_not_contains "SIGNATURE-SECRET" payload.out

    pi-session-query inspect "$primary" --session-dir "$session_dir" >inspect.out
    assert_contains "id: aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" inspect.out
    assert_contains "entries: 3" inspect.out

    pi-session-query stats --session-dir "$session_dir" --since 2026-09-15 --until 2026-09-15 --classify-targets --group-by day --format jsonl >stats.out
    assert_contains '"top_level_sessions":1' stats.out
    assert_contains '"subagent_spawns":1' stats.out
    assert_contains '"reviewer_spawns":1' stats.out
    assert_contains '"group_by":"day"' stats.out
    assert_contains '"series":{"2026-09-15":{"top_level_sessions":1,"subagent_spawns":1,"reviewer_spawns":1,"reviewer_spawns_per_top_level_session":1.0}}' stats.out
    assert_contains '"ad_hoc_reviewer_spawns":1' stats.out
    assert_contains '"markdown_or_plan_review":1' stats.out

    pi-session-query inspect "$primary" --session-dir "$session_dir" --entry-id assistant-turn --related --format jsonl >entry.out
    test "$(wc -l <entry.out)" = 2
    assert_contains '"type":"entry"' entry.out
    assert_contains '"entry_id":"assistant-turn"' entry.out
    assert_contains '"children":[{"id":"smoke-child"' entry.out
    assert_not_contains "SIGNATURE-SECRET" entry.out

    if pi-session-query query "$primary" --session-dir "$session_dir" --kind thinking --include-payload >payload-text.out 2>payload-text.err; then
      echo "Text payload query unexpectedly succeeded" >&2
      exit 1
    fi
    assert_contains "--include-payload requires --format jsonl" payload-text.err

    touch "$out"
  ''
