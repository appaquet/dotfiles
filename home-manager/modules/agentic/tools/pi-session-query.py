#!/usr/bin/env python3
"""Resolve and query persisted Pi session transcripts without modifying them."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import deque
from datetime import datetime, timezone
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator, Sequence


DEFAULT_KINDS = ("user", "assistant-text")
TOOL_KINDS = frozenset(("assistant-tool-call", "tool-result", "bash"))
KIND_CHOICES = (
    "user",
    "assistant-text",
    "thinking",
    "assistant-tool-call",
    "tool-result",
    "bash",
    "compaction-summary",
    "branch-summary",
    "custom-message",
)
DEFAULT_LIMIT = 20
DEFAULT_MAX_CHARS = 1_000
MAX_LIMIT = 100
MAX_CONTEXT = 20
MAX_RECORD_CHARS = 10_000
MAX_SESSION_FIELD_CHARS = 1_000
MAX_OUTPUT_CHARS = 50_000
MAX_PAYLOAD_CHARS = 4_000
MAX_PAYLOAD_ITEMS = 25
MAX_PAYLOAD_KEYS = 25
MAX_PAYLOAD_DEPTH = 20
MAX_COUNT_KEYS = 50
MAX_RELATED_SESSIONS = 50

REVIEWER_AGENT_NAMES = frozenset(
    (
        "architecture-reviewer",
        "code-correctness-reviewer",
        "code-style-reviewer",
        "requirements-reviewer",
    )
)
MARKDOWN_OR_PLAN_PATTERN = re.compile(
    r"(?:\b(?:plan|planning)\b|(?:^|[\s`])proj/[^\s`]+\.md\b|\b(?:across\s+(?:the\s+)?|read\s+all\s+)phase documents?\b)",
    re.IGNORECASE,
)

HELP_GUIDANCE = """\
Session directory precedence: --session-dir, then PI_CODING_AGENT_SESSION_DIR,
then ${PI_CODING_AGENT_DIR:-~/.pi/agent}/sessions. An absolute JSONL path bypasses
directory discovery.

Pagination: list and query apply --offset to primary filtered results. The output
includes next_offset and has_more; use next_offset to request the next page.
Query --before and --after add context without consuming the page. If context exceeds
the output budget, reduce --before, --after, or --max-chars.

Output: text emits a page header; JSONL starts with a page object. Every output page
is capped at 50,000 characters of complete records. inspect returns one session summary,
and JSONL additionally emits one entry object when --entry-id is used.

Privacy: assistant thinking is returned only by an explicit --kind thinking, and tool
payload fields only by --include-payload or inspect --entry-id. Image bytes, thinking
signatures, and encrypted reasoning payloads are never returned.

Invalid arguments and reported query errors are written to stderr and exit 2; --help exits 0.

Examples:
  pi-session-query list --limit 10
  pi-session-query list --cwd-prefix /work/project --name sprint --text roadmap
  pi-session-query resolve '985Z_<session-uuid>'
  pi-session-query query '<session-ref>' --match 'topic' --before 1 --after 1
  pi-session-query query '<session-ref>' --kind assistant-tool-call --tool bash --offset 20 --limit 20 --format jsonl
  pi-session-query query '<session-ref>' --kind thinking --match 'root cause' --limit 10
  pi-session-query query '<session-ref>' --kind tool-result --include-payload --format jsonl --limit 5
  pi-session-query inspect '<session-ref>'
  pi-session-query inspect '<session-ref>' --entry-id '<entry-id>'
  pi-session-query inspect '<session-ref>' --related
  pi-session-query stats --since 2026-09-01 --until 2026-09-30 --exclude-cwd-prefix /work/dotcore
