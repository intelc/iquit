#!/usr/bin/env python3
"""Export sanitized Codex user/assistant transcripts for this project."""

from __future__ import annotations

import argparse
import getpass
import json
import os
import pwd
import re
import socket
import subprocess
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable
from urllib.parse import urlsplit, urlunsplit


DEFAULT_INITIAL_SESSION = "019e183c-c75e-73d2-8b5d-ac92b2a68327"


@dataclass
class SessionInfo:
    session_id: str
    path: Path
    source: str
    cwd_values: list[str] = field(default_factory=list)
    started_at: str | None = None
    title: str | None = None


@dataclass
class Turn:
    role: str
    text: str
    timestamp: str | None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export iQuit-related Codex prompts with PII redaction."
    )
    parser.add_argument(
        "--codex-home",
        type=Path,
        default=Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")),
        help="Codex data directory. Defaults to $CODEX_HOME or ~/.codex.",
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path.cwd(),
        help="Project root used to select sessions by cwd. Defaults to cwd.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("prompts"),
        help="Folder where Markdown transcripts are written.",
    )
    parser.add_argument(
        "--include-session",
        action="append",
        default=[DEFAULT_INITIAL_SESSION],
        help="Session id to include even if its cwd is outside the project.",
    )
    parser.add_argument(
        "--redact-term",
        action="append",
        default=[],
        help="Additional literal term to replace with [REDACTED].",
    )
    return parser.parse_args()


def load_session_titles(codex_home: Path) -> dict[str, str]:
    titles: dict[str, str] = {}
    index_path = codex_home / "session_index.jsonl"
    if not index_path.exists():
        return titles

    for record in read_jsonl(index_path):
        session_id = record.get("id")
        title = record.get("thread_name")
        if isinstance(session_id, str) and isinstance(title, str):
            titles[session_id] = title
    return titles


