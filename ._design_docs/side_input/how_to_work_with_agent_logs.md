# Working with Copilot agent logs

This guide shows how to extract information from GitHub Copilot's per-session logs to feed three views: the **Cache Explorer** (token and prompt usage), the **Agent Flow Chart** (which agent called which subagent), and the **Logs** view (the event timeline with tool calls, results, and errors).

It applies to **any** chat session in **any** repository. The canonical log sources live under VS Code's user-data folder, described in section 1. The two analysis scripts are independent, self-contained Python programs reproduced in full in section 2; save them to any folder and point them at the right source data:

- `analyze_chat_logs.py` consumes the chat-widget state dump (the `kind:0/1/2` format) and produces token and call-count tables.
- `extract-invocations-from-transcript.py` consumes the transcript event stream, cross-references the chat-widget dump, and reconstructs subagent invocations with their prompts, reasoning, and tool calls.

## 1. Where the logs live

Logs are namespaced by workspace under VS Code's user-data folder:

```text
<user-data>/User/workspaceStorage/<workspaceHash>/GitHub.copilot-chat/
```

`<user-data>` is your VS Code data root (`%APPDATA%\Code` by default on Windows, `~/Library/Application Support/Code` on macOS, `~/.config/Code` on Linux). Replace `<workspaceHash>` with the 32-character hex folder matching the target workspace. The `.copilot-chat` subfolder holds four kinds of data, each with a distinct shape and use. Note that on Windows these live under the VS Code process user, not your Windows login profile.

### Debug logs (per-session directory)

Path: `<...>/GitHub.copilot-chat/debug-logs/<sessionId>/`

One directory per session, named by session UUID. A session directory contains:

| File | What it holds |
| --- | --- |
| `main.jsonl` | The primary conversation log. Always read this first. |
| `system_prompt_*.json` | The full, untruncated system prompt, one file per model used. |
| `tools_*.json` | The tool definitions sent to the model, per model. |
| `models.json` | Snapshot of available models with capabilities and limits. |
| `runSubagent-<name>-<uuid>.jsonl` | A subagent's own tool calls and LLM requests. |
| `title-` / `categorize-` / `summarize-<uuid>.jsonl` | UI housekeeping. Rarely relevant. |

`main.jsonl` links to child files through `child_session_ref` entries, so the file tree mirrors the agent tree. Each line in `main.jsonl` is one JSON object with `type`, `name`, `ts`, `dur`, `spanId`, `parentSpanId`, `status`, and `attrs`. Common event types: `session_start`, `user_message`, `llm_request`, `agent_response`, `tool_call`, `subagent`, `discovery`.

### Transcripts (one file per session)

Path: `<...>/GitHub.copilot-chat/transcripts/<sessionId>.jsonl`

A flat directory: one JSONL file per session, named `<sessionId>.jsonl`. Each line is an event with a parent pointer. The root event looks like:

```json
{"type":"session.start","data":{"sessionId":"...","producer":"copilot-agent","copilotVersion":"0.43.0"},"id":"...","timestamp":"...","parentId":null}
```

Top-level fields: `type`, `id`, `parentId`, `timestamp`, `data`. The `parentId` chains events into a tree. Common `type` values: `session.start`, `assistant.message`, `tool.execution_start`, `tool.execution_complete`.

### Chat-session resources

Path: `<...>/GitHub.copilot-chat/chat-session-resources/<sessionId>/`

Per-session attachment storage (attachments, referenced files, `content.txt` blobs). Used to resolve file attachments and tool-resource content tied to a turn. Not a primary source for the three views covered here.

### Chat-widget state dump (the `kind:0/1/2` format)

This is the source `analyze_chat_logs.py` consumes. It is VS Code's serialized chat-widget model: a top-level `version`, `sessionId`, and a `requests[]` array where each request carries `requestId`, `agent`, `modeInfo`, `modelId`, `completionTokens`, and nested `toolInvocationSerialized` entries.

VS Code keeps this state in-memory and in its state store, **not** as a loose `.jsonl` file. To use the script you must export the current chat-widget state to a file first. Two ways:

- From a running extension host, call the chat API and write `chatModel.toJSON()` to disk.
- From outside VS Code, read the global state store at `<user-data>/User/globalStorage/state.vscdb`, key `chat.ChatSessionStore.index` (session registry), and each session's memento blob that mirrors its `requests[]`. The memento blobs are JSON-encoded deltas recognizable by the `kind` field.

Each line of a dump is a delta:

- `kind:0` replaces the whole root with `v`.
- `kind:1` and `kind:2` patch a path (`k`) with a value (`v`). `kind:2` with `k == ["requests"]` appends to the requests list.

A dump is identifiable by the top-level `kind` field on each line; the very first line is usually `kind:0` and contains `version`, `sessionId`, and an empty `requests` array.

### Session history DB (global, readable with SQLite)

Path: `<user-data>/User/globalStorage/github.copilot-chat/session-store.db`

A SQLite database with full-text search indexing every past session. Useful for locating sessions across workspaces without opening the JSONL files. Main tables:

| Table | Contents |
| --- | --- |
| `sessions` | One row per session: `id`, `cwd`, `repository`, `branch`, `summary`, `agent_name`, `created_at`. The `id` matches the `<sessionId>` used in the `transcripts/` and `debug-logs/` paths. |
| `turns` | One row per turn: `session_id`, `turn_index`, `user_message`, `assistant_response`, `timestamp`. |
| `session_files` | Files touched per session: `session_id`, `file_path`, `tool_name`, `turn_index`. |
| `search_index` | FTS5 index over turn content (columns `content`, `session_id`, `source_type`, `source_id`). |

Query example, finding sessions by keyword:

```sql
SELECT s.id, s.agent_name, s.created_at, s.summary
FROM search_index si
JOIN sessions s ON s.id = si.session_id
WHERE search_index MATCH 'resource-req'
GROUP BY s.id
ORDER BY s.created_at DESC;
```

## 2. The two scripts (self-contained, copy-paste ready)

The two scripts below are reproduced in full so you can run them on any machine, against any project's logs, without needing anything from this repository. Save each one to a file (`analyze_chat_logs.py` and `extract-invocations-from-transcript.py`) in any working folder. Both scripts depend only on the Python standard library (`argparse`, `json`, `pathlib`, `dataclasses`, `collections`); no third-party packages are required.

Both scripts take their input directory as an argument. Pass an explicit path each time so you are not relying on their built-in defaults, which point at sibling `transcripts/` and `chat_logs/` subfolders of the script's own location.

### 2a. `analyze_chat_logs.py` (reads chat-widget state dumps)

Pipeline (run against an exported chat-widget dump, see section 1):

1. `iter_jsonl()` reads each line as JSON.
2. `build_final_state()` replays the deltas. `apply_path()` walks list indices and dict keys to apply each patch.
3. `agent_label()` resolves the agent name from `request.modeInfo.modeInstructions.name`, falling back to `agent.fullName`, `agent.id`.
4. `collect_tool_calls()` recurses through the state and pulls out every node with `kind == "toolInvocationSerialized"`.
5. `ingest_subagent_call()` keeps only calls whose `toolSpecificData.kind == "subagent"`, dedupes by `subAgentInvocationId` or `toolCallId`, and accumulates `SubagentStats`.
6. Token counts come from `coerce_int(completionTokens)` on each request. Subagent payloads carry no token counters, so the script computes `parent_completion_tokens` (each parent request counted once) and `allocated_completion_tokens` (parent tokens split across the subagent calls in that request).