"""


class QueryError(Exception):
    """Describes invalid session references, transcripts, or query parameters."""


@dataclass(frozen=True)
class SessionInfo:
    """Identifies validated Pi session metadata used for discovery and listing."""

    path: Path
    session_id: str
    cwd: str
    timestamp: str
    modified: str
    name: str
    message_count: int
    first_message: str
    searchable_text: str


@dataclass(frozen=True)
class Record:
    """Represents one independently searchable part of a persisted session entry."""

    ordinal: int
    entry_id: str
    line: int
    timestamp: str
    kind: str
    tool_name: str | None
    text: str
    payload: dict[str, object]


@dataclass(frozen=True)
class Page:
    """Describes a page of primary filtered results and its continuation."""

    offset: int
    limit: int
    returned: int
    next_offset: int | None
    has_more: bool


@dataclass(frozen=True)
class RecordSelection:
    """Holds paginated primary records with their requested transcript context."""

    records: list[Record]
    returned: int
    has_more: bool


@dataclass(frozen=True)
class EntryDetail:
    """Describes one persisted entry selected for forensic inspection."""

    entry_id: str
    line: int
    entry_type: str
    parent_id: str
    role: str
    timestamp: str
    records: list[Record]


@dataclass(frozen=True)
class SessionScan:
    """Summarizes the metadata, entries, and record kinds of one session transcript."""

    path: Path
    session_id: str
    version: str
    cwd: str
    name: str
    created: str
    parent_session: str
    first_activity: str
    last_activity: str
    entries: int
    last_line: int
    entry_types: dict[str, int]
    record_kinds: dict[str, int]
    tool_calls: dict[str, int]
    tool_errors: int
    models: dict[str, int]
    providers: dict[str, int]


@dataclass(frozen=True)
class RelatedSession:
    """Identifies one persisted child session linked to an inspected session."""

    session_id: str
    path: Path
    created: str


@dataclass(frozen=True)
class RelatedSessions:
    """Holds the recorded parent link and bounded children of one inspected session."""

    parent: str
    parent_id: str
    children: list[RelatedSession]
    truncated: bool


def bounded_int(label: str, minimum: int, maximum: int):
    """Create an argparse converter that rejects values outside a safe range."""

    def convert(value: str) -> int:
        try:
            parsed = int(value)
        except ValueError as error:
            raise argparse.ArgumentTypeError(f"{label} must be an integer") from error

        if not minimum <= parsed <= maximum:
            raise argparse.ArgumentTypeError(f"{label} must be between {minimum} and {maximum}")

        return parsed

    return convert


def nonnegative_int(label: str):
    """Create an argparse converter for an integer offset at or above zero."""

    def convert(value: str) -> int:
        try:
            parsed = int(value)
        except ValueError as error:
            raise argparse.ArgumentTypeError(f"{label} must be an integer") from error

        if parsed < 0:
            raise argparse.ArgumentTypeError(f"{label} must be greater than or equal to 0")

        return parsed

    return convert


def add_session_dir_argument(parser: argparse.ArgumentParser) -> None:
    """Add the shared session storage-location argument."""

    parser.add_argument(
        "--session-dir",
        metavar="PATH",
        help="Directory containing Pi session files; overrides environment and defaults",
    )


def add_session_arguments(parser: argparse.ArgumentParser) -> None:
    """Add the shared session reference and storage-location arguments."""

    parser.add_argument(
        "session_ref",
        help="Absolute JSONL path, session UUID, unique UUID prefix, or validated filename alias",
    )
    add_session_dir_argument(parser)


def build_parser() -> argparse.ArgumentParser:
    """Build the public command parser and its subcommands."""

    parser = argparse.ArgumentParser(
        prog="pi-session-query",
        description="Resolve, query, and inspect read-only Pi session JSONL transcripts.",
        # Keep generated subcommand help and examples readable in the top-level epilog.
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    subcommands = parser.add_subparsers(dest="command", required=True)

    listing = subcommands.add_parser("list", help="List recent persisted Pi sessions")
    add_session_dir_argument(listing)
    listing.add_argument("--cwd", metavar="PATH", help="Only include sessions with this exact canonical CWD")
    listing.add_argument(
        "--cwd-prefix",
        metavar="PATH",
        help="Only include sessions in this canonical CWD or one of its descendants",
    )
    listing.add_argument(
        "--name",
        action="append",
        metavar="TEXT",
        help="Case-insensitive session-name filter; repeat to require every name match",
    )
    listing.add_argument(
        "--text",
        action="append",
        metavar="TEXT",
        help="Case-insensitive filter for session name and user/assistant text; repeat to require every text match",
    )
    listing.add_argument(
        "--sort",
        choices=("modified", "created"),
        default="modified",
        help="Sort newest-first by modified time (default; Pi-compatible latest-message activity) or created time",
    )
    listing.add_argument(
        "--offset",
        type=nonnegative_int("--offset"),
        default=0,
        metavar="N",
        help="Number of filtered and sorted sessions to skip (default: 0)",
    )
    listing.add_argument(
        "--limit",
        type=bounded_int("--limit", 1, MAX_LIMIT),
        default=DEFAULT_LIMIT,
        metavar="N",
        help=f"Maximum sessions after filtering and sorting (1-{MAX_LIMIT}; default: {DEFAULT_LIMIT})",
    )
    listing.add_argument(
        "--format",
        choices=("text", "jsonl"),
        default="text",
        help="Output format (default: text)",
    )

    resolve = subcommands.add_parser("resolve", help="Resolve a session reference to one JSONL path")
    add_session_arguments(resolve)

    query = subcommands.add_parser("query", help="Query normalized records from one session transcript")
    add_session_arguments(query)
    query.add_argument(
        "--kind",
        action="append",
        choices=KIND_CHOICES,
        help="Record kind to include; repeat to include multiple kinds",
    )
    query.add_argument(
        "--exclude-tools",
        action="store_true",
        help="Exclude tool-call, tool-result, and bash records from selected kinds",
    )
    query.add_argument(
        "--tool",
        action="append",
        metavar="NAME",
        help="Only include records for this tool name; repeat to include multiple tools",
    )
    query.add_argument(
        "--match",
        action="append",
        metavar="TEXT",
        help="Case-insensitive literal text that every returned match must contain",
    )
    query.add_argument(
        "--regex",
        action="append",
        metavar="PATTERN",
        help="Regular expression that every returned match must satisfy; repeat to add patterns",
    )
    query.add_argument(
        "--include-payload",
        action="store_true",
        help="Add bounded structured tool and message payload fields to JSONL records",
    )
    query.add_argument(
        "--before",
        type=bounded_int("--before", 0, MAX_CONTEXT),
        default=0,
        metavar="N",
        help=f"Include up to N preceding selected records (0-{MAX_CONTEXT})",
    )
    query.add_argument(
        "--after",
        type=bounded_int("--after", 0, MAX_CONTEXT),
        default=0,
        metavar="N",
        help=f"Include up to N following selected records (0-{MAX_CONTEXT})",
    )
    query.add_argument(
        "--offset",
        type=nonnegative_int("--offset"),
        default=0,
        metavar="N",
        help="Number of matching records to skip before context is added (default: 0)",
    )
    query.add_argument(
        "--limit",
        type=bounded_int("--limit", 1, MAX_LIMIT),
        default=DEFAULT_LIMIT,
        metavar="N",
        help=f"Maximum matching records before context is added (1-{MAX_LIMIT}; default: {DEFAULT_LIMIT})",
    )
    query.add_argument(
        "--max-chars",
        type=bounded_int("--max-chars", 1, MAX_RECORD_CHARS),
        default=DEFAULT_MAX_CHARS,
        metavar="N",
        help=(
            f"Maximum text characters per rendered record (1-{MAX_RECORD_CHARS}; "
            f"default: {DEFAULT_MAX_CHARS})"
        ),
    )
    query.add_argument(
        "--format",
        choices=("text", "jsonl"),
        default="text",
        help="Output format (default: text)",
    )

    inspect = subcommands.add_parser(
        "inspect",
        help="Inspect one session's statistics, one entry, and related sessions",
    )
    add_session_arguments(inspect)
    inspect.add_argument(
        "--entry-id",
        metavar="ID",
        help="Add bounded structured detail for one persisted entry ID",
    )
    inspect.add_argument(
        "--related",
        action="store_true",
        help="Add the recorded parent session and children found under the session directory",
    )
    inspect.add_argument(
        "--max-chars",
        type=bounded_int("--max-chars", 1, MAX_RECORD_CHARS),
        default=DEFAULT_MAX_CHARS,
        metavar="N",
        help=(
            f"Maximum text characters per entry record (1-{MAX_RECORD_CHARS}; "
            f"default: {DEFAULT_MAX_CHARS})"
        ),
    )
    inspect.add_argument(
        "--format",
        choices=("text", "jsonl"),
        default="text",
        help="Output format (default: text)",
    )

    stats = subcommands.add_parser(
        "stats",
        help="Aggregate reviewer and sub-agent spawn metrics across the session corpus",
    )
    add_session_dir_argument(stats)
    stats.add_argument(
        "--since",
        metavar="DATE",
        help="Only include sessions created on or after this date (YYYY-MM-DD or ISO 8601)",
    )
    stats.add_argument(
        "--until",
        metavar="DATE",
        help="Only include sessions created on or before this date (YYYY-MM-DD or ISO 8601)",
    )
    stats.add_argument(
        "--exclude-cwd-prefix",
        action="append",
        metavar="PATH",
        help="Exclude sessions in this canonical CWD or a descendant; repeat for multiple paths",
    )
    stats.add_argument(
        "--classify-targets",
        action="store_true",
        help="Count reviewer prompts explicitly targeting planning or phase documents",
    )
    stats.add_argument(
        "--format",
        choices=("text", "jsonl"),
        default="text",
        help="Output format (default: text)",
    )

    parser.epilog = "\n\n".join(
        (
            "Command reference:",
            listing.format_help().rstrip(),
            resolve.format_help().rstrip(),
            query.format_help().rstrip(),
            inspect.format_help().rstrip(),
            stats.format_help().rstrip(),
            HELP_GUIDANCE.rstrip(),
        )
    )

    return parser


def default_session_dir(session_dir: str | None) -> Path:
    """Resolve the storage directory using Pi's documented precedence."""

    if session_dir:
        return Path(session_dir).expanduser()

    configured_dir = os.environ.get("PI_CODING_AGENT_SESSION_DIR")
    if configured_dir:
        return Path(configured_dir).expanduser()

    agent_dir = Path(os.environ.get("PI_CODING_AGENT_DIR") or "~/.pi/agent").expanduser()
    return agent_dir / "sessions"


def read_session_header(path: Path) -> dict[str, object] | None:
    """Read and validate the header line of one persisted Pi session file."""

    try:
        with path.open("rb") as session_file:
            raw_header = session_file.readline()
        header = json.loads(raw_header.decode("utf-8"))
    # Deeply nested JSON exhausts the decoder stack instead of raising a decode error.
    except (OSError, UnicodeError, json.JSONDecodeError, RecursionError):
        return None

    if not isinstance(header, dict) or header.get("type") != "session":
        return None

    session_id = header.get("id")
    if not isinstance(session_id, str) or not session_id:
        return None

    return header