def read_jsonl(path: Path) -> Iterable[dict]:
    try:
        with path.open("r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(record, dict):
                    yield record
    except OSError:
        return


def iter_session_files(codex_home: Path) -> Iterable[tuple[Path, str]]:
    for source_name in ("sessions", "archived_sessions"):
        source_dir = codex_home / source_name
        if not source_dir.exists():
            continue
        source_label = "archived" if source_name == "archived_sessions" else "live"
        for path in sorted(source_dir.rglob("*.jsonl")):
            yield path, source_label


def collect_matching_sessions(
    codex_home: Path,
    project_root: Path,
    include_sessions: set[str],
) -> list[SessionInfo]:
    project_root = project_root.expanduser().resolve()
    titles = load_session_titles(codex_home)
    matches: dict[Path, SessionInfo] = {}

    for path, source in iter_session_files(codex_home):
        candidate: SessionInfo | None = None
        for record in read_jsonl(path):
            if record.get("type") != "session_meta":
                continue
            payload = record.get("payload") or {}
            session_id = payload.get("id")
            if not isinstance(session_id, str):
                continue
            cwd = payload.get("cwd")
            timestamp = payload.get("timestamp") or record.get("timestamp")
            if candidate is None:
                candidate = SessionInfo(
                    session_id=session_id,
                    path=path,
                    source=source,
                    started_at=timestamp if isinstance(timestamp, str) else None,
                    title=titles.get(session_id),
                )
            if isinstance(cwd, str) and cwd not in candidate.cwd_values:
                candidate.cwd_values.append(cwd)
            if candidate.started_at is None and isinstance(timestamp, str):
                candidate.started_at = timestamp

        if candidate is None:
            continue

        cwd_match = any(is_project_cwd(cwd, project_root) for cwd in candidate.cwd_values)
        explicit_match = candidate.session_id in include_sessions
        if cwd_match or explicit_match:
            matches[path] = candidate

    return sorted(matches.values(), key=lambda item: (item.started_at or "", item.path.name))


def is_project_cwd(cwd: str, project_root: Path) -> bool:
    try:
        cwd_path = Path(cwd).expanduser().resolve()
    except OSError:
        return False
    return cwd_path == project_root


def extract_turns(path: Path) -> list[Turn]:
    response_turns: list[Turn] = []
    event_turns: list[Turn] = []

    for record in read_jsonl(path):
        timestamp = record.get("timestamp") if isinstance(record.get("timestamp"), str) else None
        record_type = record.get("type")
        payload = record.get("payload") or {}

        if record_type == "response_item" and payload.get("type") == "message":
            role = payload.get("role")
            if role not in {"user", "assistant"}:
                continue
            text = extract_content_text(payload.get("content"))
            if should_keep_turn(role, text):
                response_turns.append(Turn(role=role, text=text, timestamp=timestamp))

        if record_type == "event_msg":
            event_type = payload.get("type")
            if event_type == "user_message":
                text = str(payload.get("message") or "")
                if should_keep_turn("user", text):
                    event_turns.append(Turn(role="user", text=text, timestamp=timestamp))
            elif event_type == "agent_message":
                text = str(payload.get("message") or "")
                if should_keep_turn("assistant", text):
                    event_turns.append(Turn(role="assistant", text=text, timestamp=timestamp))

    return response_turns or event_turns


def extract_content_text(content: object) -> str:
    if isinstance(content, str):
        return content.strip()
    if not isinstance(content, list):
        return ""

    chunks: list[str] = []
    for item in content:
        if not isinstance(item, dict):
            continue
        if isinstance(item.get("text"), str):
            chunks.append(item["text"])
        elif item.get("type") in {"input_image", "local_image", "image_url"}:
            chunks.append("[IMAGE REDACTED]")
    return "\n\n".join(chunk.strip() for chunk in chunks if chunk and chunk.strip()).strip()


def should_keep_turn(role: str, text: str) -> bool:
    stripped = text.strip()
    if not stripped:
        return False
    if role == "user" and stripped.startswith("<environment_context>"):
        return False
    return True


class Redactor:
    def __init__(self, project_root: Path, extra_terms: Iterable[str]) -> None:
        self.project_root = project_root.expanduser().resolve()
        self.machine_terms = collect_machine_terms()
        self.literal_terms = sorted(
            collect_default_terms(project_root) | self.machine_terms | set(extra_terms),
            key=len,
            reverse=True,
        )

    def redact(self, text: str) -> str:
        text = re.sub(r"/Users/[^/\s)'\"<>]+", "[HOME]", text)
        text = re.sub(r"(?<!\S)~(?=/)", "[HOME]", text)
        text = re.sub(
            r"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b",
            "[EMAIL]",
            text,
        )
        text = re.sub(
            r"(?<!\w)(?:\+?1[\s.-]?)?(?:\(?\d{3}\)?[\s.-]?)\d{3}[\s.-]?\d{4}(?!\w)",
            "[PHONE]",
            text,
        )
        text = re.sub(
            r"(?i)\b(?:sk|rk|xai|ghp|github_pat)-[A-Za-z0-9_\-]{16,}\b",
            "[SECRET]",
            text,
        )
        text = re.sub(
            r"(?i)\b(authorization|api[_-]?key|access[_-]?token|password|secret)\b"
            r"(\s*[:=]\s*)(['\"]?)[^\s'\"`]+",
            r"\1\2\3[SECRET]",
            text,
        )
        text = redact_apple_developer_ids(text)
        text = re.sub(r"\b(?:\d{1,3}\.){3}\d{1,3}\b", redact_ip, text)
        text = re.sub(r"https?://[^\s)>\]]+", redact_url, text)

        for term in self.literal_terms:
            if not term or term in {"iQuit", "iquit"}:
                continue
            replacement = "[MACHINE]" if term in self.machine_terms else "[USER]"
            text = re.sub(re.escape(term), replacement, text, flags=re.IGNORECASE)
        return text


def collect_default_terms(project_root: Path) -> set[str]:
    terms = {getpass.getuser(), Path.home().name}
    try:
        gecos = pwd.getpwuid(os.getuid()).pw_gecos.split(",", 1)[0].strip()
        if gecos:
            terms.add(gecos)
            terms.add(gecos.replace(" ", ""))
    except KeyError:
        pass

    remote_owner = git_remote_owner(project_root)
    if remote_owner:
        terms.add(remote_owner)
    return {term for term in terms if term}


def collect_machine_terms() -> set[str]:
    hostname = socket.gethostname().split(".")[0].strip()
    if len(hostname) < 5 or hostname.lower() in {"local", "localhost"}:
        return set()
    return {hostname}


def git_remote_owner(project_root: Path) -> str | None:
    try:
        result = subprocess.run(
            ["git", "config", "--get", "remote.origin.url"],
            cwd=project_root,
            text=True,
            capture_output=True,
            check=False,
        )
    except OSError:
        return None
    remote = result.stdout.strip()
    if not remote:
        return None

    patterns = [
        r"github\.com[:/]([^/]+)/[^/]+(?:\.git)?$",
        r"git@[^:]+:([^/]+)/[^/]+(?:\.git)?$",
    ]
    for pattern in patterns:
        match = re.search(pattern, remote)
        if match:
            return match.group(1)
    return None


def redact_ip(match: re.Match[str]) -> str:
    ip = match.group(0)
    if ip.startswith(("127.", "10.", "192.168.")) or re.match(r"172\.(1[6-9]|2\d|3[01])\.", ip):
        return ip
    return "[IP_ADDRESS]"


def redact_apple_developer_ids(text: str) -> str:
    text = re.sub(
        r"(?i)(Developer ID Application:[^()\n]*\()[A-Z0-9]{10}(\))",
        r"\1[TEAM_ID]\2",
        text,
    )
    text = re.sub(
        r"(?i)(--team-id\s+['\"]?)[A-Z0-9]{10}(['\"]?)",
        r"\1[TEAM_ID]\2",
        text,
    )
    text = re.sub(
        r"(?i)(Team ID:\s*(?:already known as\s*)?`?)[A-Z0-9]{10}(`?)",
        r"\1[TEAM_ID]\2",
        text,
    )
    return text


def redact_url(match: re.Match[str]) -> str:
    url = match.group(0)
    split = urlsplit(url)
    if not split.query and not split.fragment:
        return url
    return urlunsplit((split.scheme, split.netloc, split.path, "[REDACTED_QUERY]", ""))


def render_session(session: SessionInfo, turns: list[Turn], redactor: Redactor) -> str:
    title = redactor.redact(session.title or "Untitled Codex session")
    cwd_values = ", ".join(redactor.redact(cwd) for cwd in session.cwd_values) or "unknown"
    source_path = redactor.redact(str(session.path))

    lines = [
        f"# {title}",
        "",
        f"- Session: `{session.session_id}`",
        f"- Source: `{session.source}`",
        f"- Started: `{session.started_at or 'unknown'}`",
        f"- CWD: `{cwd_values}`",
        f"- Source file: `{source_path}`",
        "",
    ]

    for index, turn in enumerate(turns, start=1):
        role = "User" if turn.role == "user" else "Assistant"
        timestamp = f" ({turn.timestamp})" if turn.timestamp else ""
        text = redactor.redact(turn.text).strip()
        lines.extend([f"## {index}. {role}{timestamp}", "", text, ""])

    return "\n".join(lines).rstrip() + "\n"


def slugify(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    value = value.strip("-")
    return value[:70] or "codex-session"


def write_outputs(sessions: list[SessionInfo], output_dir: Path, redactor: Redactor) -> None:
    sessions_dir = output_dir / "sessions"
    sessions_dir.mkdir(parents=True, exist_ok=True)

    rendered_sessions: list[tuple[SessionInfo, list[Turn], Path]] = []
    for session in sessions:
        turns = extract_turns(session.path)
        filename = f"{session.started_at[:10] if session.started_at else 'unknown'}-{session.session_id}-{slugify(session.title or 'session')}.md"
        output_path = sessions_dir / filename
        output_path.write_text(render_session(session, turns, redactor), encoding="utf-8")
        rendered_sessions.append((session, turns, output_path))

    write_index(rendered_sessions, output_dir, redactor)
    write_combined(rendered_sessions, output_dir, redactor)


def write_index(
    rendered_sessions: list[tuple[SessionInfo, list[Turn], Path]],
    output_dir: Path,
    redactor: Redactor,
) -> None:
    lines = [
        "# Codex iQuit Prompt Export",
        "",
        f"Generated: `{datetime.now(timezone.utc).isoformat(timespec='seconds')}`",
        "",
        "This folder contains sanitized Codex transcripts with only user and assistant turns. Tool calls, tool outputs, reasoning, system messages, developer messages, and environment-only context messages are omitted.",
        "",
        "| Session | Source | Started | Turns | File |",
        "| --- | --- | --- | ---: | --- |",
    ]
    for session, turns, path in rendered_sessions:
        title = redactor.redact(session.title or session.session_id)
        relative_path = path.relative_to(output_dir)
        lines.append(
            f"| `{session.session_id}` {title} | {session.source} | `{session.started_at or 'unknown'}` | {len(turns)} | [{relative_path}]({relative_path}) |"
        )
    lines.append("")
    (output_dir / "index.md").write_text("\n".join(lines), encoding="utf-8")


def write_combined(
    rendered_sessions: list[tuple[SessionInfo, list[Turn], Path]],
    output_dir: Path,
    redactor: Redactor,
) -> None:
    parts = [
        "# All iQuit Codex Prompts\n\n"
        "Sanitized transcript export containing only user and assistant turns.\n",
    ]
    for session, turns, _ in rendered_sessions:
        parts.append(render_session(session, turns, redactor))
    (output_dir / "all-iquit-codex-prompts.md").write_text("\n\n---\n\n".join(parts), encoding="utf-8")


def main() -> int:
    args = parse_args()
    codex_home = args.codex_home.expanduser().resolve()
    project_root = args.project_root.expanduser().resolve()
    output_dir = args.output_dir

    sessions = collect_matching_sessions(
        codex_home=codex_home,
        project_root=project_root,
        include_sessions=set(args.include_session or []),
    )
    redactor = Redactor(project_root=project_root, extra_terms=args.redact_term)
    write_outputs(sessions=sessions, output_dir=output_dir, redactor=redactor)

    archived_count = sum(1 for session in sessions if session.source == "archived")
    print(
        f"Exported {len(sessions)} sessions ({archived_count} archived) to {output_dir}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
