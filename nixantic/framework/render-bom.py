import json
import os
import sys

import tiktoken
from tiktoken.load import load_tiktoken_bpe


CATEGORY_ORDER = ["instructions", "agents", "commands", "skills", "skillSubfiles"]
CATEGORY_LABELS = {
    "instructions": "Generated instructions",
    "agents": "Agents",
    "commands": "Commands",
    "skills": "Skills",
    "skillSubfiles": "Skill subfiles",
}

CL100K_BASE_PAT_STR = (
    r"'(?i:[sdmt]|ll|ve|re)|[^\r\n\p{L}\p{N}]?+\p{L}++|\p{N}{1,3}+| ?[^\s\p{L}\p{N}]++[\r\n]*+|\s++$|\s*[\r\n]|\s+(?!\S)|\s"
)
CL100K_BASE_SPECIAL_TOKENS = {
    "<|endoftext|>": 100257,
    "<|fim_prefix|>": 100258,
    "<|fim_middle|>": 100259,
    "<|fim_suffix|>": 100260,
    "<|endofprompt|>": 100276,
}


def escape_cell(value):
    return str(value).replace("|", "\\|").replace("\n", " ")


def count_tokens(encoding, content):
    return len(encoding.encode(content))


def load_encoding(encoding_name, encoding_path, encoding_hash):
    if encoding_name != "cl100k_base":
        raise ValueError(
            f"Unsupported BOM encoding {encoding_name!r}: only the vendored 'cl100k_base' path is implemented"
        )
    if not os.path.isfile(encoding_path):
        raise FileNotFoundError(
            f"Missing local tiktoken encoding asset for BOM generation: {encoding_path}"
        )

    try:
        mergeable_ranks = load_tiktoken_bpe(encoding_path, expected_hash=encoding_hash)
    except Exception as exc:
        raise ValueError(
            f"Failed to load vendored tiktoken encoding asset for BOM generation: {encoding_path}"
        ) from exc

    return tiktoken.Encoding(
        name=encoding_name,
        pat_str=CL100K_BASE_PAT_STR,
        mergeable_ranks=mergeable_ranks,
        special_tokens=CL100K_BASE_SPECIAL_TOKENS,
    )


def table(headers, rows):
    lines = ["| " + " | ".join(headers) + " |", "| " + " | ".join(["---"] * len(headers)) + " |"]
    lines.extend("| " + " | ".join(escape_cell(cell) for cell in row) + " |" for row in rows)
    return "\n".join(lines)


def main():
    manifest_path, output_path = sys.argv[1:3]
    with open(manifest_path, encoding="utf-8") as manifest_file:
        manifest = json.load(manifest_file)

    encoding_name = manifest["encoding"]
    encoding = load_encoding(encoding_name, manifest["encodingPath"], manifest["encodingHash"])
    entries = sorted(manifest["entries"], key=lambda entry: entry["relativePath"])
    counted = [entry | {"tokens": count_tokens(encoding, entry["content"])} for entry in entries]

    total_tokens = sum(entry["tokens"] for entry in counted)
    category_rows = []
    for category in CATEGORY_ORDER:
        category_entries = [entry for entry in counted if entry["category"] == category]
        category_rows.append(
            [CATEGORY_LABELS[category], len(category_entries), sum(entry["tokens"] for entry in category_entries)]
        )

    file_rows = [
        [CATEGORY_LABELS[entry["category"]], entry["relativePath"], entry["tokens"]]
        for entry in counted
    ]
    root_rows = [
        [entry["relativePath"], entry["tokens"]]
        for entry in counted
        if entry["category"] == "instructions" and "/" not in entry["relativePath"]
    ]
    command_rows = [
        [entry["relativePath"], entry["tokens"]]
        for entry in counted
        if entry["category"] == "commands"
    ]

    sections = [
        f"# Instruction BOM: {manifest['harness']}",
        (
            f"Estimated token counts using tiktoken encoding `{encoding_name}`. "
            "These counts are planning estimates, not provider-authoritative context billing."
        ),
        "## Harness total",
        table(["Files", "Estimated tokens"], [[len(counted), total_tokens]]),
        "## Category totals",
        table(["Category", "Files", "Estimated tokens"], category_rows),
        "## Per-file rows",
        table(["Category", "File", "Estimated tokens"], file_rows) if file_rows else "_No generated instruction files._",
        "## Root/main instruction summary",
        table(["File", "Estimated tokens"], root_rows) if root_rows else "_No root/main instruction files._",
        "## Per-command file-cost",
        table(["Command file", "Estimated tokens"], command_rows) if command_rows else "_No command files._",
    ]

    with open(output_path, "w", encoding="utf-8") as output_file:
        output_file.write("\n\n".join(sections) + "\n")


if __name__ == "__main__":
    main()
