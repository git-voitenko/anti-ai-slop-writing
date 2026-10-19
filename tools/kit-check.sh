#!/usr/bin/env bash
# tools/kit-check.sh — offline drift check of agent-kit managed files, AGENTS.md core block and .agent-kit.lock.
# Entry: bash tools/kit-check.sh [repo]; first step of tools/verify.sh; spec — agent-kit docs/architecture.md §kit-check.
set -euo pipefail
command -v python3 >/dev/null 2>&1 || { echo "kit-check: SKIP(python3): python3 not found"; exit 77; }
ROOT="$(git -C "${1:-.}" rev-parse --show-toplevel)"
exec python3 - "$ROOT" <<'PY'
import hashlib, json, os, re, subprocess, sys

ROOT = sys.argv[1]
LOCK = ".agent-kit.lock"
# Every profile carries these; dropping one from the lock is drift (agent-kit standard-contract).
REQUIRED = [
    "CLAUDE.md", "docs/code-style.md",
    ".agents/skills/linear/SKILL.md", ".agents/skills/linear/references/templates.md",
    ".agents/skills/verify/SKILL.md", ".claude/skills/linear", ".claude/skills/verify",
    ".claude/settings.json", ".claude/rules/code-style.md", ".codex/config.toml",
    "tools/kit-check.sh", "tools/main-checkout-ff.sh", "tools/hooks-install.sh",
    "hooks/pre-commit", "hooks/pre-push", ".github/workflows/verify.yml",
]
NO_FULL_PROFILES = {"skill"}
ALLOWED_SECTIONS = ["Проект", "Порядок чтения", "Проверки", "Выпуск", "Секреты", "Правила проекта"]
BEGIN_RE = re.compile(r"^<!-- agent-kit:core begin v(\S+) -->$")
END_LINE = "<!-- agent-kit:core end -->"
ATX_RE = re.compile(r"^ {0,3}(#{1,2})(?:[ \t]+(.*)|[ \t]*)$")
SETEXT_RE = re.compile(r"^ {0,3}(=+|-+)[ \t]*$")
LIST_OR_QUOTE_RE = re.compile(r"^\s*([-*+]|\d+[.)])(\s|$)|^\s*>|^\s*\|")
FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
INDENTED_CODE_RE = re.compile(r"^    ")
GI_BEGIN, GI_END = "# agent-kit:gitignore begin", "# agent-kit:gitignore end"
problems = []


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def entry_hash(path):
    full = os.path.join(ROOT, path)
    if os.path.islink(full):
        return "symlink:" + os.readlink(full)
    if not os.path.isfile(full):
        return None
    with open(full, "rb") as fh:
        return sha256(fh.read())


