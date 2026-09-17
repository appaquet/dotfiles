#!/usr/bin/env python3
"""Unit tests for the read-only pi-session-query CLI.

Run with `just test pi-session-query-unit`, or `python3 pi-session-query.test.py` for a fast loop.
"""

import importlib.util
import io
import json
import pathlib
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from unittest import mock

MODULE_PATH = pathlib.Path(__file__).resolve().with_name("pi-session-query.py")
SPEC = importlib.util.spec_from_file_location("pi_session_query", MODULE_PATH)
query = importlib.util.module_from_spec(SPEC)
# dataclasses resolve annotations through sys.modules during module execution.
sys.modules[SPEC.name] = query
SPEC.loader.exec_module(query)


class RecordNormalizationTests(unittest.TestCase):
    """Verify how persisted entries become independently searchable records."""

    def test_assistant_thinking_exposes_text_without_opaque_payloads(self):
        entry = message_entry(
            "assistant-entry",
            {
                "role": "assistant",
                "content": [
                    thinking_block("Hidden reasoning needle", signature="SIGNATURE-SECRET"),
                    {"type": "text", "text": "Visible conclusion"},
                ],
                "model": "test-model",
                "stopReason": "stop",
            },
        )

        records = list(query.records_for_entry(entry, 2, 0))

        self.assertEqual(["thinking", "assistant-text"], [record.kind for record in records])
        self.assertEqual("Hidden reasoning needle", records[0].text)
        self.assertEqual("test-model", records[0].payload["model"])
        self.assertNotIn("thinkingSignature", records[0].payload)
        self.assertNotIn("encrypted_content", records[0].payload)
        self.assertNotIn("SIGNATURE-SECRET", json.dumps(records[0].payload))

    def test_tool_call_carries_bounded_arguments_and_linkage(self):
        entry = message_entry(
            "assistant-entry",
            {
                "role": "assistant",
                "content": [
                    {"type": "toolCall", "id": "call-1", "name": "read", "arguments": {"path": "/work/file.txt"}},
                    {"type": "toolCall", "id": "call-2", "name": "bash"},
                ],
                "stopReason": "toolUse",
            },
        )

        first, second = list(query.records_for_entry(entry, 4, 0))

        self.assertEqual("assistant-tool-call", first.kind)
        self.assertEqual("read", first.tool_name)
        self.assertEqual("call-1", first.payload["toolCallId"])
        self.assertEqual({"path": "/work/file.txt"}, first.payload["arguments"])
        self.assertEqual('read {"path":"/work/file.txt"}', first.text)
        self.assertIsNone(second.payload["arguments"])

    def test_tool_result_reports_error_usage_and_image_count(self):
        entry = message_entry(
            "tool-entry",
            {
                "role": "toolResult",
                "toolCallId": "call-1",
                "toolName": "read",
                "content": [{"type": "text", "text": "boom"}, image_block()],
                "isError": True,
                "usage": {"input": 5, "output": 6, "totalTokens": 11},
            },
        )

        record = next(iter(query.records_for_entry(entry, 5, 0)))

        self.assertEqual("tool-result", record.kind)
        self.assertIs(True, record.payload["isError"])
        self.assertEqual(1, record.payload["images"])
        self.assertEqual(11, record.payload["usage"]["totalTokens"])
        self.assertEqual("call-1", record.payload["toolCallId"])
        self.assertEqual("call-1", next(iter(query.records_for_entry(entry, 5, 0))).payload["toolCallId"])

    def test_bash_execution_records_share_one_kind(self):
        modern = message_entry(
            "bash-message",
            {
                "role": "bashExecution",
                "command": "echo command",
                "output": "output",
                "exitCode": 3,
                "truncated": True,
            },
        )
        legacy = {
            "type": "bashExecution",
            "id": "bash-legacy",
            "command": "echo legacy",
            "output": "legacy output",
        }

        modern_record = next(iter(query.records_for_entry(modern, 6, 0)))
        legacy_record = next(iter(query.records_for_entry(legacy, 7, 0)))

        for record in (modern_record, legacy_record):
            self.assertEqual("bash", record.kind)
            self.assertEqual("bash", record.tool_name)
        self.assertEqual("echo command\noutput", modern_record.text)
        self.assertEqual(3, modern_record.payload["exitCode"])
        self.assertIs(True, modern_record.payload["truncated"])
        self.assertEqual("echo legacy\nlegacy output", legacy_record.text)

    def test_image_only_tool_result_yields_no_record(self):
        entry = message_entry(
            "image-entry",
            {"role": "toolResult", "toolCallId": "call-1", "toolName": "read", "content": [image_block()]},
        )

        self.assertEqual([], list(query.records_for_entry(entry, 8, 0)))

    def test_summaries_and_custom_messages_normalize(self):
        compaction = {
            "type": "compaction",
            "id": "compaction-entry",
            "summary": "Compaction summary",
            "firstKeptEntryId": "kept",
        }
        branch = {"type": "branch_summary", "id": "branch-entry", "summary": "Branch summary"}
        custom = {"type": "custom_message", "id": "custom-entry", "content": "Custom text"}

        self.assertEqual("compaction-summary", next(iter(query.records_for_entry(compaction, 9, 0))).kind)
        self.assertEqual("branch-summary", next(iter(query.records_for_entry(branch, 10, 0))).kind)
        self.assertEqual("custom-message", next(iter(query.records_for_entry(custom, 11, 0))).kind)