Point `<chat_log_dir>` at the folder where you exported the chat-widget dump (see section 1):

```bash
python analyze_chat_logs.py <chat_log_dir>            # text tables
python analyze_chat_logs.py <chat_log_dir> --json     # machine-readable JSON
```

It outputs request and token counts grouped by invoked agent, a summary of subagent invocations, and a breakdown by caller agent to subagent.

Full source:

```python
#!/usr/bin/env python3
"""Analyze VS Code Copilot chat session logs.

The logs in ``chat_logs`` are JSONL state snapshots/deltas. This script extracts
request-level token usage and counts direct agent requests plus subagent
invocations found inside serialized tool-call responses.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


LOG_DIR = Path(__file__).with_name("chat_logs")


@dataclass
class RequestStats:
    request_id: str
    session_file: str
    agent_name: str = "unknown"
    agent_id: str = ""
    mode_name: str = ""
    model_id: str = ""
    completion_tokens: int = 0
    elapsed_ms: int = 0
    timestamp: int = 0


@dataclass
class SubagentStats:
    agent_name: str
    model_name: str = ""
    invocation_ids: set[str] = field(default_factory=set)
    tool_call_ids: set[str] = field(default_factory=set)
    descriptions: Counter[str] = field(default_factory=Counter)
    parent_requests: set[str] = field(default_factory=set)
    parent_invocations: Counter[str] = field(default_factory=Counter)
    parent_descriptions: dict[str, Counter[str]] = field(default_factory=dict)
    parent_models: dict[str, Counter[str]] = field(default_factory=dict)
    session_files: set[str] = field(default_factory=set)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Calculate token and request statistics from Copilot chat logs."
    )
    parser.add_argument(
        "log_dir",
        nargs="?",
        type=Path,
        default=LOG_DIR,
        help=f"Directory containing *.jsonl chat logs (default: {LOG_DIR})",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print machine-readable JSON instead of text tables.",
    )
    return parser.parse_args()


def iter_jsonl(path: Path) -> tuple[list[dict[str, Any]], int]:
    records: list[dict[str, Any]] = []
    bad_lines = 0
    with path.open("r", encoding="utf-8-sig") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                value = json.loads(line)
            except json.JSONDecodeError:
                bad_lines += 1
                continue
            if isinstance(value, dict):
                records.append(value)
    return records, bad_lines


def apply_path(root: Any, path: list[Any], value: Any) -> Any:
    """Apply a simple VS Code state delta into a Python object tree."""
    if not path:
        return value

    current = root
    for key in path[:-1]:
        if isinstance(current, list) and isinstance(key, int):
            while len(current) <= key:
                current.append({})
            current = current[key]
        elif isinstance(current, dict):
            current = current.setdefault(key, [] if isinstance(path[-1], int) else {})
        else:
            return root

    last = path[-1]
    if isinstance(current, list) and isinstance(last, int):
        while len(current) <= last:
            current.append({})
        current[last] = value
    elif isinstance(current, dict):
        current[last] = value
    return root


def build_final_state(records: list[dict[str, Any]]) -> dict[str, Any]:
    state: dict[str, Any] = {}
    for record in records:
        kind = record.get("kind")
        if kind == 0 and isinstance(record.get("v"), dict):
            state = record["v"]
        elif kind in {1, 2} and isinstance(record.get("k"), list):
            path = record["k"]
            value = record.get("v")
            if kind == 2 and path == ["requests"] and isinstance(value, list):
                state.setdefault("requests", [])
                if isinstance(state["requests"], list):
                    state["requests"].extend(value)
                continue
            state = apply_path(state, path, value)
    return state


def coerce_int(value: Any) -> int:
    if isinstance(value, bool):
        return 0
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    return 0


def agent_label(request: dict[str, Any]) -> tuple[str, str, str]:
    mode_info = request.get("modeInfo") if isinstance(request.get("modeInfo"), dict) else {}
    mode_instructions = (
        mode_info.get("modeInstructions")
        if isinstance(mode_info.get("modeInstructions"), dict)
        else {}
    )
    agent = request.get("agent") if isinstance(request.get("agent"), dict) else {}

    mode_name = str(mode_info.get("modeName") or mode_info.get("name") or "")
    agent_name = str(
        mode_instructions.get("name")
        or mode_info.get("name")
        or mode_name
        or agent.get("fullName")
        or agent.get("name")
        or agent.get("id")
        or "unknown"
    )
    agent_id = str(agent.get("id") or "")
    return agent_name, agent_id, mode_name


def collect_tool_calls(value: Any) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if value.get("kind") == "toolInvocationSerialized":
            calls.append(value)
        for child in value.values():
            calls.extend(collect_tool_calls(child))
    elif isinstance(value, list):
        for child in value:
            calls.extend(collect_tool_calls(child))
    return calls


def analyze_file(
    path: Path,
    requests: dict[str, RequestStats],
    subagents: dict[str, SubagentStats],
) -> tuple[int, int]:
    records, bad_lines = iter_jsonl(path)
    state = build_final_state(records)
    seen_requests = 0

    index_to_request_id: dict[int, str] = {}
    seen_tool_calls: set[str] = set()
    final_requests = state.get("requests", [])

    def ingest_subagent_call(call: dict[str, Any], request_id: str) -> None:
        tool_data = call.get("toolSpecificData")
        if not isinstance(tool_data, dict) or tool_data.get("kind") != "subagent":
            return

        invocation_id = str(call.get("subAgentInvocationId") or "")
        tool_call_id = str(call.get("toolCallId") or "")
        dedupe_key = invocation_id or tool_call_id or json.dumps(call, sort_keys=True, default=str)
        if dedupe_key in seen_tool_calls:
            return
        seen_tool_calls.add(dedupe_key)

        subagent_name = str(tool_data.get("agentName") or "unknown")
        subagent = subagents.setdefault(subagent_name, SubagentStats(subagent_name))
        model_name = str(tool_data.get("modelName") or "")
        subagent.model_name = model_name or subagent.model_name
        if invocation_id:
            subagent.invocation_ids.add(invocation_id)
        if tool_call_id:
            subagent.tool_call_ids.add(tool_call_id)
        if request_id and model_name:
            subagent.parent_models.setdefault(request_id, Counter())[model_name] += 1
        if tool_data.get("description"):
            description = str(tool_data["description"])
            subagent.descriptions[description] += 1
            if request_id:
                subagent.parent_descriptions.setdefault(request_id, Counter())[description] += 1
        if request_id:
            subagent.parent_requests.add(request_id)
            subagent.parent_invocations[request_id] += 1
        subagent.session_files.add(path.name)

    for index, request in enumerate(final_requests):
        if not isinstance(request, dict):
            continue

        request_id = str(request.get("requestId") or f"{path.stem}#{index}")
        index_to_request_id[index] = request_id
        agent_name, agent_id, mode_name = agent_label(request)
        stats = requests.setdefault(
            request_id,
            RequestStats(request_id=request_id, session_file=path.name),
        )
        stats.session_file = path.name
        stats.agent_name = agent_name
        stats.agent_id = agent_id
        stats.mode_name = mode_name
        stats.model_id = str(request.get("modelId") or stats.model_id)
        stats.completion_tokens = max(
            stats.completion_tokens,
            coerce_int(request.get("completionTokens")),
        )
        stats.elapsed_ms = max(stats.elapsed_ms, coerce_int(request.get("elapsedMs")))
        stats.timestamp = max(stats.timestamp, coerce_int(request.get("timestamp")))
        seen_requests += 1

        for call in collect_tool_calls(request.get("response")):
            ingest_subagent_call(call, request_id)

    for record in records:
        path_keys = record.get("k") if isinstance(record.get("k"), list) else []
        parent_request_id = ""

        if len(path_keys) >= 2 and path_keys[0] == "requests" and isinstance(path_keys[1], int):
            parent_request_id = index_to_request_id.get(path_keys[1], "")

        value = record.get("v")
        if path_keys == ["requests"] and isinstance(value, list):
            request_values = value
        else:
            request_values = [value]

        for request_value in request_values:
            inferred_request_id = parent_request_id
            if isinstance(request_value, dict) and request_value.get("requestId"):
                inferred_request_id = str(request_value["requestId"])

            for call in collect_tool_calls(request_value):
                ingest_subagent_call(call, inferred_request_id)

    return seen_requests, bad_lines


def summarize(log_dir: Path) -> dict[str, Any]:
    requests: dict[str, RequestStats] = {}
    subagents: dict[str, SubagentStats] = {}
    files = sorted(log_dir.glob("*.jsonl"))
    bad_lines = 0
    parsed_request_rows = 0

    for path in files:
        file_requests, file_bad_lines = analyze_file(path, requests, subagents)
        parsed_request_rows += file_requests
        bad_lines += file_bad_lines

    by_agent: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "requests": 0,
            "completion_tokens": 0,
            "models": Counter(),
            "session_files": set(),
        }
    )
    for request in requests.values():
        row = by_agent[request.agent_name]
        row["requests"] += 1
        row["completion_tokens"] += request.completion_tokens
        row["session_files"].add(request.session_file)
        if request.model_id:
            row["models"][request.model_id] += 1

    subagent_invocations_by_request: Counter[str] = Counter()
    for subagent in subagents.values():
        subagent_invocations_by_request.update(subagent.parent_invocations)

    def subagent_completion_stats(row: SubagentStats) -> tuple[int, int]:
        parent_tokens = sum(
            requests[request_id].completion_tokens
            for request_id in row.parent_requests
            if request_id in requests
        )
        allocated_tokens = round(
            sum(
                requests[request_id].completion_tokens
                * invocation_count
                / subagent_invocations_by_request[request_id]
                for request_id, invocation_count in row.parent_invocations.items()
                if request_id in requests and subagent_invocations_by_request[request_id]
            )
        )
        return parent_tokens, allocated_tokens

    by_subagent_caller: dict[tuple[str, str], dict[str, Any]] = defaultdict(
        lambda: {
            "invocations": 0,
            "parent_requests": set(),
            "parent_invocations": Counter(),
            "models": Counter(),
            "descriptions": Counter(),
            "session_files": set(),
        }
    )
    for subagent_name, subagent in subagents.items():
        for request_id, invocation_count in subagent.parent_invocations.items():
            request = requests.get(request_id)
            caller_agent = request.agent_name if request else "unknown"
            row = by_subagent_caller[(caller_agent, subagent_name)]
            row["invocations"] += invocation_count
            row["parent_requests"].add(request_id)
            row["parent_invocations"][request_id] += invocation_count
            row["descriptions"].update(subagent.parent_descriptions.get(request_id, Counter()))
            row["models"].update(subagent.parent_models.get(request_id, Counter()))
            row["session_files"].update(subagent.session_files)

    return {
        "log_dir": str(log_dir),
        "files": len(files),
        "bad_lines": bad_lines,
        "parsed_request_rows": parsed_request_rows,
        "unique_requests": len(requests),
        "total_completion_tokens": sum(r.completion_tokens for r in requests.values()),
        "subagent_token_note": (
            "Subagent call payloads do not contain direct token counters. "
            "parent_completion_tokens sums each parent request once when the "
            "subagent appeared; allocated_completion_tokens splits parent "
            "completionTokens across subagent invocations in that request."
        ),
        "by_agent": {
            name: {
                "requests": row["requests"],
                "completion_tokens": row["completion_tokens"],
                "models": dict(row["models"]),
                "session_files": sorted(row["session_files"]),
            }
            for name, row in sorted(
                by_agent.items(),
                key=lambda item: (-item[1]["completion_tokens"], item[0].lower()),
            )
        },
        "by_subagent": {
            name: {
                "invocations": len(row.invocation_ids) or len(row.tool_call_ids),
                "parent_requests": len(row.parent_requests),
                "parent_completion_tokens": subagent_completion_stats(row)[0],
                "allocated_completion_tokens": subagent_completion_stats(row)[1],
                "model": row.model_name,
                "top_descriptions": row.descriptions.most_common(10),
                "session_files": sorted(row.session_files),
            }
            for name, row in sorted(
                subagents.items(),
                key=lambda item: (
                    -sum(
                        requests[request_id].completion_tokens
                        for request_id in item[1].parent_requests
                        if request_id in requests
                    ),
                    item[0].lower(),
                ),
            )
        },
        "by_subagent_caller": {
            f"{caller_agent} -> {subagent_name}": {
                "caller_agent": caller_agent,
                "subagent": subagent_name,
                "invocations": row["invocations"],
                "parent_requests": len(row["parent_requests"]),
                "parent_completion_tokens": sum(
                    requests[request_id].completion_tokens
                    for request_id in row["parent_requests"]
                    if request_id in requests
                ),
                "allocated_completion_tokens": round(
                    sum(
                        requests[request_id].completion_tokens
                        * invocation_count
                        / subagent_invocations_by_request[request_id]
                        for request_id, invocation_count in row["parent_invocations"].items()
                        if request_id in requests and subagent_invocations_by_request[request_id]
                    )
                ),
                "models": dict(row["models"]),
                "top_descriptions": row["descriptions"].most_common(10),
                "session_files": sorted(row["session_files"]),
            }
            for (caller_agent, subagent_name), row in sorted(
                by_subagent_caller.items(),
                key=lambda item: (
                    -sum(
                        requests[request_id].completion_tokens
                        for request_id in item[1]["parent_requests"]
                        if request_id in requests
                    ),
                    item[0][0].lower(),
                    item[0][1].lower(),
                ),
            )
        },
    }


def print_table(title: str, headers: list[str], rows: list[list[Any]]) -> None:
    print(f"\n{title}")
    if not rows:
        print("  (none)")
        return
    widths = [
        max(len(str(value)) for value in [header] + [row[index] for row in rows])
        for index, header in enumerate(headers)
    ]
    print("  " + "  ".join(header.ljust(widths[index]) for index, header in enumerate(headers)))
    print("  " + "  ".join("-" * width for width in widths))
    for row in rows:
        print("  " + "  ".join(str(value).ljust(widths[index]) for index, value in enumerate(row)))


def print_text(summary: dict[str, Any]) -> None:
    print(f"Chat log directory: {summary['log_dir']}")
    print(f"Files analyzed: {summary['files']}")
    print(f"Unique requests: {summary['unique_requests']}")
    print(f"Total completion tokens: {summary['total_completion_tokens']:,}")
    if summary["bad_lines"]:
        print(f"Malformed JSONL lines skipped: {summary['bad_lines']}")
    print("Token note: these logs expose completionTokens; prompt/input token fields were not present.")
    print(summary["subagent_token_note"])

    agent_rows = [
        [
            name,
            data["requests"],
            f"{data['completion_tokens']:,}",
            ", ".join(data["models"].keys()) or "-",
        ]
        for name, data in summary["by_agent"].items()
    ]
    print_table("Requests and Tokens by Invoked Agent", ["agent", "requests", "completion tokens", "models"], agent_rows)

    subagent_rows = [
        [
            name,
            data["invocations"],
            data["parent_requests"],
            f"{data['parent_completion_tokens']:,}",
            f"{data['allocated_completion_tokens']:,}",
            data["model"] or "-",
            "; ".join(f"{desc} ({count})" for desc, count in data["top_descriptions"][:3]) or "-",
        ]
        for name, data in summary["by_subagent"].items()
    ]
    print_table(
        "Subagent Invocations",
        [
            "subagent",
            "invocations",
            "parent requests",
            "parent tokens",
            "allocated tokens",
            "model",
            "top descriptions",
        ],
        subagent_rows,
    )

    subagent_caller_rows = [
        [
            data["caller_agent"],
            data["subagent"],
            data["invocations"],
            data["parent_requests"],
            f"{data['parent_completion_tokens']:,}",
            f"{data['allocated_completion_tokens']:,}",
            ", ".join(data["models"].keys()) or "-",
            "; ".join(f"{desc} ({count})" for desc, count in data["top_descriptions"][:3]) or "-",
        ]
        for data in summary["by_subagent_caller"].values()
    ]
    print_table(
        "Subagent Invocations by Caller Agent",
        [
            "caller",
            "subagent",
            "invocations",
            "parent requests",
            "parent tokens",
            "allocated tokens",
            "models",
            "top descriptions",
        ],
        subagent_caller_rows,
    )


def main() -> None:
    args = parse_args()
    summary = summarize(args.log_dir)
    if args.json:
        print(json.dumps(summary, indent=2))
    else:
        print_text(summary)


if __name__ == "__main__":
    main()
```