def read_session_info(path: Path) -> SessionInfo | None:
    """Read validated Pi metadata while streaming one persisted session file."""

    header = read_session_header(path)
    if header is None:
        return None

    session_id = header["id"]
    name = ""
    message_count = 0
    first_message = ""
    texts: list[str] = []
    activity: object = header.get("timestamp")
    try:
        with path.open("rb") as session_file:
            # The validated header line carries no session metadata beyond the id.
            next(session_file, None)
            for raw_line in session_file:
                if not raw_line.strip():
                    continue
                entry = json.loads(raw_line.decode("utf-8"))
                if not isinstance(entry, dict):
                    return None
                if entry.get("type") == "session_info":
                    candidate_name = entry.get("name")
                    name = candidate_name.strip() if isinstance(candidate_name, str) else ""
                if entry.get("type") != "message":
                    continue
                message_count += 1
                message = entry.get("message")
                if not isinstance(message, dict):
                    continue
                role = message.get("role")
                text = text_content(message.get("content"))
                if role == "user" and text and not first_message:
                    first_message = text
                if role in ("user", "assistant") and text:
                    texts.append(text)
                if role in ("user", "assistant"):
                    message_timestamp = message.get("timestamp")
                    if isinstance(message_timestamp, (int, float)) and not isinstance(message_timestamp, bool):
                        activity = message_timestamp
                    elif isinstance(entry.get("timestamp"), str):
                        activity = entry["timestamp"]
    except (OSError, UnicodeError, json.JSONDecodeError, RecursionError):
        return None

    timestamp = header.get("timestamp") if isinstance(header.get("timestamp"), str) else ""
    return SessionInfo(
        path=path,
        session_id=session_id,
        cwd=header.get("cwd") if isinstance(header.get("cwd"), str) else "",
        timestamp=timestamp,
        modified=pi_timestamp(activity, path),
        name=name,
        message_count=message_count,
        first_message=first_message or "(no messages)",
        searchable_text="\n".join((name, *texts)),
    )


def list_sessions(arguments: argparse.Namespace) -> str:
    """Discover, filter, sort, and render bounded persisted-session metadata."""

    session_dir = default_session_dir(arguments.session_dir)
    if not session_dir.is_dir():
        raise QueryError(f"Session directory not found: {session_dir}")

    exact_cwd = canonical_path(arguments.cwd) if arguments.cwd else None
    cwd_prefix = canonical_path(arguments.cwd_prefix) if arguments.cwd_prefix else None
    sessions = [
        session
        for path in sorted(session_dir.rglob("*.jsonl"))
        if (session := read_session_info(path)) is not None
        and matches_session(session, exact_cwd, cwd_prefix, arguments.name or (), arguments.text or ())
    ]
    timestamp = (lambda session: session.timestamp) if arguments.sort == "created" else (lambda session: session.modified)
    # Stable sorts keep canonical paths and IDs ascending when timestamps tie.
    sessions.sort(key=lambda session: (str(session.path.resolve()), session.session_id))
    sessions.sort(key=timestamp, reverse=True)
    return paginated_output(
        (json_session(session) if arguments.format == "jsonl" else text_session(session) for session in sessions[arguments.offset : arguments.offset + arguments.limit]),
        "\n" if arguments.format == "jsonl" else "\n\n",
        arguments.format,
        arguments.offset,
        arguments.limit,
        max(0, len(sessions) - arguments.offset),
    )


def resolve_session(session_ref: str, session_dir: Path) -> Path:
    """Resolve one absolute path, ID alias, or validated filename alias."""

    reference_path = Path(session_ref).expanduser()
    if reference_path.is_absolute():
        if reference_path.suffix != ".jsonl":
            raise QueryError(f"Session path must be a JSONL file: {reference_path}")
        if not reference_path.is_file():
            raise QueryError(f"Session file not found: {reference_path}")
        return reference_path.resolve()

    if not session_ref:
        raise QueryError("Session reference must not be empty")
    if not session_dir.is_dir():
        raise QueryError(f"Session directory not found: {session_dir}")

    candidates = [
        session
        for path in sorted(session_dir.rglob("*.jsonl"))
        if (session := read_session_info(path)) is not None
    ]
    identifiers = [session for session in candidates if session.session_id.startswith(session_ref)]
    exact = [session for session in identifiers if session.session_id == session_ref]
    aliases = [session for session in candidates if matches_filename_alias(session, session_ref)]
    selected = exact or identifiers or aliases

    if not selected:
        raise QueryError(f"Session reference not found: {session_ref}")
    if len(selected) == 1:
        return selected[0].path.resolve()

    details = "\n".join(
        f"  {candidate.session_id} {candidate.timestamp} {candidate.cwd} {candidate.path}"
        for candidate in selected
    )
    raise QueryError(f"Ambiguous session reference '{session_ref}':\n{details}")


def matches_session(
    session: SessionInfo,
    exact_cwd: str | None,
    cwd_prefix: str | None,
    names: Sequence[str],
    texts: Sequence[str],
) -> bool:
    """Return whether one session satisfies every supplied list filter."""

    cwd = canonical_path(session.cwd) if session.cwd else ""
    if exact_cwd is not None and cwd != exact_cwd:
        return False
    if cwd_prefix is not None:
        try:
            Path(cwd).relative_to(cwd_prefix)
        except ValueError:
            return False

    name = session.name.casefold()
    if any(filter_text.casefold() not in name for filter_text in names):
        return False
    searchable_text = session.searchable_text.casefold()
    return all(filter_text.casefold() in searchable_text for filter_text in texts)


def text_session(session: SessionInfo) -> str:
    """Render selectable session metadata in the default text format."""

    return "\n".join(
        (
            f"id: {session_text(session.session_id)}",
            f"path: {session_text(str(session.path))}",
            f"cwd: {session_text(session.cwd)}",
            f"created: {session_text(session.timestamp)}",
            f"modified: {session_text(session.modified)}",
            f"name: {session_text(session.name)}",
            f"message_count: {session.message_count}",
            f"first_message: {session_text(session.first_message)}",
        )
    )