class PayloadBoundingTests(unittest.TestCase):
    """Verify forensic payload fields stay bounded and JSON-safe."""

    def test_long_strings_are_truncated_with_a_marker(self):
        bounded = query.payload_value("x" * 100_000)

        self.assertLessEqual(len(bounded), query.MAX_PAYLOAD_CHARS + 1)
        self.assertTrue(bounded.endswith("…"))

    def test_nesting_is_capped_before_the_recursion_limit(self):
        nested = {"leaf": "value"}
        for _ in range(500):
            nested = {"child": nested}

        bounded = query.payload_value(nested)

        self.assertIn("…deeper", json.dumps(bounded, ensure_ascii=False))

    def test_item_and_key_limits_fold_the_remainder(self):
        items = query.payload_value(list(range(100)))
        fields = query.payload_value({f"key{index}": index for index in range(100)})

        self.assertEqual(query.MAX_PAYLOAD_ITEMS, len(items) - 1)
        self.assertEqual("…75 more items", items[-1])
        self.assertEqual(query.MAX_PAYLOAD_KEYS, len(fields) - 1)
        self.assertEqual("75 more keys", fields["…more"])

    def test_non_json_values_become_type_markers(self):
        self.assertEqual("<object>", query.payload_value(object()))

    def test_usage_payload_keeps_tokens_and_cost_total(self):
        payload = query.usage_payload(
            {"input": 11, "output": 22, "totalTokens": 110, "cost": {"total": 0.0123}}
        )

        self.assertEqual({"input": 11, "output": 22, "totalTokens": 110, "costTotal": 0.0123}, payload)
        self.assertEqual({}, query.usage_payload(None))

    def test_bounded_counts_folds_rare_names(self):
        counts = {f"tool{index}": 1 for index in range(query.MAX_COUNT_KEYS + 9)}
        counts["bash"] = 5

        bounded = query.bounded_counts(counts)

        self.assertEqual(query.MAX_COUNT_KEYS + 1, len(bounded))
        self.assertEqual("bash", next(iter(bounded)))
        self.assertEqual(5, bounded["bash"])
        self.assertEqual(10, bounded["…other"])