### 2b. `extract-invocations-from-transcript.py` (reads transcripts, cross-refs chat logs)

Pipeline:

1. `load_jsonl()` produces a list of `TranscriptEvent` objects (`id`, `parentId`, `type`, `timestamp`, `data`).
2. It builds `parent_by_id` (the parent chain) and `completion_events_by_tool_call()` (indexes `tool.execution_complete` by `toolCallId`).
3. It scans `assistant.message` events for `toolRequests` where `name == "runSubagent"` and `arguments.agentName` matches the target, keyed by `toolCallId`.
4. Each `tool.execution_start` for `runSubagent` with the target agent is bound to its completion event, giving a `SubagentInvocation` with line bounds, success flag, prompt, and description.
5. `index_chat_log_tools()` reads the matching chat-log files and enriches each tool call with `resultDetails.isError`, terminal state, exit code, command lines, and output.
6. `collect_thinking()` pulls `reasoningText` from the subagent's assistant turns. `collect_tool_invocations()` lists every tool the subagent ran, with success or failure.

`nearest_run_start()` is the key detail: to assign an event to a subagent, it walks the `parentId` chain up to the closest `runSubagent` start. Parallel sibling subagent calls can serialize as nested under one another, so the script treats every target-agent `runSubagent` start as a hard invocation boundary. This stops wrapper or sibling calls from looking like ordinary tools inside the parent.