def git(*args):
    res = subprocess.run(["git", "-C", ROOT] + list(args), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return res.returncode, res.stdout.decode("utf-8", "replace").strip()


def read_text(path):
    with open(os.path.join(ROOT, path), "rb") as fh:
        return fh.read().decode("utf-8")


def check_lock_shape(lock):
    for key, kind in (("version", str), ("source_sha", str), ("profile", str), ("core_sha256", str),
                      ("files", dict), ("blocks", dict)):
        if not isinstance(lock.get(key), kind) or not lock.get(key):
            problems.append("lock: field '%s' is missing or empty" % key)
    if problems:
        return False
    if not re.match(r"^\d+\.\d+\.\d+$", lock["version"]):
        problems.append("lock: version '%s' is not semver" % lock["version"])
    if not re.match(r"^[0-9a-f]{7,40}$", lock["source_sha"]):
        problems.append("lock: source_sha '%s' is not a git SHA" % lock["source_sha"])
    return True


def check_files(lock):
    required = list(REQUIRED)
    if lock["profile"] not in NO_FULL_PROFILES:
        required.append(".github/workflows/verify-full.yml")
    for path in required:
        if path not in lock["files"]:
            problems.append("managed: %s is required but missing from the lock" % path)
    for path, expected in sorted(lock["files"].items()):
        if os.path.isabs(path) or ".." in path.split("/") or not path:
            problems.append("lock: path %r escapes the repository" % path)
            continue
        actual = entry_hash(path)
        if actual is None:
            problems.append("managed: %s is missing" % path)
        elif actual != expected:
            problems.append("managed: %s differs from the lock (edited outside kit-sync)" % path)


def split_agents(lock):
    if not os.path.isfile(os.path.join(ROOT, "AGENTS.md")):
        problems.append("AGENTS.md: missing")
        return None
    lines = read_text("AGENTS.md").split("\n")
    begins = [i for i, line in enumerate(lines) if BEGIN_RE.match(line)]
    ends = [i for i, line in enumerate(lines) if line == END_LINE]
    if len(begins) != 1 or len(ends) != 1 or begins[0] > ends[0]:
        problems.append("AGENTS.md: expected exactly one core begin marker followed by one end marker")
        return None
    b, e = begins[0], ends[0]
    marker_version = BEGIN_RE.match(lines[b]).group(1)
    if marker_version != lock["version"]:
        problems.append("AGENTS.md: core marker v%s != lock version %s" % (marker_version, lock["version"]))
    core = "\n".join(lines[b + 1:e]) + "\n"
    if sha256(core.encode("utf-8")) != lock["core_sha256"]:
        problems.append("AGENTS.md: core block differs from the lock (core is edited only in agent-kit)")
    return lines[:b], lines[e + 1:]


def outside_fences(lines):
    """Yields (line, in_code): a fence closes only with the same char and at least the opening length (CommonMark)."""
    fence = None
    for line in lines:
        m = FENCE_RE.match(line)
        # A backtick fence whose info string contains a backtick is not a fence (CommonMark 4.5).
        if m and m.group(1)[0] == "`" and "`" in m.group(2):
            m = None
        if fence is None and m:
            fence = (m.group(1)[0], len(m.group(1)))
            yield line, True
            continue
        if fence is not None:
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= fence[1] and not m.group(2).strip():
                fence = None
            yield line, True
            continue
        yield line, False


def atx_title(heading):
    text = (heading.group(2) or "").strip()
    # Only a closing run of '#' preceded by a space (or the whole text) is decoration; '## Title#' keeps its '#'.
    return re.sub(r"(^|\s+)#+$", "", text).strip()


def check_project_block(head, tail):
    h1 = 0
    for line, code in outside_fences(head):
        if code or not line.strip() or line.lstrip().startswith(">"):
            continue
        heading = ATX_RE.match(line)
        if heading and heading.group(1) == "#":
            h1 += 1
            continue
        problems.append("AGENTS.md: text before the core block is not allowed: %r" % line[:60])
    if h1 > 1:
        problems.append("AGENTS.md: more than one H1 before the core block")
    section, paragraph = None, ""
    for line, code in outside_fences(tail):
        heading = None if code else ATX_RE.match(line)
        if heading:
            title = atx_title(heading) if heading.group(1) == "##" else None
            if title not in ALLOWED_SECTIONS:
                problems.append("AGENTS.md: section %r is not allowed in the project block" % line.strip())
            section, paragraph = title, ""
            continue
        # A setext underline turns an open paragraph into an H1/H2 that the ATX check would not see.
        if not code and paragraph and SETEXT_RE.match(line):
            problems.append("AGENTS.md: setext heading %r is not allowed in the project block" % paragraph.strip())
            paragraph = ""
        elif code or not line.strip() or LIST_OR_QUOTE_RE.match(line) or SETEXT_RE.match(line):
            paragraph = ""
        elif paragraph or not INDENTED_CODE_RE.match(line.expandtabs(4)):
            paragraph = paragraph or line
        if section is None and line.strip():
            problems.append("AGENTS.md: project text outside an allowed section: %r" % line[:60])


def check_gitignore(lock):
    expected = lock["blocks"].get(".gitignore")
    if not expected:
        problems.append("lock: blocks['.gitignore'] is missing")
        return
    if not os.path.isfile(os.path.join(ROOT, ".gitignore")):
        problems.append(".gitignore: missing")
        return
    lines = read_text(".gitignore").split("\n")
    if lines.count(GI_BEGIN) != 1 or lines.count(GI_END) != 1 or lines.index(GI_BEGIN) > lines.index(GI_END):
        problems.append(".gitignore: expected one agent-kit block")
        return
    body = "\n".join(lines[lines.index(GI_BEGIN) + 1:lines.index(GI_END)]) + "\n"
    if sha256(body.encode("utf-8")) != expected:
        problems.append(".gitignore: agent-kit block differs from the lock")


def check_history(lock):
    if os.environ.get("KIT_CHECK_NO_HISTORY") == "1":
        return "history: skipped (KIT_CHECK_NO_HISTORY=1)"
    base = os.environ.get("KIT_CHECK_BASE", "origin/main")
    code, _ = git("rev-parse", "--verify", "-q", base + "^{commit}")
    if code != 0:
        # CI must see the base, otherwise "lock + file" edits would pass unnoticed (verify.yml fetch-depth: 0).
        if os.environ.get("GITHUB_ACTIONS") == "true":
            problems.append("history: base %s is not available in CI" % base)
        return "history: skipped (no %s)" % base
    code, mb = git("merge-base", base, "HEAD")
    if code != 0:
        problems.append("history: no merge-base between %s and HEAD" % base)
        return ""
    code, old_text = git("show", "%s:%s" % (mb, LOCK))
    if code != 0:
        return "history: no lock at base (first adoption)"
    try:
        old = json.loads(old_text)
    except ValueError:
        return "history: base lock unreadable, skipped"
    changed = [k for k in ("files", "blocks", "core_sha256", "profile") if old.get(k) != lock.get(k)]
    if old.get("version") == lock["version"]:
        if changed:
            problems.append("history: lock %s changed without a version bump (only kit-sync of a new kit version may change it)"
                            % ", ".join(changed))
    elif old.get("source_sha") == lock["source_sha"]:
        problems.append("history: version changed but source_sha did not")
    return "history: compared with %s" % base


def main():
    path = os.path.join(ROOT, LOCK)
    if not os.path.isfile(path):
        print("kit-check: FAIL\n  - %s is missing (run agent-kit bin/kit-sync.sh)" % LOCK)
        return 1
    try:
        with open(path, "rb") as fh:
            lock = json.loads(fh.read().decode("utf-8"))
    except ValueError as exc:
        print("kit-check: FAIL\n  - %s is not valid JSON: %s" % (LOCK, exc))
        return 1
    if not isinstance(lock, dict) or not check_lock_shape(lock):
        print("kit-check: FAIL\n" + "\n".join("  - " + p for p in problems))
        return 1
    check_files(lock)
    parts = split_agents(lock)
    if parts:
        check_project_block(*parts)
    check_gitignore(lock)
    note = check_history(lock)
    if problems:
        print("kit-check: FAIL (%d)" % len(problems))
        print("\n".join("  - " + p for p in problems))
        return 1
    print("kit-check: OK (agent-kit v%s, profile %s, %d managed files; %s)"
          % (lock["version"], lock["profile"], len(lock["files"]), note))
    return 0


sys.exit(main())
PY