class StreamAndSelectionTests(unittest.TestCase):
    """Verify transcript streaming, filtering, and pagination behavior."""

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.session_dir = pathlib.Path(self.directory.name)

    def test_iter_records_keeps_ordinals_unique_across_entries(self):
        path = self.session_dir / "session.jsonl"
        write_session(
            path,
            header("session"),
            message_entry("user-entry", {"role": "user", "content": "First request"}),
            message_entry(
                "assistant-entry",
                {
                    "role": "assistant",
                    "content": [{"type": "text", "text": "Second"}, {"type": "text", "text": "Third"}],
                },
            ),
        )

        records = list(query.iter_records(path))

        self.assertEqual([0, 1, 2], [record.ordinal for record in records])
        self.assertEqual(["user", "assistant-text", "assistant-text"], [record.kind for record in records])

    def test_iter_entries_reports_decoder_stack_exhaustion(self):
        path = self.session_dir / "session.jsonl"
        write_session(path, header("session"), message_entry("user-entry", {"role": "user", "content": "text"}))

        with mock.patch.object(query.json, "loads", side_effect=RecursionError("stack")):
            with self.assertRaises(query.QueryError) as raised:
                list(query.iter_entries(path))

        self.assertIn("JSON nesting too deep", str(raised.exception))

    def test_discovery_skips_transcripts_with_decoder_stack_exhaustion(self):
        path = self.session_dir / "session.jsonl"
        write_session(path, header("session"), message_entry("user-entry", {"role": "user", "content": "text"}))

        with mock.patch.object(query.json, "loads", side_effect=RecursionError("stack")):
            self.assertIsNone(query.read_session_info(path))

    def test_select_records_applies_kinds_context_and_pagination(self):
        records = [
            build_record(0, "entry-0", "user", "Earlier context"),
            build_record(1, "entry-1", "user", "Needle request"),
            build_record(2, "entry-2", "assistant-text", "Assistant reply"),
            build_record(3, "entry-3", "tool-result", "Tool output"),
            build_record(4, "entry-4", "user", "Needle follow-up"),
        ]
        arguments = query.build_parser().parse_args(
            ["query", "session", "--kind", "user", "--kind", "assistant-text", "--match", "needle",
             "--before", "1", "--after", "1", "--limit", "1"]
        )

        selection = query.select_records(records, arguments, arguments.limit)

        self.assertEqual(["entry-0", "entry-1", "entry-2"], [record.entry_id for record in selection.records])
        self.assertEqual(1, selection.returned)
        self.assertTrue(selection.has_more)

    def test_matches_session_filters_on_cwd_boundary_name_and_text(self):
        session = session_info("/work/project/sub", "Sprint review", "Roadmap request")

        self.assertTrue(query.matches_session(session, "/work/project/sub", None, ("sprint",), ("ROADMAP",)))
        self.assertTrue(query.matches_session(session, None, "/work/project", (), ()))
        self.assertFalse(
            query.matches_session(session_info("/work/project-a", "Sprint review", "Roadmap"), None, "/work/project", (), ())
        )
        self.assertFalse(query.matches_session(session, "/work/project-b", None, (), ()))
        self.assertFalse(query.matches_session(session, None, None, ("release",), ()))
        self.assertFalse(query.matches_session(session, None, None, (), ("missing",)))