Point `<transcript_dir>` at the transcript file's parent (or a folder holding transcript `.jsonl` files), and `<chat_log_dir>` at the chat-widget dump folder:

```bash
python extract-invocations-from-transcript.py <transcript_dir> -o <output.md> --agent <agentName> --chat-log-dir <chat_log_dir>
```

Defaults: transcript dir is `transcripts/`, chat-log dir is `chat_logs/`, target agent is `ticket-helper`, output is `ticket-helper-failures.md`. Change `--agent` to the name of the subagent you actually want to extract. The output is a markdown report with each invocation's full prompt, reasoning turns, and the tools it called with their outcomes.

Full source:

```python
#!/usr/bin/env python3
"""Extract subagent invocations from VS Code/Copilot transcript JSONL files.

The default output is tailored to the ticket-helper investigation:

- locate each `runSubagent` invocation for `ticket-helper`
- preserve the exact full prompt used to invoke the subagent
- collect `reasoningText` from assistant thinking turns inside the subagent
- collect tool invocations and their success/failure status, including
  `run_in_terminal` commands with explanation and goal

The transcript event tree can keep parent-agent follow-up messages under a
completed subagent's ancestry, so completed invocations are bounded by their own
`runSubagent` completion line.

Parallel sibling `runSubagent` starts can also be serialized as descendants of
one another. The extractor treats every target-agent `runSubagent` start as an
invocation boundary so wrapper/sibling calls do not appear as ordinary tools
inside another invocation.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any


DEFAULT_TRANSCRIPT_DIR = Path(__file__).with_name("transcripts")
DEFAULT_CHAT_LOG_DIR = Path(__file__).with_name("chat_logs")
DEFAULT_OUTPUT = Path(__file__).with_name("ticket-helper-failures.md")


@dataclass
class TranscriptEvent:
    raw: dict[str, Any]
    line: int

    @property
    def event_id(self) -> str:
        return str(self.raw.get("id") or "")

    @property
    def parent_id(self) -> str:
        return str(self.raw.get("parentId") or "")

    @property
    def event_type(self) -> str:
        return str(self.raw.get("type") or "")

    @property
    def timestamp(self) -> str:
        return str(self.raw.get("timestamp") or "")

    @property
    def data(self) -> dict[str, Any]:
        data = self.raw.get("data")
        return data if isinstance(data, dict) else {}


@dataclass
class SubagentInvocation:
    file: str
    request_line: int | None
    request_timestamp: str
    request_message_id: str
    line: int
    event_id: str
    parent_id: str
    tool_call_id: str
    timestamp: str
    description: str
    prompt: str
    events: list[TranscriptEvent] = field(default_factory=list)
    success: bool | None = None
    complete_line: int | None = None
    complete_timestamp: str = ""
    nested_invocation_ids: list[str] = field(default_factory=list)
    nested_tool_call_ids: list[str] = field(default_factory=list)
    wrapper_invocation: bool = False


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract subagent prompts, thinking turns, and tool invocations from transcript JSONL files."
    )
    parser.add_argument(
        "transcript_dir",
        nargs="?",
        type=Path,
        default=DEFAULT_TRANSCRIPT_DIR,
        help=f"Directory containing transcript *.jsonl files (default: {DEFAULT_TRANSCRIPT_DIR})",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Markdown output path (default: {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--chat-log-dir",
        type=Path,
        default=DEFAULT_CHAT_LOG_DIR,
        help=f"Directory containing matching chat log *.jsonl files (default: {DEFAULT_CHAT_LOG_DIR})",
    )
    parser.add_argument(
        "--agent",
        default="ticket-helper",
        help="Subagent name to extract from runSubagent calls (default: ticket-helper)",
    )
    return parser.parse_args()


def load_jsonl(path: Path) -> list[TranscriptEvent]:
    events: list[TranscriptEvent] = []
    with path.open("r", encoding="utf-8-sig") as handle:
        for line_no, line in enumerate(handle, 1):
            line = line.strip()
            if not line:
                continue
            try:
                value = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(value, dict):
                events.append(TranscriptEvent(value, line_no))
    return events


def parse_tool_arguments(raw: Any) -> dict[str, Any]:
    if isinstance(raw, dict):
        return raw
    if isinstance(raw, str):
        try:
            value = json.loads(raw)
        except json.JSONDecodeError:
            return {}
        return value if isinstance(value, dict) else {}
    return {}


def markdown_fence(text: Any) -> str:
    value = "" if text is None else str(text)
    run = 0
    max_run = 0
    for char in value:
        if char == "`":
            run += 1
            max_run = max(max_run, run)
        else:
            run = 0
    ticks = "`" * max(3, max_run + 1)
    return f"{ticks}\n{value}\n{ticks}"