def json_session(session: SessionInfo) -> str:
    """Render selectable session metadata as a compact JSONL object."""

    return json.dumps(
        {
            "id": session_text(session.session_id),
            "path": session_text(str(session.path)),
            "cwd": session_text(session.cwd),
            "created": session_text(session.timestamp),
            "modified": session_text(session.modified),
            "name": session_text(session.name),
            "message_count": session.message_count,
            "first_message": session_text(session.first_message),
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )


def matches_filename_alias(session: SessionInfo, reference: str) -> bool:
    """Match full stems or tails only when the filename repeats the header ID."""

    stem = session.path.stem
    validated = stem.endswith(f"_{session.session_id}")
    return validated and (reference == stem or (reference.endswith(f"_{session.session_id}") and stem.endswith(reference)))


def canonical_path(value: str) -> str:
    """Return the canonical form used by Pi to compare working directories."""

    return str(Path(value).expanduser().resolve())


def pi_timestamp(value: object, path: Path) -> str:
    """Return Pi's activity timestamp fallback sequence as a sortable ISO value."""

    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return datetime.fromtimestamp(value / 1_000, timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
    if isinstance(value, str):
        try:
            datetime.fromisoformat(value.replace("Z", "+00:00"))
            return value
        except ValueError:
            pass
    return datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def text_content(content: object) -> str:
    """Extract visible text from Pi string or text-block content."""

    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""

    texts = [
        block["text"]
        for block in content
        if isinstance(block, dict) and block.get("type") == "text" and isinstance(block.get("text"), str)
    ]
    return "\n".join(texts)


def bounded_value(value: object, budget: list[int], depth: int = 0) -> object:
    """Copy one persisted JSON value into a bounded, JSON-safe forensic field.

    The shared budget is consumed as the value is copied, so arbitrarily large tool
    arguments cannot exceed the per-record payload limit. Nesting is separately capped
    because list levels consume very little of that budget.
    """

    if depth >= MAX_PAYLOAD_DEPTH:
        budget[0] -= 8
        return "…deeper"

    if value is None or isinstance(value, bool):
        budget[0] -= 4
        return value

    if isinstance(value, (int, float)):
        budget[0] -= 8
        return value

    if isinstance(value, str):
        allowed = max(0, min(len(value), budget[0] - 2))
        budget[0] -= allowed + 2
        if allowed >= len(value):
            return value
        return f"{value[: max(0, allowed - 1)]}…"

    if isinstance(value, list):
        budget[0] -= 2
        bounded = [
            bounded_value(item, budget, depth + 1) for item in value[:MAX_PAYLOAD_ITEMS] if budget[0] > 0
        ]
        if len(bounded) < len(value):
            bounded.append(f"…{len(value) - len(bounded)} more items")
        return bounded

    if isinstance(value, dict):
        budget[0] -= 2
        bounded_fields: dict[str, object] = {}
        for key, item in value.items():
            if len(bounded_fields) >= MAX_PAYLOAD_KEYS or budget[0] <= 0:
                break
            name = str(key)
            budget[0] -= len(name) + 3
            bounded_fields[name] = bounded_value(item, budget, depth + 1)
        if len(bounded_fields) < len(value):
            bounded_fields["…more"] = f"{len(value) - len(bounded_fields)} more keys"
        return bounded_fields

    budget[0] -= 8
    return f"<{type(value).__name__}>"

def payload_value(value: object) -> object:
    """Return one bounded JSON-safe copy of a persisted payload value."""

    return bounded_value(value, [MAX_PAYLOAD_CHARS])


def usage_payload(usage: object) -> dict[str, object]:
    """Return the bounded token and cost totals of one persisted usage object."""

    if not isinstance(usage, dict):
        return {}

    payload: dict[str, object] = {}
    for field in ("input", "output", "cacheRead", "cacheWrite", "totalTokens"):
        value = usage.get(field)
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            payload[field] = value

    cost = usage.get("cost")
    if isinstance(cost, dict):
        total = cost.get("total")
        if isinstance(total, (int, float)) and not isinstance(total, bool):
            payload["costTotal"] = total

    return payload


def content_images(content: object) -> int:
    """Count image blocks without exposing their base64 payloads."""

    if not isinstance(content, list):
        return 0
    return sum(1 for block in content if isinstance(block, dict) and block.get("type") == "image")


def entry_payload(entry: dict[str, object]) -> dict[str, object]:
    """Return the entry-level forensic fields shared by every record of one entry."""

    payload: dict[str, object] = {}
    entry_type = entry.get("type")
    if isinstance(entry_type, str):
        payload["entryType"] = session_text(entry_type)
    parent_id = entry.get("parentId")
    if isinstance(parent_id, str) and parent_id:
        payload["parentId"] = session_text(parent_id)
    return payload


def assistant_payload(message: dict[str, object]) -> dict[str, object]:
    """Return the bounded model, stop, and usage metadata of one assistant message."""

    payload: dict[str, object] = {}
    for field in ("model", "provider", "api", "stopReason"):
        value = message.get(field)
        if isinstance(value, str) and value:
            payload[field] = truncate_text(value, MAX_SESSION_FIELD_CHARS)

    error = message.get("errorMessage")
    if isinstance(error, str) and error:
        payload["errorMessage"] = truncate_text(error, MAX_SESSION_FIELD_CHARS)

    usage = usage_payload(message.get("usage"))
    if usage:
        payload["usage"] = usage
    return payload


def bash_payload(source: dict[str, object]) -> dict[str, object]:
    """Return the bounded completion fields of one persisted bash execution."""

    payload: dict[str, object] = {}
    exit_code = source.get("exitCode")
    if isinstance(exit_code, (int, float)) and not isinstance(exit_code, bool):
        payload["exitCode"] = exit_code
    for field in ("cancelled", "truncated"):
        value = source.get(field)
        if isinstance(value, bool):
            payload[field] = value
    full_output = source.get("fullOutputPath")
    if isinstance(full_output, str) and full_output:
        payload["fullOutputPath"] = truncate_text(full_output, MAX_SESSION_FIELD_CHARS)
    return payload


def build_record(
    ordinal: int,
    entry: dict[str, object],
    line: int,
    kind: str,
    text: str,
    tool_name: str | None = None,
    payload: dict[str, object] | None = None,
) -> Record:
    """Create a normalized searchable record from one persisted entry block."""

    entry_id = entry.get("id")
    timestamp = entry.get("timestamp")
    return Record(
        ordinal=ordinal,
        entry_id=entry_id if isinstance(entry_id, str) else f"line-{line}",
        line=line,
        timestamp=timestamp if isinstance(timestamp, str) else "",
        kind=kind,
        tool_name=tool_name,
        text=text,
        payload=payload or {},
    )


def records_for_entry(entry: dict[str, object], line: int, ordinal: int) -> Iterator[Record]:
    """Normalize all independently searchable records represented by one Pi entry."""

    entry_type = entry.get("type")
    base = entry_payload(entry)

    if entry_type == "message":
        message = entry.get("message")
        if not isinstance(message, dict):
            return

        role = message.get("role")
        if role == "user":
            text = text_content(message.get("content"))
            payload = {"role": "user", **base}
            images = content_images(message.get("content"))
            if images:
                payload["images"] = images
            if text:
                yield build_record(ordinal, entry, line, "user", text, payload=payload)
            return

        if role == "assistant":
            payload = {"role": "assistant", **base, **assistant_payload(message)}
            content = message.get("content")
            if not isinstance(content, list):
                text = text_content(content)
                if text:
                    yield build_record(ordinal, entry, line, "assistant-text", text, payload=payload)
                return

            for block in content:
                if not isinstance(block, dict):
                    continue
                block_type = block.get("type")
                if block_type == "text" and isinstance(block.get("text"), str):
                    yield build_record(ordinal, entry, line, "assistant-text", block["text"], payload=payload)
                    ordinal += 1
                elif block_type == "thinking" and isinstance(block.get("thinking"), str):
                    # Thinking signatures stay out of every normalized record.
                    yield build_record(ordinal, entry, line, "thinking", block["thinking"], payload=payload)
                    ordinal += 1
                elif block_type == "toolCall":
                    name = block.get("name")
                    tool_name = name if isinstance(name, str) else ""
                    arguments = block.get("arguments")
                    serialized_arguments = json.dumps(
                        arguments if arguments is not None else {},
                        ensure_ascii=False,
                        sort_keys=True,
                        separators=(",", ":"),
                    )
                    call_payload = dict(payload)
                    call_id = block.get("id")
                    if isinstance(call_id, str) and call_id:
                        call_payload["toolCallId"] = session_text(call_id)
                    call_payload["arguments"] = payload_value(arguments)
                    yield build_record(
                        ordinal,
                        entry,
                        line,
                        "assistant-tool-call",
                        f"{tool_name} {serialized_arguments}",
                        tool_name or None,
                        call_payload,
                    )
                    ordinal += 1
            return

        if role == "toolResult":
            text = text_content(message.get("content"))
            tool_name = message.get("toolName")
            payload = {"role": "toolResult", **base}
            call_id = message.get("toolCallId")
            if isinstance(call_id, str) and call_id:
                payload["toolCallId"] = session_text(call_id)
            is_error = message.get("isError")
            if isinstance(is_error, bool):
                payload["isError"] = is_error
            images = content_images(message.get("content"))
            if images:
                payload["images"] = images
            usage = usage_payload(message.get("usage"))
            if usage:
                payload["usage"] = usage
            if text:
                yield build_record(
                    ordinal,
                    entry,
                    line,
                    "tool-result",
                    text,
                    tool_name if isinstance(tool_name, str) else None,
                    payload,
                )
            return

        if role == "bashExecution":
            payload = {"role": "bashExecution", **base, **bash_payload(message)}
            parts = [part for part in (message.get("command"), message.get("output")) if isinstance(part, str) and part]
            if parts:
                yield build_record(ordinal, entry, line, "bash", "\n".join(parts), "bash", payload)
            return

    if entry_type == "bashExecution":
        parts = [part for part in (entry.get("command"), entry.get("output")) if isinstance(part, str) and part]
        if parts:
            yield build_record(ordinal, entry, line, "bash", "\n".join(parts), "bash", {**base, **bash_payload(entry)})
        return

    summaries = {
        "compaction": "compaction-summary",
        "branch_summary": "branch-summary",
    }
    if entry_type in summaries:
        summary = entry.get("summary")
        if isinstance(summary, str) and summary:
            yield build_record(ordinal, entry, line, summaries[entry_type], summary, payload=base)
        return

    if entry_type == "custom_message":
        text = text_content(entry.get("content"))
        if text:
            yield build_record(ordinal, entry, line, "custom-message", text, payload=base)


def iter_entries(path: Path) -> Iterator[tuple[int, dict[str, object]]]:
    """Stream validated persisted entries with their source line numbers."""

    saw_header = False
    try:
        session_file = path.open("rb")
    except OSError as error:
        raise QueryError(f"Could not read session file {path}: {error}") from error

    with session_file:
        for line_number, raw_bytes in enumerate(session_file, start=1):
            if not raw_bytes.strip():
                continue
            try:
                raw_line = raw_bytes.decode("utf-8")
            except UnicodeDecodeError as error:
                raise QueryError(f"Invalid UTF-8 on line {line_number} in {path}: {error}") from error
            try:
                entry = json.loads(raw_line)
            except json.JSONDecodeError as error:
                raise QueryError(f"Invalid JSON on line {line_number} in {path}: {error.msg}") from error
            except RecursionError as error:
                raise QueryError(f"JSON nesting too deep on line {line_number} in {path}") from error

            if not isinstance(entry, dict):
                raise QueryError(f"Expected a JSON object on line {line_number} in {path}")

            if not saw_header:
                if entry.get("type") != "session" or not isinstance(entry.get("id"), str):
                    raise QueryError(f"Invalid Pi session header on line {line_number} in {path}")
                saw_header = True
                continue

            yield line_number, entry

    if not saw_header:
        raise QueryError(f"Session file is empty: {path}")


def iter_records(path: Path) -> Iterator[Record]:
    """Stream a Pi transcript and yield normalized records in persisted order."""

    ordinal = 0
    for line_number, entry in iter_entries(path):
        for record in records_for_entry(entry, line_number, ordinal):
            yield record
            ordinal += 1


def selected_kinds(arguments: argparse.Namespace) -> frozenset[str]:
    """Return the kinds enabled by the query flags and default conversation view."""

    kinds = set(arguments.kind or DEFAULT_KINDS)
    if arguments.exclude_tools:
        kinds.difference_update(TOOL_KINDS)
    return frozenset(kinds)


def compile_patterns(patterns: Sequence[str] | None) -> tuple[re.Pattern[str], ...]:
    """Compile explicit regular expressions before streaming the transcript."""

    compiled = []
    for pattern in patterns or ():
        try:
            compiled.append(re.compile(pattern))
        except re.error as error:
            raise QueryError(f"Invalid regular expression '{pattern}': {error}") from error
    return tuple(compiled)


def matches_record(
    record: Record,
    kinds: frozenset[str],
    tools: frozenset[str],
    literals: Sequence[str],
    patterns: Sequence[re.Pattern[str]],
) -> bool:
    """Return whether one selected record satisfies every requested text filter."""

    if record.kind not in kinds:
        return False
    if tools and record.tool_name not in tools:
        return False

    casefolded_text = record.text.casefold()
    if any(literal.casefold() not in casefolded_text for literal in literals):
        return False
    return all(pattern.search(record.text) for pattern in patterns)


def select_records(records: Iterable[Record], arguments: argparse.Namespace, limit: int) -> RecordSelection:
    """Select one primary-match page with bounded before/after transcript context."""

    kinds = selected_kinds(arguments)
    tools = frozenset(arguments.tool or ())
    literals = tuple(arguments.match or ())
    patterns = compile_patterns(arguments.regex)
    history: deque[Record] = deque(maxlen=arguments.before)
    selected: dict[int, Record] = {}
    skipped = 0
    match_count = 0
    after_remaining = 0
    has_more = False

    for record in records:
        if record.kind not in kinds:
            continue

        if after_remaining:
            selected[record.ordinal] = record
            after_remaining -= 1

        if matches_record(record, kinds, tools, literals, patterns):
            if skipped < arguments.offset:
                skipped += 1
            elif match_count < limit:
                for previous in history:
                    selected[previous.ordinal] = previous
                selected[record.ordinal] = record
                match_count += 1
                after_remaining = max(after_remaining, arguments.after)
            else:
                has_more = True
                if not after_remaining:
                    return RecordSelection(
                        [selected[ordinal] for ordinal in sorted(selected)],
                        match_count,
                        True,
                    )

        history.append(record)

        if has_more and not after_remaining:
            return RecordSelection(
                [selected[ordinal] for ordinal in sorted(selected)],
                match_count,
                True,
            )

    return RecordSelection(
        [selected[ordinal] for ordinal in sorted(selected)],
        match_count,
        has_more,
    )


def session_text(text: str) -> str:
    """Bound one session-list field without affecting filtering or sorting.

    Rendering preserves every metadata field while keeping each value within the page budget.
    """

    return truncate_text(text, MAX_SESSION_FIELD_CHARS)


def truncate_text(text: str, maximum: int) -> str:
    """Truncate one rendered record without changing the text used for matching."""

    if len(text) <= maximum:
        return text
    return f"{text[: maximum - 1]}…"


def text_record(record: Record, maximum: int) -> str:
    """Render one attributable record in the default agent-readable text format."""

    details = [
        f"entry: {record.entry_id}",
        f"line: {record.line}",
        f"timestamp: {record.timestamp}",
        f"kind: {record.kind}",
    ]
    if record.tool_name:
        details.append(f"tool: {record.tool_name}")
    return f"[{' | '.join(details)}]\n{truncate_text(record.text, maximum)}"


def json_record(record: Record, maximum: int, include_payload: bool = False) -> str:
    """Render one normalized record as a compact JSONL object."""

    document: dict[str, object] = {
        "entry_id": record.entry_id,
        "line": record.line,
        "timestamp": record.timestamp,
        "kind": record.kind,
        "tool_name": record.tool_name,
        "text": truncate_text(record.text, maximum),
    }
    if include_payload:
        document.update(record.payload)
    return json.dumps(document, ensure_ascii=False, separators=(",", ":"))


def page_chunk(page: Page, format_name: str) -> str:
    """Render reserved page metadata before every list or query result page."""

    if format_name == "jsonl":
        return json.dumps(
            {"type": "page", "offset": page.offset, "limit": page.limit, "returned": page.returned,
             "next_offset": page.next_offset, "has_more": page.has_more},
            separators=(",", ":"),
        )
    next_offset = page.next_offset if page.next_offset is not None else "null"
    return f"[page | offset: {page.offset} | limit: {page.limit} | returned: {page.returned} | next_offset: {next_offset} | has_more: {str(page.has_more).lower()}]"


def paginated_output(
    chunks: Iterable[str],
    separator: str,
    format_name: str,
    offset: int,
    limit: int,
    available: int,
) -> str:
    """Render the largest complete primary-result prefix within the output budget."""

    candidates = list(chunks)
    # Session-list fields are individually capped, so one candidate always fits the page budget.
    maximum = min(len(candidates), available)
    for returned in range(maximum, -1, -1):
        has_more = available > returned
        page = Page(offset, limit, returned, offset + returned if has_more else None, has_more)
        output = separator.join((page_chunk(page, format_name), *candidates[:returned]))
        if len(output) <= MAX_OUTPUT_CHARS:
            return output
    raise AssertionError("page metadata exceeds the output budget")


def bounded_counts(counts: dict[str, int]) -> dict[str, int]:
    """Return the most frequent counts, folding rare names into one bounded bucket."""

    ordered = sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    if len(ordered) <= MAX_COUNT_KEYS:
        return dict(ordered)
    head = ordered[:MAX_COUNT_KEYS]
    return {**dict(head), "…other": sum(count for _, count in ordered[MAX_COUNT_KEYS:])}


def scan_session(path: Path, entry_id: str | None) -> tuple[SessionScan, EntryDetail | None]:
    """Collect bounded forensic statistics from one session transcript.

    Requested entry detail is collected during the same single pass, so inspection never
    re-reads or dumps the whole transcript.
    """

    header = read_session_header(path)
    if header is None:
        raise QueryError(f"Invalid Pi session header in {path}")

    entry_types: dict[str, int] = {}
    record_kinds: dict[str, int] = {}
    tool_calls: dict[str, int] = {}
    models: dict[str, int] = {}
    providers: dict[str, int] = {}
    tool_errors = 0
    entries = 0
    last_line = 0
    first_activity = ""
    last_activity = ""
    name = ""
    detail: EntryDetail | None = None
    detail_lines: list[int] = []
    ordinal = 0

    for line_number, entry in iter_entries(path):
        last_line = line_number
        entry_type = entry.get("type")
        if isinstance(entry_type, str):
            entry_types[entry_type] = entry_types.get(entry_type, 0) + 1
        if entry_type == "session_info":
            candidate_name = entry.get("name")
            name = candidate_name.strip() if isinstance(candidate_name, str) else ""
            continue

        entries += 1
        timestamp = entry.get("timestamp")
        if isinstance(timestamp, str) and timestamp:
            first_activity = first_activity or timestamp
            last_activity = timestamp

        message = entry.get("message") if entry_type == "message" else None
        if isinstance(message, dict):
            model = message.get("model")
            if isinstance(model, str) and model:
                models[model] = models.get(model, 0) + 1
            provider = message.get("provider")
            if isinstance(provider, str) and provider:
                providers[provider] = providers.get(provider, 0) + 1
            # Error state is counted from the entry so image-only results are not lost.
            if message.get("role") == "toolResult" and message.get("isError") is True:
                tool_errors += 1

        entry_records: list[Record] = []
        for record in records_for_entry(entry, line_number, ordinal):
            ordinal += 1
            record_kinds[record.kind] = record_kinds.get(record.kind, 0) + 1
            if record.kind == "assistant-tool-call" and record.tool_name:
                tool_calls[record.tool_name] = tool_calls.get(record.tool_name, 0) + 1
            entry_records.append(record)

        if entry_id is None:
            continue
        candidate_id = entry.get("id")
        if not isinstance(candidate_id, str) or candidate_id != entry_id:
            continue
        detail_lines.append(line_number)
        parent_id = entry.get("parentId")
        role = message.get("role") if isinstance(message, dict) else None
        detail = EntryDetail(
            entry_id=candidate_id,
            line=line_number,
            entry_type=entry_type if isinstance(entry_type, str) else "",
            parent_id=parent_id if isinstance(parent_id, str) else "",
            role=role if isinstance(role, str) else "",
            timestamp=timestamp if isinstance(timestamp, str) else "",
            records=entry_records,
        )

    if entry_id is not None:
        if not detail_lines:
            raise QueryError(f"Entry ID not found: {entry_id}")
        if len(detail_lines) > 1:
            listed = ", ".join(str(line_number) for line_number in detail_lines)
            raise QueryError(f"Duplicate entry ID '{entry_id}' at lines {listed}")

    created = header.get("timestamp")
    parent_session = header.get("parentSession")
    return (
        SessionScan(
            path=path,
            session_id=str(header["id"]),
            version=str(header.get("version", "")),
            cwd=header.get("cwd") if isinstance(header.get("cwd"), str) else "",
            name=name,
            created=pi_timestamp(created, path),
            parent_session=parent_session if isinstance(parent_session, str) else "",
            first_activity=first_activity,
            last_activity=last_activity,
            entries=entries,
            last_line=last_line,
            entry_types=entry_types,
            record_kinds=record_kinds,
            tool_calls=tool_calls,
            tool_errors=tool_errors,
            models=models,
            providers=providers,
        ),
        detail,
    )


def related_sessions(session_dir: Path, scan: SessionScan) -> RelatedSessions:
    """Find the recorded parent link and children stored under one session directory."""

    parent_id = ""
    if scan.parent_session:
        parent_header = read_session_header(Path(scan.parent_session).expanduser())
        if parent_header is not None:
            candidate_id = parent_header.get("id")
            parent_id = candidate_id if isinstance(candidate_id, str) else ""

    selected = canonical_path(str(scan.path))
    children: list[RelatedSession] = []
    if session_dir.is_dir():
        for candidate in sorted(session_dir.rglob("*.jsonl")):
            header = read_session_header(candidate)
            if header is None:
                continue
            linked = header.get("parentSession")
            if not isinstance(linked, str) or not linked:
                continue
            if canonical_path(linked) != selected or canonical_path(str(candidate)) == selected:
                continue
            session_id = header.get("id")
            children.append(
                RelatedSession(
                    session_id=session_id if isinstance(session_id, str) else "",
                    path=candidate,
                    created=pi_timestamp(header.get("timestamp"), candidate),
                )
            )

    children.sort(key=lambda child: (child.created, child.session_id), reverse=True)
    return RelatedSessions(
        parent=scan.parent_session,
        parent_id=parent_id,
        children=children[:MAX_RELATED_SESSIONS],
        truncated=len(children) > MAX_RELATED_SESSIONS,
    )


def text_counts(prefix: str, counts: dict[str, int]) -> list[str]:
    """Render one bounded count mapping as stable, greppable lines."""

    return [f"{prefix}.{name}: {count}" for name, count in bounded_counts(counts).items()]


def text_related(related: RelatedSessions) -> list[str]:
    """Render the recorded parent link and bounded children of one inspected session."""

    lines = [f"parent_session: {session_text(related.parent) if related.parent else '(none)'}"]
    if related.parent_id:
        lines.append(f"parent_session_id: {session_text(related.parent_id)}")
    lines.extend(
        f"child_session: {session_text(child.session_id)} {session_text(child.created)} {session_text(str(child.path))}"
        for child in related.children
    )
    if related.truncated:
        lines.append("children_truncated: true")
    return lines


def text_entry(detail: EntryDetail, maximum: int) -> list[str]:
    """Render one persisted entry with its bounded records and payload fields."""

    lines = [
        f"[entry | id: {session_text(detail.entry_id)} | line: {detail.line} | type: {session_text(detail.entry_type)} "
        f"| parent_id: {session_text(detail.parent_id) or '-'} | role: {session_text(detail.role) or '-'}]"
    ]
    for record in detail.records:
        lines.append(text_record(record, maximum))
        if record.payload:
            lines.append(f"payload: {json.dumps(record.payload, ensure_ascii=False, separators=(',', ':'))}")
    return lines


def text_inspect(
    scan: SessionScan,
    detail: EntryDetail | None,
    related: RelatedSessions | None,
    maximum: int,
) -> str:
    """Render one bounded session summary with optional entry and relationship evidence."""

    lines = [
        f"id: {session_text(scan.session_id)}",
        f"path: {session_text(str(scan.path))}",
        f"version: {session_text(scan.version or 'unknown')}",
        f"cwd: {session_text(scan.cwd)}",
        f"created: {session_text(scan.created)}",
        f"first_activity: {session_text(scan.first_activity)}",
        f"last_activity: {session_text(scan.last_activity)}",
        f"name: {session_text(scan.name)}",
        f"entries: {scan.entries}",
        f"last_line: {scan.last_line}",
        f"tool_errors: {scan.tool_errors}",
    ]
    lines.extend(text_counts("entry_type", scan.entry_types))
    lines.extend(text_counts("record_kind", scan.record_kinds))
    lines.extend(text_counts("tool", scan.tool_calls))
    lines.extend(text_counts("model", scan.models))
    lines.extend(text_counts("provider", scan.providers))
    if related is not None:
        lines.extend(text_related(related))
    if detail is not None:
        lines.extend(text_entry(detail, maximum))
    return "\n".join(lines)


def json_inspect(scan: SessionScan, related: RelatedSessions | None) -> str:
    """Render one session summary as a compact JSONL object."""

    document: dict[str, object] = {
        "type": "inspect",
        "id": session_text(scan.session_id),
        "path": session_text(str(scan.path)),
        "version": session_text(scan.version),
        "cwd": session_text(scan.cwd),
        "created": session_text(scan.created),
        "first_activity": session_text(scan.first_activity),
        "last_activity": session_text(scan.last_activity),
        "name": session_text(scan.name),
        "entries": scan.entries,
        "last_line": scan.last_line,
        "tool_errors": scan.tool_errors,
        "entry_types": bounded_counts(scan.entry_types),
        "record_kinds": bounded_counts(scan.record_kinds),
        "tool_calls": bounded_counts(scan.tool_calls),
        "models": bounded_counts(scan.models),
        "providers": bounded_counts(scan.providers),
    }
    if related is not None:
        document["parent_session"] = session_text(related.parent)
        document["parent_session_id"] = session_text(related.parent_id)
        document["children"] = [
            {
                "id": session_text(child.session_id),
                "created": session_text(child.created),
                "path": session_text(str(child.path)),
            }
            for child in related.children
        ]
        document["children_truncated"] = related.truncated
    return json.dumps(document, ensure_ascii=False, separators=(",", ":"))


def json_entry(detail: EntryDetail, maximum: int) -> str:
    """Render one persisted entry with its bounded records as a compact JSONL object."""

    return json.dumps(
        {
            "type": "entry",
            "entry_id": session_text(detail.entry_id),
            "line": detail.line,
            "entry_type": session_text(detail.entry_type),
            "parent_id": session_text(detail.parent_id),
            "role": session_text(detail.role),
            "timestamp": session_text(detail.timestamp),
            "records": [
                {
                    "kind": record.kind,
                    "tool_name": record.tool_name,
                    "text": truncate_text(record.text, maximum),
                    **record.payload,
                }
                for record in detail.records
            ],
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )


def run_query(arguments: argparse.Namespace) -> str:
    """Resolve, stream, select, and render one read-only transcript query."""

    path = resolve_session(arguments.session_ref, default_session_dir(arguments.session_dir))
    requested = arguments.limit
    separator = "\n" if arguments.format == "jsonl" else "\n\n"
    while True:
        selection = select_records(iter_records(path), arguments, requested)
        if selection.returned == 0 and selection.has_more:
            raise QueryError("Query context exceeds output budget; reduce --before, --after, or --max-chars")
        page = Page(
            arguments.offset,
            arguments.limit,
            selection.returned,
            arguments.offset + selection.returned if selection.has_more else None,
            selection.has_more,
        )
        chunks = (
            (json_record(record, arguments.max_chars, arguments.include_payload) for record in selection.records)
            if arguments.format == "jsonl"
            else (text_record(record, arguments.max_chars) for record in selection.records)
        )
        output = separator.join((page_chunk(page, arguments.format), *chunks))
        if len(output) <= MAX_OUTPUT_CHARS:
            return output
        requested -= 1


def run_inspect(arguments: argparse.Namespace) -> str:
    """Resolve, scan, and render read-only forensic evidence for one session."""

    session_dir = default_session_dir(arguments.session_dir)
    path = resolve_session(arguments.session_ref, session_dir)
    scan, detail = scan_session(path, arguments.entry_id)
    related = related_sessions(session_dir, scan) if arguments.related else None

    if arguments.format == "jsonl":
        documents = [json_inspect(scan, related)]
        if detail is not None:
            documents.append(json_entry(detail, arguments.max_chars))
        output = "\n".join(documents)
    else:
        output = text_inspect(scan, detail, related, arguments.max_chars)

    if len(output) > MAX_OUTPUT_CHARS:
        records = len(detail.records) if detail is not None else 0
        raise QueryError(
            "Inspect output exceeds output budget; reduce --max-chars "
            f"(selected entry has {records} records)"
        )

    return output


def run_stats(arguments: argparse.Namespace) -> str:
    """Aggregate reviewer and sub-agent spawn metrics across persisted sessions."""

    session_dir = default_session_dir(arguments.session_dir)
    if not session_dir.is_dir():
        raise QueryError(f"Session directory not found: {session_dir}")

    since = parse_date_bound(arguments.since, end_of_day=False) if arguments.since else None
    until = parse_date_bound(arguments.until, end_of_day=True) if arguments.until else None
    if since is not None and until is not None and since > until:
        raise QueryError("--since must be before or equal to --until")
    excluded = tuple(canonical_path(value) for value in arguments.exclude_cwd_prefix or ())

    sessions = 0
    top_level_sessions = 0
    subagent_spawns = 0
    reviewer_spawns = 0
    ad_hoc_reviewer_spawns = 0
    markdown_or_plan_review = 0
    reviewer_spawns_by_agent: dict[str, int] = {}
    weekly: dict[str, dict[str, int]] = {}
    workspaces: dict[str, dict[str, int | bool]] = {}

    for path in sorted(session_dir.rglob("*.jsonl")):
        session = read_session_info(path)
        if session is None:
            continue
        cwd = canonical_path(session.cwd) if session.cwd else ""
        if any(path_has_prefix(cwd, prefix) for prefix in excluded):
            continue
        bare_agent_name, separator, agent_hash = session.name.partition("#")
        is_subagent = bool(bare_agent_name and separator and agent_hash)
        is_reviewer = is_subagent and bare_agent_name in REVIEWER_AGENT_NAMES

        created = parse_timestamp(session.timestamp) or parse_timestamp(session.modified)
        if not timestamp_in_window(created, since, until):
            continue

        sessions += 1
        week = iso_week(created)
        week_counts = weekly.setdefault(
            week,
            {"top_level_sessions": 0, "subagent_spawns": 0, "reviewer_spawns": 0},
        )
        workspace = workspaces.setdefault(
            cwd,
            {"top_level_sessions": 0, "reviewer_spawns": 0, "orchestrator_ever": False},
        )

        if is_subagent:
            subagent_spawns += 1
            week_counts["subagent_spawns"] += 1
            if is_reviewer:
                reviewer_spawns += 1
                week_counts["reviewer_spawns"] += 1
                workspace["reviewer_spawns"] += 1
                reviewer_spawns_by_agent[bare_agent_name] = reviewer_spawns_by_agent.get(bare_agent_name, 0) + 1
                if arguments.classify_targets and not session.first_message.startswith("<system-reminder>"):
                    ad_hoc_reviewer_spawns += 1
                    if MARKDOWN_OR_PLAN_PATTERN.search(session.first_message):
                        markdown_or_plan_review += 1
        else:
            top_level_sessions += 1
            week_counts["top_level_sessions"] += 1
            workspace["top_level_sessions"] += 1
            if transcript_has_mode(path, "orchestrator"):
                workspace["orchestrator_ever"] = True

    for week_counts in weekly.values():
        week_counts["reviewer_spawns_per_top_level_session"] = safe_ratio(
            week_counts["reviewer_spawns"],
            week_counts["top_level_sessions"],
        )

    cohort = orchestrator_cohort(workspaces)
    document: dict[str, object] = {
        "type": "stats",
        "window": {"since": arguments.since, "until": arguments.until},
        "excluded_cwd_prefixes": list(excluded),
        "sessions": sessions,
        "top_level_sessions": top_level_sessions,
        "subagent_spawns": subagent_spawns,
        "reviewer_spawns": reviewer_spawns,
        "reviewer_spawns_by_agent": dict(sorted(reviewer_spawns_by_agent.items())),
        "reviewer_spawns_per_top_level_session": safe_ratio(reviewer_spawns, top_level_sessions),
        "reviewer_share_percent": safe_ratio(reviewer_spawns * 100, subagent_spawns, digits=2),
        "orchestrator_cohort": cohort,
        "weekly": dict(sorted(weekly.items())),
    }
    if arguments.classify_targets:
        document["target_classification"] = {
            "ad_hoc_reviewer_spawns": ad_hoc_reviewer_spawns,
            "markdown_or_plan_review": markdown_or_plan_review,
        }

    return json.dumps(document, ensure_ascii=False, separators=(",", ":")) if arguments.format == "jsonl" else text_stats(document)


def parse_date_bound(value: str, end_of_day: bool) -> datetime:
    """Parse one inclusive command-line date bound as an aware UTC datetime."""

    raw = value.strip()
    try:
        parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError as error:
        raise QueryError(f"Invalid date '{value}'; expected YYYY-MM-DD or ISO 8601") from error
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    if end_of_day and len(raw) == 10:
        parsed = parsed.replace(hour=23, minute=59, second=59, microsecond=999999)
    return parsed.astimezone(timezone.utc)


def parse_timestamp(value: str) -> datetime | None:
    """Parse one persisted ISO timestamp as an aware UTC datetime."""

    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def timestamp_in_window(created: datetime | None, since: datetime | None, until: datetime | None) -> bool:
    """Return whether a timestamp falls inside the requested inclusive window."""

    if created is None:
        return since is None and until is None
    return (since is None or created >= since) and (until is None or created <= until)


def path_has_prefix(path: str, prefix: str) -> bool:
    """Return whether one canonical path equals or descends from another."""

    try:
        Path(path).relative_to(prefix)
    except ValueError:
        return False
    return True


def iso_week(created: datetime | None) -> str:
    """Return a stable ISO year-week label for a persisted timestamp."""

    if created is None:
        return "unknown"
    year, week, _ = created.isocalendar()
    return f"{year}-W{week:02d}"


def transcript_has_mode(path: Path, mode: str) -> bool:
    """Detect one persisted Pi mode-switch entry in a transcript."""

    try:
        for _, entry in iter_entries(path):
            data = entry.get("data")
            if (
                entry.get("type") == "custom"
                and entry.get("customType") == "mode-switch"
                and isinstance(data, dict)
                and data.get("mode") == mode
            ):
                return True
    except QueryError:
        return False
    return False


def orchestrator_cohort(workspaces: dict[str, dict[str, int | bool]]) -> dict[str, object]:
    """Compare reviewer spawn rates for orchestrator-ever and never workspaces."""

    cohorts = {
        "orchestrator_ever": {"top_level_sessions": 0, "reviewer_spawns": 0},
        "never": {"top_level_sessions": 0, "reviewer_spawns": 0},
    }
    for workspace in workspaces.values():
        if not workspace["top_level_sessions"]:
            continue
        name = "orchestrator_ever" if workspace["orchestrator_ever"] else "never"
        cohorts[name]["top_level_sessions"] += int(workspace["top_level_sessions"])
        cohorts[name]["reviewer_spawns"] += int(workspace["reviewer_spawns"])

    for values in cohorts.values():
        values["spawns_per_session"] = safe_ratio(values["reviewer_spawns"], values["top_level_sessions"])
    orchestrator_rate = cohorts["orchestrator_ever"]["spawns_per_session"]
    never_rate = cohorts["never"]["spawns_per_session"]
    return {
        **cohorts,
        "rate_ratio": safe_ratio(orchestrator_rate, never_rate) if orchestrator_rate is not None and never_rate is not None else None,
    }


def safe_ratio(numerator: int | float, denominator: int | float, digits: int = 3) -> float | None:
    """Return one rounded ratio, or None when its denominator is zero."""

    return round(numerator / denominator, digits) if denominator else None


def text_stats(document: dict[str, object]) -> str:
    """Render one corpus-wide statistics document as readable text."""

    lines = [
        f"sessions: {document['sessions']}",
        f"top_level_sessions: {document['top_level_sessions']}",
        f"subagent_spawns: {document['subagent_spawns']}",
        f"reviewer_spawns: {document['reviewer_spawns']}",
        f"reviewer_spawns_per_top_level_session: {document['reviewer_spawns_per_top_level_session']}",
        f"reviewer_share_percent: {document['reviewer_share_percent']}",
    ]
    for name, count in document["reviewer_spawns_by_agent"].items():
        lines.append(f"reviewer.{name}: {count}")
    target_classification = document.get("target_classification")
    if isinstance(target_classification, dict):
        lines.append(f"ad_hoc_reviewer_spawns: {target_classification['ad_hoc_reviewer_spawns']}")
        lines.append(f"markdown_or_plan_review: {target_classification['markdown_or_plan_review']}")
    cohort = document["orchestrator_cohort"]
    for name in ("orchestrator_ever", "never"):
        values = cohort[name]
        lines.append(
            f"cohort.{name}: top_level_sessions={values['top_level_sessions']} "
            f"reviewer_spawns={values['reviewer_spawns']} spawns_per_session={values['spawns_per_session']}"
        )
    lines.append(f"cohort.rate_ratio: {cohort['rate_ratio']}")
    for week, values in document["weekly"].items():
        lines.append(
            f"week.{week}: top_level_sessions={values['top_level_sessions']} "
            f"subagent_spawns={values['subagent_spawns']} reviewer_spawns={values['reviewer_spawns']} "
            f"reviewer_spawns_per_top_level_session={values['reviewer_spawns_per_top_level_session']}"
        )
    return "\n".join(lines)


def main(arguments: Sequence[str] | None = None) -> int:
    """Run the command and report actionable failures without a traceback."""

    parser = build_parser()
    parsed = parser.parse_args(arguments)

    try:
        session_dir = default_session_dir(parsed.session_dir)
        if parsed.command == "list":
            output = list_sessions(parsed)
        elif parsed.command == "resolve":
            output = str(resolve_session(parsed.session_ref, session_dir))
        elif parsed.command == "query":
            if parsed.include_payload and parsed.format != "jsonl":
                raise QueryError("--include-payload requires --format jsonl")
            output = run_query(parsed)
        elif parsed.command == "inspect":
            output = run_inspect(parsed)
        else:
            output = run_stats(parsed)
        if output:
            print(output)
    except QueryError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