class InspectionTests(unittest.TestCase):
    """Verify session statistics, entry detail, and relationship discovery."""

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.session_dir = pathlib.Path(self.directory.name)
        self.root = self.session_dir / "project" / "2026-01-01T00-00-00-000Z_forensic-root.jsonl"
        self.root.parent.mkdir(parents=True)
        write_session(
            self.root,
            header("forensic-root"),
            {"type": "session_info", "name": "Forensic session"},
            message_entry("forensic-user", {"role": "user", "content": [{"type": "text", "text": "Request"}, image_block()]}, timestamp=1),
            message_entry(
                "forensic-assistant",
                {
                    "role": "assistant",
                    "content": [
                        thinking_block("Thinking needle", signature="SIGNATURE-SECRET"),
                        {"type": "text", "text": "Assistant text"},
                        {"type": "toolCall", "id": "call-1", "name": "read", "arguments": {"path": "/work/file.txt"}},
                    ],
                    "provider": "test-provider",
                    "model": "test-model",
                    "stopReason": "toolUse",
                },
                parent_id="forensic-user",
                timestamp=2,
            ),
            message_entry(
                "forensic-result",
                {
                    "role": "toolResult",
                    "toolCallId": "call-1",
                    "toolName": "read",
                    "content": [{"type": "text", "text": "Tool error"}],
                    "isError": True,
                },
                parent_id="forensic-assistant",
                timestamp=3,
            ),
            message_entry(
                "forensic-bash",
                {"role": "bashExecution", "command": "echo command", "output": "output", "exitCode": 0},
                parent_id="forensic-result",
                timestamp=4,
            ),
            message_entry(
                "forensic-image-only",
                {"role": "toolResult", "toolCallId": "call-2", "toolName": "read", "content": [image_block()], "isError": True},
                parent_id="forensic-bash",
                timestamp=5,
            ),
        )

    def test_scan_session_counts_entries_records_tools_models_and_activity(self):
        scan, detail = query.scan_session(self.root, None)

        self.assertIsNone(detail)
        self.assertEqual("forensic-root", scan.session_id)
        self.assertEqual("3", scan.version)
        self.assertEqual("Forensic session", scan.name)
        self.assertEqual(5, scan.entries)
        self.assertEqual(7, scan.last_line)
        self.assertEqual("2026-01-01T00:00:01.000Z", scan.first_activity)
        self.assertEqual("2026-01-01T00:00:05.000Z", scan.last_activity)
        self.assertEqual({"message": 5, "session_info": 1}, scan.entry_types)
        self.assertEqual(
            {"user": 1, "thinking": 1, "assistant-text": 1, "assistant-tool-call": 1, "tool-result": 1, "bash": 1},
            scan.record_kinds,
        )
        self.assertEqual({"read": 1}, scan.tool_calls)
        self.assertEqual(2, scan.tool_errors)
        self.assertEqual({"test-model": 1}, scan.models)
        self.assertEqual({"test-provider": 1}, scan.providers)

    def test_scan_session_returns_one_entry_detail_without_opaque_payloads(self):
        _, detail = query.scan_session(self.root, "forensic-assistant")

        self.assertEqual(4, detail.line)
        self.assertEqual("message", detail.entry_type)
        self.assertEqual("forensic-user", detail.parent_id)
        self.assertEqual("assistant", detail.role)
        self.assertEqual(["thinking", "assistant-text", "assistant-tool-call"], [record.kind for record in detail.records])
        self.assertNotIn("SIGNATURE-SECRET", query.json_entry(detail, 1_000))

    def test_scan_session_rejects_missing_and_duplicate_entry_ids(self):
        with self.assertRaises(query.QueryError) as missing:
            query.scan_session(self.root, "absent-entry")
        self.assertIn("Entry ID not found: absent-entry", str(missing.exception))

        duplicated = self.session_dir / "duplicated.jsonl"
        write_session(
            duplicated,
            header("duplicated"),
            message_entry("dup-entry", {"role": "user", "content": "First"}),
            message_entry("dup-entry", {"role": "user", "content": "Second"}, timestamp=2),
        )
        with self.assertRaises(query.QueryError) as duplicate:
            query.scan_session(duplicated, "dup-entry")
        self.assertIn("Duplicate entry ID 'dup-entry' at lines 2, 3", str(duplicate.exception))

    def test_related_sessions_finds_parent_link_and_direct_children_only(self):
        children = [
            ("forensic-child-one", "2026-01-02T00:00:00.000Z"),
            ("forensic-child-two", "2026-01-03T00:00:00.000Z"),
        ]
        for session_id, timestamp in children:
            write_session(
                self.session_dir / "nested" / "deeper" / f"{session_id}.jsonl",
                header(session_id, timestamp=timestamp, parent_session=str(self.root)),
                message_entry(f"{session_id}-user", {"role": "user", "content": "Child"}),
            )
        write_session(
            self.session_dir / "grandchild.jsonl",
            header("forensic-grandchild", timestamp="2026-01-04T00:00:00.000Z", parent_session=str(self.session_dir / "nested" / "deeper" / "forensic-child-one.jsonl")),
            message_entry("grandchild-user", {"role": "user", "content": "Grandchild"}),
        )
        write_session(
            self.session_dir / "unrelated.jsonl",
            header("unrelated-session", timestamp="2026-01-05T00:00:00.000Z", parent_session="/nowhere/absent.jsonl"),
            message_entry("unrelated-user", {"role": "user", "content": "Unrelated"}),
        )

        root_scan, _ = query.scan_session(self.root, None)
        related = query.related_sessions(self.session_dir, root_scan)

        self.assertEqual("", related.parent)
        self.assertEqual("", related.parent_id)
        self.assertEqual(["forensic-child-two", "forensic-child-one"], [child.session_id for child in related.children])
        self.assertFalse(related.truncated)

        child_scan, _ = query.scan_session(self.session_dir / "nested" / "deeper" / "forensic-child-one.jsonl", None)
        child_related = query.related_sessions(self.session_dir, child_scan)

        self.assertEqual(str(self.root), child_related.parent)
        self.assertEqual("forensic-root", child_related.parent_id)
        self.assertEqual(["forensic-grandchild"], [child.session_id for child in child_related.children])

    def test_inspect_renders_summary_entry_and_relationships(self):
        scan, detail = query.scan_session(self.root, "forensic-assistant")
        related = query.related_sessions(self.session_dir, scan)

        text = query.text_inspect(scan, detail, related, 1_000)
        document = json.loads(query.json_inspect(scan, related))
        entry = json.loads(query.json_entry(detail, 1_000))

        self.assertIn("tool_errors: 2", text)
        self.assertIn("record_kind.thinking: 1", text)
        self.assertIn("[entry | id: forensic-assistant | line: 4", text)
        self.assertIn("parent_session: (none)", text)
        self.assertEqual("inspect", document["type"])
        self.assertIn("call-1", text)
        self.assertEqual(["read"], list(document["tool_calls"]))
        self.assertEqual("entry", entry["type"])
        self.assertEqual("call-1", entry["records"][2]["toolCallId"])
        self.assertEqual({"path": "/work/file.txt"}, entry["records"][2]["arguments"])