def one_line(text: str) -> str:
    return str(text or "").replace("\n", " ").strip()


def completion_events_by_tool_call(events: list[TranscriptEvent]) -> dict[str, list[TranscriptEvent]]:
    completions: dict[str, list[TranscriptEvent]] = {}
    for event in events:
        data = event.data
        tool_call_id = data.get("toolCallId")
        if event.event_type == "tool.execution_complete" and tool_call_id:
            completions.setdefault(str(tool_call_id), []).append(event)
    return completions


def iter_dicts(value: Any) -> Any:
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from iter_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from iter_dicts(child)


def index_chat_log_tools(chat_log_dir: Path) -> dict[str, dict[str, dict[str, Any]]]:
    by_file: dict[str, dict[str, dict[str, Any]]] = {}
    if not chat_log_dir.exists():
        return by_file

    for path in sorted(chat_log_dir.glob("*.jsonl")):
        by_tool_call: dict[str, dict[str, Any]] = {}
        with path.open("r", encoding="utf-8-sig") as handle:
            for line_no, line in enumerate(handle, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    root = json.loads(line)
                except json.JSONDecodeError:
                    continue
                for item in iter_dicts(root):
                    if item.get("kind") != "toolInvocationSerialized":
                        continue
                    tool_call_id = item.get("toolCallId")
                    if not tool_call_id:
                        continue
                    by_tool_call[str(tool_call_id)] = {
                        "line": line_no,
                        "tool_id": str(item.get("toolId") or ""),
                        "subagent_invocation_id": str(item.get("subAgentInvocationId") or ""),
                        "is_complete": item.get("isComplete"),
                        "result_is_error": (item.get("resultDetails") or {}).get("isError")
                        if isinstance(item.get("resultDetails"), dict)
                        else None,
                        "result_details": item.get("resultDetails"),
                        "tool_specific_data": item.get("toolSpecificData"),
                    }
        if by_tool_call:
            by_file[path.name] = by_tool_call

    return by_file


def terminal_log_summary(log_entry: dict[str, Any] | None) -> dict[str, Any]:
    if not log_entry:
        return {}
    data = log_entry.get("tool_specific_data")
    if not isinstance(data, dict) or data.get("kind") != "terminal":
        return {}
    state = data.get("terminalCommandState") if isinstance(data.get("terminalCommandState"), dict) else {}
    command_line = data.get("commandLine") if isinstance(data.get("commandLine"), dict) else {}
    output = data.get("terminalCommandOutput") if isinstance(data.get("terminalCommandOutput"), dict) else {}
    cwd = data.get("cwd") if isinstance(data.get("cwd"), dict) else {}
    return {
        "exit_code": state.get("exitCode"),
        "duration": state.get("duration"),
        "timestamp": state.get("timestamp"),
        "command": command_line.get("original") or command_line.get("forDisplay"),
        "cwd": cwd.get("path"),
        "output_line_count": output.get("lineCount"),
        "output_text": output.get("text"),
    }


def extract_file(path: Path, agent_name: str) -> list[SubagentInvocation]:
    events = load_jsonl(path)
    parent_by_id = {event.event_id: event.parent_id for event in events if event.event_id}
    completions = completion_events_by_tool_call(events)
    invocations_by_start_id: dict[str, SubagentInvocation] = {}
    requests_by_tool_call: dict[str, dict[str, Any]] = {}

    for event in events:
        if event.event_type != "assistant.message":
            continue
        for request in event.data.get("toolRequests") or []:
            if request.get("name") != "runSubagent":
                continue
            arguments = parse_tool_arguments(request.get("arguments"))
            if arguments.get("agentName") != agent_name:
                continue
            requests_by_tool_call[str(request.get("toolCallId") or "")] = {
                "line": event.line,
                "timestamp": event.timestamp,
                "message_id": event.event_id,
            }

    for event in events:
        data = event.data
        if event.event_type != "tool.execution_start":
            continue
        if data.get("toolName") != "runSubagent":
            continue

        arguments = parse_tool_arguments(data.get("arguments"))
        if arguments.get("agentName") != agent_name:
            continue

        tool_call_id = str(data.get("toolCallId") or "")
        request_event = requests_by_tool_call.get(tool_call_id, {})
        invocation = SubagentInvocation(
            file=path.name,
            request_line=request_event.get("line"),
            request_timestamp=str(request_event.get("timestamp") or ""),
            request_message_id=str(request_event.get("message_id") or ""),
            line=event.line,
            event_id=event.event_id,
            parent_id=event.parent_id,
            tool_call_id=tool_call_id,
            timestamp=event.timestamp,
            description=str(arguments.get("description") or ""),
            prompt=str(arguments.get("prompt") or ""),
        )

        completion = next(iter(completions.get(tool_call_id, [])), None)
        if completion:
            invocation.success = bool(completion.data.get("success"))
            invocation.complete_line = completion.line
            invocation.complete_timestamp = completion.timestamp

        invocations_by_start_id[event.event_id] = invocation

    run_start_ids = set(invocations_by_start_id)
    run_tool_call_by_start_id = {
        start_id: invocation.tool_call_id for start_id, invocation in invocations_by_start_id.items()
    }

    def nearest_run_start(event: TranscriptEvent) -> str | None:
        current = event.parent_id
        seen: set[str] = set()
        while current and current not in seen:
            seen.add(current)
            if current in run_start_ids:
                return current
            current = parent_by_id.get(current, "")
        return None

    for event in events:
        start_id = nearest_run_start(event)
        if not start_id:
            continue

        invocation = invocations_by_start_id[start_id]
        if event.line <= invocation.line:
            continue
        if invocation.complete_line is not None and event.line > invocation.complete_line:
            continue

        # A target-agent runSubagent start nested under another target-agent
        # start is a separate invocation boundary, not a normal child tool.
        # VS Code/Copilot transcripts can serialize parallel sibling subagent
        # calls this way, which previously inflated tool counts and produced
        # confusing `runSubagent - unknown` entries inside the parent.
        if event.event_id in run_start_ids:
            nested = invocations_by_start_id[event.event_id]
            invocation.nested_invocation_ids.append(nested.event_id)
            invocation.nested_tool_call_ids.append(nested.tool_call_id)
            continue

        invocation.events.append(event)

    for invocation in invocations_by_start_id.values():
        tools = collect_tool_invocations(invocation)
        non_wrapper_tools = [tool for tool in tools if not is_target_subagent_tool(tool, agent_name)]
        thinking = collect_thinking(invocation)
        # If an older transcript shape still leaves a nested target-agent
        # runSubagent request in the event stream, capture it as nested metadata.
        for tool in tools:
            if (tool.get("name") or "") != "runSubagent":
                continue
            arguments = tool.get("arguments") or {}
            if arguments.get("agentName") != agent_name:
                continue
            tool_call_id = str(tool.get("tool_call_id") or "")
            if tool_call_id and tool_call_id not in invocation.nested_tool_call_ids:
                invocation.nested_tool_call_ids.append(tool_call_id)
            for nested_start_id, nested_tool_call_id in run_tool_call_by_start_id.items():
                if nested_tool_call_id != tool_call_id:
                    continue
                if nested_start_id != invocation.event_id and nested_start_id not in invocation.nested_invocation_ids:
                    invocation.nested_invocation_ids.append(nested_start_id)
        invocation.wrapper_invocation = (
            not non_wrapper_tools
            and not thinking
            and (bool(tools) or bool(invocation.nested_tool_call_ids))
        )

    return sorted(invocations_by_start_id.values(), key=lambda item: item.line)


def extract_invocations(transcript_dir: Path, agent_name: str) -> list[SubagentInvocation]:
    invocations: list[SubagentInvocation] = []
    for path in sorted(transcript_dir.glob("*.jsonl")):
        invocations.extend(extract_file(path, agent_name))
    return sorted(invocations, key=lambda item: (item.file, item.line))


def collect_thinking(invocation: SubagentInvocation) -> list[tuple[int, str, str]]:
    thinking: list[tuple[int, str, str]] = []
    for event in invocation.events:
        if event.event_type != "assistant.message":
            continue
        reasoning = event.data.get("reasoningText")
        if reasoning:
            thinking.append((event.line, event.timestamp, str(reasoning)))
    return thinking


def collect_tool_invocations(
    invocation: SubagentInvocation,
    log_tools: dict[str, dict[str, dict[str, Any]]] | None = None,
) -> list[dict[str, Any]]:
    tool_requests: list[dict[str, Any]] = []
    tool_starts: dict[str, dict[str, Any]] = {}
    completions: dict[str, dict[str, Any]] = {}

    for event in invocation.events:
        data = event.data
        if event.event_type == "assistant.message":
            for request in data.get("toolRequests") or []:
                arguments = parse_tool_arguments(request.get("arguments"))
                tool_requests.append(
                    {
                        "request_line": event.line,
                        "request_timestamp": event.timestamp,
                        "tool_call_id": str(request.get("toolCallId") or ""),
                        "name": str(request.get("name") or ""),
                        "arguments": arguments,
                        "command": str(arguments.get("command") or ""),
                        "explanation": str(arguments.get("explanation") or ""),
                        "goal": str(arguments.get("goal") or ""),
                    }
                )

        if event.event_type == "tool.execution_start" and data.get("toolName"):
            arguments = parse_tool_arguments(data.get("arguments"))
            tool_starts[str(data.get("toolCallId") or "")] = {
                "start_line": event.line,
                "timestamp": event.timestamp,
                "name": str(data.get("toolName") or ""),
                "arguments": arguments,
                "command": str(arguments.get("command") or ""),
                "explanation": str(arguments.get("explanation") or ""),
                "goal": str(arguments.get("goal") or ""),
            }

        if event.event_type == "tool.execution_complete" and data.get("toolCallId"):
            completions[str(data.get("toolCallId"))] = {
                "line": event.line,
                "timestamp": event.timestamp,
                "success": data.get("success"),
            }

    seen = {request["tool_call_id"] for request in tool_requests}
    for tool_call_id, start in tool_starts.items():
        if tool_call_id in seen:
            continue
        tool_requests.append(
            {
                "request_line": None,
                "request_timestamp": "",
                "tool_call_id": tool_call_id,
                "name": start["name"],
                "arguments": start["arguments"],
                "command": start["command"],
                "explanation": start["explanation"],
                "goal": start["goal"],
            }
        )

    for request in tool_requests:
        start = tool_starts.get(request["tool_call_id"])
        if start:
            request["start"] = start
            request.setdefault("name", start["name"])
            if not request.get("command"):
                request["command"] = start["command"]
            if not request.get("explanation"):
                request["explanation"] = start["explanation"]
            if not request.get("goal"):
                request["goal"] = start["goal"]
        request["completion"] = completions.get(request["tool_call_id"])
        log_entry = (log_tools or {}).get(invocation.file, {}).get(request["tool_call_id"])
        request["log"] = log_entry
        request["terminal_log"] = terminal_log_summary(log_entry)

    return sorted(
        tool_requests,
        key=lambda item: (
            item.get("request_line") or (item.get("start") or {}).get("start_line") or 0,
            item["tool_call_id"],
        ),
    )


def collect_ordered_events(
    invocation: SubagentInvocation,
    log_tools: dict[str, dict[str, dict[str, Any]]] | None = None,
    target_agent_name: str = "",
) -> list[dict[str, Any]]:
    ordered: list[dict[str, Any]] = []
    tool_invocations = collect_tool_invocations(invocation, log_tools)

    visible_tools = [
        tool for tool in tool_invocations if not is_target_subagent_tool(tool, target_agent_name)
    ]
    for index, tool in enumerate(visible_tools, 1):
        start = tool.get("start") or {}
        ordered.append(
            {
                "kind": "tool",
                "line": start.get("start_line") or tool.get("request_line") or 0,
                "index": index,
                "tool": tool,
            }
        )

    thinking_index = 0
    for event in invocation.events:
        if event.event_type != "assistant.message":
            continue
        reasoning = event.data.get("reasoningText")
        if not reasoning:
            continue
        thinking_index += 1
        ordered.append(
            {
                "kind": "thinking",
                "line": event.line,
                "index": thinking_index,
                "timestamp": event.timestamp,
                "text": str(reasoning),
            }
        )

    return sorted(ordered, key=lambda item: (item["line"], 0 if item["kind"] == "thinking" else 1, item["index"]))


def status_label(success: Any) -> str:
    if success is None:
        return "unknown"
    return "success" if bool(success) else "failure"


def effective_tool_status(tool: dict[str, Any]) -> str:
    terminal = tool.get("terminal_log") or {}
    exit_code = terminal.get("exit_code")
    if isinstance(exit_code, int):
        return "success" if exit_code == 0 else "failure"
    log_entry = tool.get("log") or {}
    if log_entry.get("result_is_error") is True:
        return "failure"
    completion = tool.get("completion")
    if completion:
        return status_label(completion.get("success"))
    return "unknown"


def is_target_subagent_tool(tool: dict[str, Any], agent_name: str) -> bool:
    if not agent_name:
        return False
    if (tool.get("name") or "") != "runSubagent":
        return False
    arguments = tool.get("arguments") or {}
    return arguments.get("agentName") == agent_name


def display_path(path: Path) -> str:
    try:
        return path.resolve().relative_to(Path.cwd().resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def unique_ordered(values: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        if not value or value in seen:
            continue
        seen.add(value)
        result.append(value)
    return result


def render_markdown(
    invocations: list[SubagentInvocation],
    transcript_dir: Path,
    agent_name: str,
    log_tools: dict[str, dict[str, dict[str, Any]]] | None = None,
) -> str:
    transcript_display = display_path(transcript_dir)
    lines: list[str] = []
    lines.append(f"# {agent_name} Subagent Invocations")
    lines.append("")
    lines.append(
        f"Generated from `{transcript_display}` on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}."
    )
    lines.append("")
    lines.append(f"Total {agent_name} invocations: {len(invocations)}.")
    lines.append("")
    wrapper_count = sum(1 for invocation in invocations if invocation.wrapper_invocation)
    nested_reference_count = sum(1 for invocation in invocations if invocation.nested_tool_call_ids)
    lines.append(f"Wrapper-only invocations: {wrapper_count}.")
    lines.append(f"Invocations with nested/wrapper subagent references: {nested_reference_count}.")
    lines.append("")
    lines.append(
        "For each invocation, the top-level status is the `runSubagent` tool completion status. "
        "Tool statuses use terminal exit codes from matching chat logs when available; non-zero terminal exit codes are reported as failures. "
        "Nested target-agent `runSubagent` starts are reported as wrapper metadata instead of ordinary tool failures."
    )
    lines.append("")

    for number, invocation in enumerate(invocations, 1):
        title = invocation.description or one_line(invocation.prompt)[:80] or invocation.tool_call_id
        lines.append(f"## {number}. {title}")
        lines.append("")
        lines.append(f"- File: `{transcript_display}/{invocation.file}`")
        if invocation.request_line:
            lines.append(f"- Invocation request line: `{invocation.request_line}`")
        if invocation.request_timestamp:
            lines.append(f"- Invocation request timestamp: `{invocation.request_timestamp}`")
        if invocation.request_message_id:
            lines.append(f"- Invocation request message id: `{invocation.request_message_id}`")
        lines.append(f"- Execution start line: `{invocation.line}`")
        lines.append(f"- Execution start id: `{invocation.event_id}`")
        lines.append(f"- Tool call id: `{invocation.tool_call_id}`")
        lines.append(f"- Execution start timestamp: `{invocation.timestamp}`")
        if invocation.complete_line:
            lines.append(f"- Completion line: `{invocation.complete_line}`")
        if invocation.complete_timestamp:
            lines.append(f"- Completion timestamp: `{invocation.complete_timestamp}`")
        lines.append(f"- Invocation status: `{status_label(invocation.success)}`")
        lines.append(f"- Wrapper-only invocation: `{'yes' if invocation.wrapper_invocation else 'no'}`")
        nested_tool_call_ids = unique_ordered(invocation.nested_tool_call_ids)
        nested_invocation_ids = unique_ordered(invocation.nested_invocation_ids)
        if nested_tool_call_ids:
            lines.append(
                "- Nested/wrapper subagent tool call ids: "
                + ", ".join(f"`{tool_call_id}`" for tool_call_id in nested_tool_call_ids)
            )
        if nested_invocation_ids:
            lines.append(
                "- Nested/wrapper subagent execution start ids: "
                + ", ".join(f"`{event_id}`" for event_id in nested_invocation_ids)
            )
        lines.append("")
        lines.append("### Full Prompt")
        lines.append("")
        lines.append(markdown_fence(invocation.prompt))
        lines.append("")

        lines.append("### Events In Order")
        lines.append("")
        ordered_events = collect_ordered_events(invocation, log_tools, agent_name)
        if ordered_events:
            for event in ordered_events:
                if event["kind"] == "thinking":
                    lines.append(
                        f"#### Thinking {event['index']} "
                        f"(line {event['line']}, timestamp `{event['timestamp']}`)"
                    )
                    lines.append("")
                    lines.append(markdown_fence(event["text"]))
                    lines.append("")
                    continue

                tool = event["tool"]
                completion = tool.get("completion")
                start = tool.get("start") or {}
                transcript_success = completion.get("success") if completion else None
                tool_name = tool.get("name") or start.get("name") or "unknown"
                lines.append(f"#### Tool {event['index']}: `{tool_name}` - `{effective_tool_status(tool)}`")
                lines.append("")
                if tool.get("request_line"):
                    lines.append(f"- Request line: `{tool['request_line']}`")
                if tool.get("request_timestamp"):
                    lines.append(f"- Request timestamp: `{tool['request_timestamp']}`")
                if start:
                    lines.append(f"- Execution start line: `{start['start_line']}`")
                    if start.get("timestamp"):
                        lines.append(f"- Execution start timestamp: `{start['timestamp']}`")
                lines.append(f"- Tool call id: `{tool['tool_call_id']}`")
                if completion:
                    lines.append(f"- Completion line: `{completion['line']}`")
                    if completion.get("timestamp"):
                        lines.append(f"- Completion timestamp: `{completion['timestamp']}`")
                    lines.append(f"- Transcript completion status: `{status_label(transcript_success)}`")
                log_entry = tool.get("log")
                terminal = tool.get("terminal_log") or {}
                if log_entry:
                    lines.append(f"- Chat log line: `{log_entry['line']}`")
                    if log_entry.get("result_is_error") is not None:
                        lines.append(f"- Chat log result error: `{bool(log_entry['result_is_error'])}`")
                if terminal:
                    lines.append(f"- Terminal exit code: `{terminal.get('exit_code')}`")
                    lines.append(
                        f"- Terminal exit status: `{'success' if terminal.get('exit_code') == 0 else 'failure'}`"
                    )
                    if terminal.get("duration") is not None:
                        lines.append(f"- Terminal duration ms: `{terminal['duration']}`")
                    if terminal.get("cwd"):
                        lines.append(f"- Terminal cwd: `{terminal['cwd']}`")
                    if terminal.get("output_line_count") is not None:
                        lines.append(f"- Terminal output line count: `{terminal['output_line_count']}`")
                lines.append(f"- Explanation: {tool.get('explanation') or ''}")
                lines.append(f"- Goal: {tool.get('goal') or ''}")
                lines.append("")
                if terminal and terminal.get("exit_code") not in (None, 0) and terminal.get("output_text"):
                    lines.append("Terminal Output:")
                    lines.append("")
                    lines.append(markdown_fence(terminal["output_text"]))
                    lines.append("")
                if tool.get("command"):
                    lines.append("Command:")
                    lines.append("")
                    lines.append(markdown_fence(tool["command"]))
                    lines.append("")
                lines.append("Arguments:")
                lines.append("")
                lines.append(markdown_fence(json.dumps(tool.get("arguments") or {}, indent=2, ensure_ascii=False)))
                lines.append("")
        else:
            lines.append("_No thinking turns or tool invocations recorded inside this subagent invocation._")
            lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def main() -> None:
    args = parse_args()
    log_tools = index_chat_log_tools(args.chat_log_dir)
    invocations = extract_invocations(args.transcript_dir, args.agent)
    markdown = render_markdown(invocations, args.transcript_dir, args.agent, log_tools)
    args.output.write_text(markdown, encoding="utf-8")
    print(f"Wrote {args.output} with {len(invocations)} {args.agent} invocations.")


if __name__ == "__main__":
    main()
```

## 3. Feeding each view

### Cache Explorer view

This view is about token usage and prompt composition. Two sources feed it.

From the **chat-widget dump**, run `analyze_chat_logs.py --json` and read:

- `total_completion_tokens` and `unique_requests`.
- `by_agent.<agent>.completion_tokens` and `.requests` for per-agent totals.
- `by_subagent.<agent>.parent_completion_tokens` and `.allocated_completion_tokens` for subagent cost allocation. The attached `subagent_token_note` reminder explains the limitation: subagent payloads have no direct token counters, so the parent request is charged.

From the **debug logs**, read `main.jsonl` `llm_request` events if you need input tokens, cache hits, or time-to-first-token. The `attrs` there carry `model`, `inputTokens`, `outputTokens`, `ttft`, `maxTokens`, `temperature`, `topP`, `systemPromptFile`, and `userRequest`. Input and cache fields are absent from the chat-widget dump, so the debug logs are your only source for prompt size and cache behavior. For the full system prompt backing a request, open the `system_prompt_*.json` file named in `systemPromptFile` (also referenced by a `system_prompt_ref` entry).

### Agent Flow Chart view

This view maps the agent hierarchy: who called whom, and how often.

The fastest path is the chat-widget dump plus `analyze_chat_logs.py`. Use the `by_subagent_caller` block, keyed as `"<caller_agent> -> <subagent>"`. Each entry has `invocations`, `parent_requests`, `parent_completion_tokens`, `allocated_completion_tokens`, `models`, and the top call descriptions. In text-table mode this prints as a `Subagent Invocations by Caller Agent` table, with one row per caller-to-subagent pair and their shared tokens: for example, a row showing `workflow-mgr` calling `ticket-helper` directly, and another row showing `Architect` in turn calling `ticket-helper`.

For the exact nesting order and per-invocation prompts, use the transcript extractor. It reproduces the tree from `parentId` chains and emits one section per `runSubagent` invocation with its prompt, so you can trace a leaf subagent back through its caller chain.

From the **debug logs**, the `spanId` / `parentSpanId` pair gives the same tree. A `subagent` event names the child agent (`attrs.agentName`); its `parentSpanId` points at the caller's `tool_call` for `runSubagent`. Each top-level request gets one `subagent` event per child it spawns.

### Logs view

This view is the chronological timeline: tool calls, their arguments and results, errors, and the model's reasoning.

From the **transcripts**, `extract-invocations-from-transcript.py` produces a per-subagent log. For each invocation you get the ordered tool list (`collect_tool_invocations`), reasoning turns (`collect_thinking`), and the cross-referenced terminal output and exit codes. Each tool entry carries `name`, `arguments`, `command`, `explanation`, `goal`, and a `completion` with `success`.

From the **chat-widget dump**, `toolInvocationSerialized` nodes carry `toolId`, `toolCallId`, `subAgentInvocationId`, `isComplete`, and `resultDetails.isError`. `index_chat_log_tools()` in the extractor keys all of these by `toolCallId` so the transcript events and chat-widget details join cleanly. The `terminal_log_summary()` helper extracts exit code, duration, command line, working directory, and output text from `run_in_terminal` calls.

From the **debug logs**, `main.jsonl` `tool_call` events carry `attrs.args` (JSON input), `attrs.result` (output or error text), and `status` of `ok` or `error`. To find errors, filter for `"status":"error"`. To find slow calls, filter for high `dur` values (in milliseconds). The `agent_response` events carry `attrs.response` and optional `attrs.reasoning` for the model's thinking.

## 4. Workflow for any new session

1. Find the session. Use the session history DB to locate it by keyword, or read the session registry in `state.vscdb` key `chat.ChatSessionStore.index`:

   ```bash
   sqlite3 "<user-data>/User/globalStorage/github.copilot-chat/session-store.db" \
     "SELECT id, agent_name, created_at, summary FROM sessions WHERE summary LIKE '%<keyword>%';"
   ```

   The returned `id` is the `<sessionId>` for all the per-session paths below.

2. Gather the three sources for that session:

   ```text
   <...>/GitHub.copilot-chat/debug-logs/<sessionId>/main.jsonl
   <...>/GitHub.copilot-chat/transcripts/<sessionId>.jsonl
   <...> a chat-widget dump for <sessionId> (export first, see section 1)
   ```

   The scripts default to `transcripts/` and `chat_logs/` subfolders of the current directory, so either copy the files into those names or pass the paths as arguments.

3. Triage the debug log first if you need a quick read of the session. On Windows, use `Select-String` or `node -e`. On macOS or Linux, use `grep` or `jq`. Use the terminal for this, since debug logs live outside the workspace and `grep_search` cannot reach them.

4. Run the analysis.

   For call counts and token totals:

   ```bash
   python analyze_chat_logs.py <chat_log_dir> --json > cache.json
   ```

   For per-subagent detail with prompts, reasoning, and tool outcomes:

   ```bash
   python extract-invocations-from-transcript.py <transcript_dir> --chat-log-dir <chat_log_dir> --agent <agentName> -o report.md
   ```

5. Build the views from the outputs.
   - Cache Explorer: `cache.json` fields `by_agent`, `by_subagent`, plus debug-log `llm_request` tokens for input and cache data the chat-widget dump lacks.
   - Agent Flow Chart: `by_subagent_caller` from `analyze_chat_logs.py`, or the invocation tree from the transcript report.
   - Logs view: the ordered tool and reasoning list from the transcript report, joined to chat-widget `resultDetails` by `toolCallId`.

## 5. Quick reference

| You want | Source | Script or command |
| --- | --- | --- |
| Per-agent token totals | chat-widget dump | `analyze_chat_logs.py --json` -> `by_agent` |
| Subagent cost allocation | chat-widget dump | `analyze_chat_logs.py --json` -> `by_subagent` |
| Input tokens, cache hits, TTFT | debug logs | `main.jsonl` `llm_request` attrs |
| Full system prompt | debug logs | `system_prompt_*.json` via `systemPromptFile` |
| Caller to subagent map | chat-widget dump | `analyze_chat_logs.py` -> `by_subagent_caller` |
| Per-invocation prompt and reasoning | transcripts | `extract-invocations-from-transcript.py` report |
| Tool call result or error | chat-widget dump + transcripts | `extract-invocations-from-transcript.py`, joined by `toolCallId` |
| Tool errors in the debug log | debug logs | filter `main.jsonl` for `"status":"error"` |
| Terminal command and exit code | chat-widget dump | `terminal_log_summary()` on `run_in_terminal` calls |
| Find a session by keyword | session-store.db | FTS5 `search_index MATCH '<term>'` |

### Notes and limits

- Subagent payloads in the chat-widget dump carry no direct token counters. `parent_completion_tokens` counts each parent request once; `allocated_completion_tokens` splits it across the subagent calls in that request.
- The transcript tree can serialize parallel sibling subagent calls as nested under one another. The extractor treats each target-agent `runSubagent` start as a boundary so wrapper or sibling calls are not counted as ordinary child tools.
- The chat-widget dump (`kind:0/1/2`) is not a file VS Code writes to disk by default; you must export it from the running extension host or read it from the state store.
- Debug-log and transcript files can be large. Check size first, then stream with `grep`, `jq`, or `Select-String`. Avoid loading whole files into memory.
- Use straight quotes, not curly quotes, when grepping for strings in the logs.
