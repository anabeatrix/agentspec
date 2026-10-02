"""Tests for build-devin.sh: the bundle it produces must be self-contained."""
from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = REPO_ROOT / "build-devin.sh"
SDD_SKILLS = (
    "sdd-workflow",
    "sdd-brainstorm",
    "sdd-define",
    "sdd-design",
    "sdd-build",
    "sdd-ship",
    "sdd-iterate",
)

pytestmark = pytest.mark.skipif(shutil.which("bash") is None, reason="bash not available")


def _build(output: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", SCRIPT.name, "--output", output.as_posix(), *args],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )


@pytest.fixture(scope="module")
def bundle(tmp_path_factory: pytest.TempPathFactory) -> Path:
    output = tmp_path_factory.mktemp("devin")
    result = _build(output)
    assert result.returncode == 0, result.stdout + result.stderr
    return output


def test_bundle_layout(bundle: Path) -> None:
    assert (bundle / "AGENTS.md").is_file()
    assert (bundle / ".agentspec" / "kb" / "_index.yaml").is_file()
    assert (bundle / ".agentspec" / "sdd" / "templates" / "DEFINE_TEMPLATE.md").is_file()
    assert (bundle / ".agentspec" / "agents" / "workflow" / "build-agent.md").is_file()
    for skill in SDD_SKILLS:
        assert (bundle / ".agents" / "skills" / skill / "SKILL.md").is_file()


def test_skills_carry_no_claude_code_vocabulary(bundle: Path) -> None:
    slash_command = re.compile(r"(?<![\w./:-])/(agentspec:)?(brainstorm|define|design|build|ship|iterate)(?![\w/-])")
    for skill in SDD_SKILLS:
        text = (bundle / ".agents" / "skills" / skill / "SKILL.md").read_text(encoding="utf-8")
        assert ".claude/" not in text
        assert "CLAUDE.md" not in text
        assert not slash_command.search(text), f"{skill} still has a slash command"


def test_skills_end_with_devin_overlay(bundle: Path) -> None:
    for skill in SDD_SKILLS:
        text = (bundle / ".agents" / "skills" / skill / "SKILL.md").read_text(encoding="utf-8")
        assert text.startswith("---"), f"{skill} lost its frontmatter"
        assert "## Running under Devin" in text


def test_repo_local_agents_excluded(bundle: Path) -> None:
    agents = bundle / ".agentspec" / "agents"
    assert not (agents / "_template.md").exists()
    assert not (agents / "architect" / "agent-architect.md").exists()


@pytest.fixture(scope="module")
def analytics_bundle(tmp_path_factory: pytest.TempPathFactory) -> Path:
    output = tmp_path_factory.mktemp("devin-analytics")
    result = _build(output, "--profile", "analytics")
    assert result.returncode == 0, result.stdout + result.stderr
    return output


def test_profile_keeps_only_listed_kb_and_roles(analytics_bundle: Path) -> None:
    kb = analytics_bundle / ".agentspec" / "kb"
    domains = {path.name for path in kb.iterdir() if path.is_dir()}
    assert domains == {"dbt", "sql-patterns", "data-modeling", "data-quality", "cloud-platforms", "shared", "_templates"}

    agents = analytics_bundle / ".agentspec" / "agents"
    assert (agents / "data-engineering" / "dbt-specialist.md").is_file()
    assert (agents / "workflow" / "define-agent.md").is_file()
    assert not (agents / "data-engineering" / "spark-engineer.md").exists()
    assert not (agents / "platform").exists()


def test_profile_filters_the_kb_index(analytics_bundle: Path) -> None:
    index = (analytics_bundle / ".agentspec" / "kb" / "_index.yaml").read_text(encoding="utf-8")
    registry = index.split("\ndomains:", 1)[1]
    listed = set(re.findall(r"^  ([a-z0-9-]+):\s*$", registry, flags=re.MULTILINE))
    assert listed == {"dbt", "sql-patterns", "data-modeling", "data-quality", "cloud-platforms"}


def test_profile_adds_its_rules_and_overlays(analytics_bundle: Path) -> None:
    agents_md = (analytics_bundle / "AGENTS.md").read_text(encoding="utf-8")
    assert "## Analytics engineering rules" in agents_md
    define = (analytics_bundle / ".agents" / "skills" / "sdd-define" / "SKILL.md").read_text(encoding="utf-8")
    assert define.index("## Running under Devin") < define.index("### Analytics discovery")


def test_unknown_profile_is_rejected(tmp_path: Path) -> None:
    result = _build(tmp_path, "--profile", "does-not-exist")
    assert result.returncode == 1


def test_refuses_to_build_into_a_git_repository(tmp_path: Path) -> None:
    (tmp_path / ".git").mkdir()
    result = _build(tmp_path)
    assert result.returncode == 1
    assert not (tmp_path / ".agentspec").exists()