class CommandTests(unittest.TestCase):
    """Verify the packaged command contract that the smoke check also covers."""

    def test_payload_requests_require_jsonl_output(self):
        errors = io.StringIO()

        with redirect_stdout(io.StringIO()), redirect_stderr(errors):
            status = query.main(["query", "missing-session", "--kind", "thinking", "--include-payload"])

        self.assertEqual(2, status)
        self.assertIn("--include-payload requires --format jsonl", errors.getvalue())

    def test_json_record_hides_payload_until_requested(self):
        entry = message_entry(
            "assistant-entry",
            {"role": "assistant", "content": [{"type": "toolCall", "id": "call-1", "name": "read", "arguments": {"path": "/work/file.txt"}}]},
        )
        record = next(iter(query.records_for_entry(entry, 2, 0)))

        self.assertNotIn("arguments", json.loads(query.json_record(record, 100)))
        self.assertEqual({"path": "/work/file.txt"}, json.loads(query.json_record(record, 100, True))["arguments"])


def session_info(cwd, name, text):
    """Build one discovered-session record for filter tests."""

    return query.SessionInfo(
        path=pathlib.Path(cwd) / "session.jsonl",
        session_id="session",
        cwd=cwd,
        timestamp="2026-01-01T00:00:00.000Z",
        modified="2026-01-01T00:00:00.000Z",
        name=name,
        message_count=1,
        first_message=text,
        searchable_text=f"{name}\n{text}",
    )


def header(session_id, timestamp="2026-01-01T00:00:00.000Z", parent_session=None, cwd="/work/project"):
    """Build one v3 session header for a temporary transcript."""

    document = {"type": "session", "version": 3, "id": session_id, "timestamp": timestamp, "cwd": cwd}
    if parent_session:
        document["parentSession"] = parent_session
    return document


def message_entry(entry_id, message, parent_id=None, timestamp=1):
    """Build one persisted message entry around a message document."""

    entry = {
        "type": "message",
        "id": entry_id,
        "timestamp": f"2026-01-01T00:00:0{timestamp}.000Z",
        "message": message,
    }
    if parent_id:
        entry["parentId"] = parent_id
    return entry


def thinking_block(text, signature=None):
    """Build one thinking content block, optionally with an opaque signature."""

    block = {"type": "thinking", "thinking": text}
    if signature:
        block["thinkingSignature"] = signature
        block["encrypted_content"] = "ENCRYPTED-SECRET"
    return block


def image_block():
    """Build one image content block that must never reach the output."""

    return {"type": "image", "data": "IMAGEBASE64SECRET", "mimeType": "image/png"}


def build_record(ordinal, entry_id, kind, text):
    """Build one standalone record for selection tests."""

    return query.build_record(ordinal, {"id": entry_id}, ordinal + 2, kind, text)


def write_session(path, *lines):
    """Write one JSONL transcript whose first line is its header."""

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for line in lines:
            handle.write(f"{json.dumps(line)}\n")


if __name__ == "__main__":
    unittest.main()
