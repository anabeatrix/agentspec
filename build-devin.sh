#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# AgentSpec Devin Builder
# =============================================================================
# Packages .claude/ (source of truth) into devin/ — a bundle a repository can
# adopt to run the SDD workflow under Devin. MVP scope: the sdd-* skills, the
# agents (as role files), the KB, the SDD templates/contracts, and spec-linter.
#
# Layout of the bundle (mirrors what Devin reads in a target repository):
#   AGENTS.md                 always-on context (Devin loads it automatically)
#   .agents/skills/sdd-*/     phase skills (Devin's recommended skill path)
#   .agentspec/               roles, KB, SDD templates/contracts, tools, workspace
#
# Usage:
#   ./build-devin.sh                      # Build the full bundle into ./devin
#   ./build-devin.sh --profile analytics  # Build a lean bundle (devin-extras/profiles/)
#   ./build-devin.sh --output DIR         # Build into DIR
#   ./build-devin.sh --help               # Show this help
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/.claude"
EXTRAS_DIR="${SCRIPT_DIR}/devin-extras"
OUT_DIR="${SCRIPT_DIR}/devin"
PROFILE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
ok()    { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

# Cleanup trap for interrupted builds
cleanup() {
    [[ -d "${OUT_DIR}" ]] && find "${OUT_DIR}" -name "*.tmp" -type f -delete 2>/dev/null || true
}
trap cleanup EXIT

# ─── Arguments ───────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            cat <<'EOF'
AgentSpec Devin Builder

Packages .claude/ (source of truth) into a bundle for Devin: the SDD phase
skills, specialist roles, KB, templates, contracts, and the spec-linter.
Rewrites .claude/ paths to the bundle layout and appends devin-extras/overlays.

A profile (devin-extras/profiles/NAME/) narrows the bundle to the KB domains
and roles one kind of team needs, and adds its own rules and overlays.

Usage:
  ./build-devin.sh                      Build the full bundle into ./devin
  ./build-devin.sh --profile NAME       Build a lean bundle for one profile
  ./build-devin.sh --output DIR         Build into DIR
  ./build-devin.sh --help               Show this help

Output: devin/ — see devin/README.md for installing it into a repository.
EOF
            exit 0
            ;;
        --output)
            if [[ -z "${2:-}" ]]; then
                error "--output needs a directory"
                exit 1
            fi
            OUT_DIR="$2"
            shift 2
            ;;
        --profile)
            if [[ -z "${2:-}" ]]; then
                error "--profile needs a name"
                exit 1
            fi
            PROFILE="$2"
            shift 2
            ;;
        *)
            error "Unknown argument: $1 (see --help)"
            exit 1
            ;;
    esac
done

# ─── Preflight ───────────────────────────────────────────────────────────────

if [[ ! -d "${SOURCE_DIR}" ]]; then
    error ".claude/ directory not found at ${SOURCE_DIR}"
    exit 1
fi

if [[ ! -d "${EXTRAS_DIR}/overlays" ]] || [[ ! -f "${EXTRAS_DIR}/AGENTS.md" ]]; then
    error "devin-extras/ is incomplete (needs AGENTS.md and overlays/)"
    exit 1
fi

PROFILE_DIR=""
if [[ -n "${PROFILE}" ]]; then
    PROFILE_DIR="${EXTRAS_DIR}/profiles/${PROFILE}"
    if [[ ! -f "${PROFILE_DIR}/kb.txt" ]] || [[ ! -f "${PROFILE_DIR}/agents.txt" ]]; then
        error "Profile '${PROFILE}' not found (needs ${PROFILE_DIR}/kb.txt and agents.txt)"
        exit 1
    fi
fi

# The clean step below deletes .agentspec/ wholesale, which in an adopted
# repository holds that project's phase documents. Building straight into a
# repository is therefore refused — build the bundle, then copy it in.
if [[ -e "${OUT_DIR}/.git" ]]; then
    error "${OUT_DIR} is a git repository — build into a scratch directory and copy the bundle in"
    exit 1
fi

mkdir -p "${OUT_DIR}"
OUT_DIR="$(cd "${OUT_DIR}" && pwd)"
SKILLS_DIR="${OUT_DIR}/.agents/skills"
SPEC_DIR="${OUT_DIR}/.agentspec"

info "Building AgentSpec Devin bundle from .claude/ (profile: ${PROFILE:-full}) ..."

# ─── Step 1: Clean previous build ────────────────────────────────────────────

info "Cleaning previous build..."
rm -rf "${OUT_DIR:?}/.agents" "${OUT_DIR:?}/.agentspec"
rm -f "${OUT_DIR:?}/AGENTS.md" "${OUT_DIR:?}/README.md"
ok "Previous build cleaned"

# ─── Step 2: Copy components ─────────────────────────────────────────────────

info "Copying SDD skills..."
mkdir -p "${SKILLS_DIR}"
SDD_SKILLS=(sdd-workflow sdd-brainstorm sdd-define sdd-design sdd-build sdd-ship sdd-iterate)
for skill in "${SDD_SKILLS[@]}"; do
    if [[ ! -f "${SOURCE_DIR}/skills/${skill}/SKILL.md" ]]; then
        error "Missing skill: .claude/skills/${skill}/SKILL.md"
        exit 1
    fi
    cp -r "${SOURCE_DIR}/skills/${skill}" "${SKILLS_DIR}/${skill}"
done

info "Copying agents as role files..."
mkdir -p "${SPEC_DIR}"
cp -r "${SOURCE_DIR}/agents" "${SPEC_DIR}/agents"

# Same exclusions as build-plugin.sh: contributor scaffolding and the
# repo-local agent that depends on files the bundle does not carry.
find "${SPEC_DIR}/agents" -name '_template.md' -delete 2>/dev/null || true
REPO_LOCAL_AGENTS=(architect/agent-architect.md)
for agent in "${REPO_LOCAL_AGENTS[@]}"; do
    rm -rf "${SPEC_DIR:?}/agents/${agent}"
done

info "Copying KB domains..."
cp -r "${SOURCE_DIR}/kb" "${SPEC_DIR}/kb"

info "Copying SDD templates and architecture..."
mkdir -p "${SPEC_DIR}/sdd"
cp -r "${SOURCE_DIR}/sdd/templates" "${SPEC_DIR}/sdd/templates"
cp -r "${SOURCE_DIR}/sdd/architecture" "${SPEC_DIR}/sdd/architecture"
[[ -f "${SOURCE_DIR}/sdd/_index.md" ]] && cp "${SOURCE_DIR}/sdd/_index.md" "${SPEC_DIR}/sdd/"
[[ -f "${SOURCE_DIR}/sdd/README.md" ]] && cp "${SOURCE_DIR}/sdd/README.md" "${SPEC_DIR}/sdd/"

# Workspace directories: Devin has no SessionStart hook to create them, so the
# bundle ships them empty.
for dir in features reports archive; do
    mkdir -p "${SPEC_DIR}/sdd/${dir}"
    : > "${SPEC_DIR}/sdd/${dir}/.gitkeep"
done

# The Define, Design, and Iterate skills run the contract gate through the
# spec-linter. Copy-then-prune, as in build-plugin.sh.
if [[ -d "${SCRIPT_DIR}/tools/spec-linter" ]]; then
    info "Copying spec-linter tool..."
    mkdir -p "${SPEC_DIR}/tools"
    cp -r "${SCRIPT_DIR}/tools/spec-linter" "${SPEC_DIR}/tools/spec-linter"
    rm -rf "${SPEC_DIR}/tools/spec-linter/.venv"
    rm -rf "${SPEC_DIR}/tools/spec-linter/tests"
    find "${SPEC_DIR}/tools/spec-linter" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
    find "${SPEC_DIR}/tools/spec-linter" -name '.pytest_cache' -type d -exec rm -rf {} + 2>/dev/null || true
    find "${SPEC_DIR}/tools/spec-linter" -name '.ruff_cache' -type d -exec rm -rf {} + 2>/dev/null || true
    find "${SPEC_DIR}/tools/spec-linter" -name '*.egg-info' -type d -exec rm -rf {} + 2>/dev/null || true
else
    warn "tools/spec-linter not found — the contract gate will be unavailable in the bundle"
fi

ok "All components copied"

# ─── Step 2b: Apply the profile ──────────────────────────────────────────────
# A profile keeps only the KB domains in kb.txt (plus shared/ and _templates/)
# and the roles in agents.txt (plus the workflow/ phase agents), and filters
# the KB index to match so the skills never discover a domain that is absent.

read_list() {
    # Prints the entries of a profile list: no comments, blanks, or CRs.
    tr -d '' < "$1" | grep -vE '^[[:space:]]*(#|$)' || true
}

if [[ -n "${PROFILE_DIR}" ]]; then
    info "Applying profile '${PROFILE}'..."

    KEEP_KB="$(read_list "${PROFILE_DIR}/kb.txt")"
    while IFS= read -r domain; do
        if [[ ! -d "${SPEC_DIR}/kb/${domain}" ]]; then
            error "Profile '${PROFILE}' lists an unknown KB domain: ${domain}"
            exit 1
        fi
    done <<< "${KEEP_KB}"
    for dir in "${SPEC_DIR}/kb"/*/; do
        name="$(basename "${dir}")"
        case "${name}" in
            shared|_templates) continue ;;
        esac
        grep -qxF "${name}" <<< "${KEEP_KB}" || rm -rf "${dir}"
    done
    rm -f "${SPEC_DIR}/kb/README.md"

    awk -v keep="$(tr '
' ' ' <<< "${KEEP_KB}")" '
        BEGIN { n = split(keep, names, " "); for (i = 1; i <= n; i++) kept[names[i]] = 1 }
        /^# Domain Registry/ { print "# Domain Registry — filtered to the build profile"; next }
        /^domains:/ { in_domains = 1; print; next }
        !in_domains { print; next }
        /^  #/ { on = 0; next }
        /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
            name = $1; sub(/:.*/, "", name)
            on = (name in kept)
            if (on) print ""
        }
        on && !/^[[:space:]]*$/ { print }
    ' "${SPEC_DIR}/kb/_index.yaml" > "${SPEC_DIR}/kb/_index.yaml.tmp"
    mv "${SPEC_DIR}/kb/_index.yaml.tmp" "${SPEC_DIR}/kb/_index.yaml"

    KEEP_AGENTS="$(read_list "${PROFILE_DIR}/agents.txt")"
    while IFS= read -r agent; do
        if [[ ! -f "${SPEC_DIR}/agents/${agent}.md" ]]; then
            error "Profile '${PROFILE}' lists an unknown agent: ${agent}"
            exit 1
        fi
    done <<< "${KEEP_AGENTS}"
    while IFS= read -r -d '' file; do
        rel="${file#"${SPEC_DIR}/agents/"}"
        rel="${rel%.md}"
        case "${rel}" in
            workflow/*) continue ;;
        esac
        grep -qxF "${rel}" <<< "${KEEP_AGENTS}" || rm -f "${file}"
    done < <(find "${SPEC_DIR}/agents" -name '*.md' -type f -print0)
    find "${SPEC_DIR}/agents" -type d -empty -delete

    ok "Profile applied"
fi

# ─── Step 3: Path rewriting ──────────────────────────────────────────────────
#
# Applied to every .md/.yaml/.yml/.json file in the bundle:
#   .claude/commands/workflow/{phase}.md → @skills:sdd-{phase}   (commands are not shipped)
#   .claude/skills/                      → .agents/skills/
#   .claude/CLAUDE.md                    → AGENTS.md
#   tools/spec-linter/                   → .agentspec/tools/spec-linter/
#   .claude/                             → .agentspec/           (everything else, workspace included)
#
# Order matters: the specific rules must run before the generic .claude/ rule.
# ─────────────────────────────────────────────────────────────────────────────

PHASES='brainstorm|define|design|build|ship|iterate'

rewrite() {
    # rewrite <grep-pattern> <dir>... -- <sed args>...
    # Runs sed only over files matching the grep pattern (keeps the build fast).
    local pattern="$1"; shift
    local -a dirs=()
    while [[ "$1" != "--" ]]; do dirs+=("$1"); shift; done
    shift
    local file tmp
    while IFS= read -r -d '' file; do
        tmp="${file}.tmp"
        sed -E "$@" "$file" > "$tmp" && mv "$tmp" "$file" || { rm -f "$tmp"; exit 1; }
    done < <(grep -rlE --null "${pattern}" "${dirs[@]}" \
        --include="*.md" --include="*.yaml" --include="*.yml" --include="*.json" || true)
}

info "Rewriting paths..."
rewrite '\.claude/|tools/spec-linter/' "${SKILLS_DIR}" "${SPEC_DIR}" -- \
    -e "s#\.claude/commands/workflow/(${PHASES})\.md#@skills:sdd-\1#g" \
    -e 's#\.claude/skills/#.agents/skills/#g' \
    -e 's#\.claude/CLAUDE\.md#AGENTS.md#g' \
    -e 's#tools/spec-linter/#.agentspec/tools/spec-linter/#g' \
    -e 's#\.claude/#.agentspec/#g'
ok "Paths rewritten"

# ─── Step 4: Vocabulary rewriting ────────────────────────────────────────────
#
# Applied to skills, roles, and SDD documents only (KB and tools are left
# alone — they are reference content, not workflow instructions):
#   CLAUDE.md                  → AGENTS.md
#   /define, /agentspec:define → @skills:sdd-define   (and the other phases)
#
# The slash rule runs twice: a match consumes its trailing delimiter, so two
# commands separated by a single character need a second pass.
# ─────────────────────────────────────────────────────────────────────────────

info "Rewriting commands to skill invocations..."
SLASH_RULE="s#(^|[^A-Za-z0-9_./:-])/(agentspec:)?(${PHASES})([^A-Za-z0-9_/.-]|\.[^A-Za-z0-9]|\.?\$)#\1@skills:sdd-\3\4#g"
rewrite "CLAUDE\.md|/(agentspec:)?(${PHASES})" \
    "${SKILLS_DIR}" "${SPEC_DIR}/agents" "${SPEC_DIR}/sdd" -- \
    -e 's#CLAUDE\.md#AGENTS.md#g' \
    -e "${SLASH_RULE}" \
    -e "${SLASH_RULE}"
ok "Commands rewritten"

# ─── Step 5: Append Devin overlays to the skills ─────────────────────────────
# Overlays are written in bundle vocabulary and appended after the rewrite so
# they are never rewritten themselves. _common.md goes on every skill; a
# {skill}.md overlay, when present, follows it, then the profile's own.

info "Appending Devin overlays..."
for skill in "${SDD_SKILLS[@]}"; do
    cat "${EXTRAS_DIR}/overlays/_common.md" >> "${SKILLS_DIR}/${skill}/SKILL.md"
    if [[ -f "${EXTRAS_DIR}/overlays/${skill}.md" ]]; then
        cat "${EXTRAS_DIR}/overlays/${skill}.md" >> "${SKILLS_DIR}/${skill}/SKILL.md"
    fi
    if [[ -n "${PROFILE_DIR}" ]] && [[ -f "${PROFILE_DIR}/overlays/${skill}.md" ]]; then
        cat "${PROFILE_DIR}/overlays/${skill}.md" >> "${SKILLS_DIR}/${skill}/SKILL.md"
    fi
done

cp "${EXTRAS_DIR}/AGENTS.md" "${OUT_DIR}/AGENTS.md"
if [[ -n "${PROFILE_DIR}" ]] && [[ -f "${PROFILE_DIR}/AGENTS.md" ]]; then
    cat "${PROFILE_DIR}/AGENTS.md" >> "${OUT_DIR}/AGENTS.md"
fi
[[ -f "${EXTRAS_DIR}/README.md" ]] && cp "${EXTRAS_DIR}/README.md" "${OUT_DIR}/README.md"

# Restore the executable bit lost on the wrapper when the tree was copied
chmod +x "${SPEC_DIR}/tools/spec-linter/spec-lint" 2>/dev/null || true

ok "Overlays appended"

# ─── Step 6: Verify ──────────────────────────────────────────────────────────
# 6a. No Claude Code path may survive in the workflow layer.
# 6b. Every bundle path the workflow layer references must exist in the bundle.
#     The workflow layer (skills, AGENTS.md, phase roles) fails the build; the
#     rest (specialist roles, KB, SDD docs) only warns — those still mention
#     components outside the MVP.

info "Verifying bundle..."

CORE_PATHS=("${SKILLS_DIR}" "${OUT_DIR}/AGENTS.md" "${SPEC_DIR}/agents/workflow")

STALE_OUTPUT=$(grep -rnE '\.claude/|CLAUDE_PLUGIN_ROOT' "${CORE_PATHS[@]}" || true)
if [[ -n "${STALE_OUTPUT}" ]]; then
    error "Claude Code paths survived in the workflow layer:"
    printf '%s\n' "${STALE_OUTPUT}" | head -20 >&2
    exit 1
fi

# AGENTS.md is truncated by Devin past 16 KiB
AGENTS_BYTES=$(wc -c < "${OUT_DIR}/AGENTS.md" | tr -d ' ')
if [[ "${AGENTS_BYTES}" -gt 16384 ]]; then
    error "AGENTS.md is ${AGENTS_BYTES} bytes — Devin loads only the first 16384"
    exit 1
fi

dangling_refs() {
    # Prints every bundle path referenced under the given paths that does not
    # exist in the bundle. Workspace paths (written at run time) are skipped;
    # a reference cut short by a placeholder is checked up to its directory.
    local ref
    while IFS= read -r ref; do
        case "${ref}" in
            *'{'|*'*'|*'<'|*'$')
                ref="${ref%?}"
                ref="${ref%/*}"
                ;;
            *___)
                ref="${ref%/*}"
                ;;
        esac
        while [[ "${ref}" == *. ]] || [[ "${ref}" == */ ]]; do ref="${ref%?}"; done
        case "${ref}" in
            .agentspec/sdd/features*|.agentspec/sdd/reports*|.agentspec/sdd/archive*) continue ;;
            .agentspec/sdd/specs*|.agentspec/sdd/drafts*|.agentspec/sdd/.detected-stack*) continue ;;
            .agentspec/storage*|.agentspec|.agents) continue ;;
        esac
        [[ -e "${OUT_DIR}/${ref}" ]] || printf '%s\n' "${ref}"
    done < <(grep -rhoE '(\.agentspec|\.agents)/[A-Za-z0-9_./-]*[{*<$]?' "$@" \
        --include="*.md" --include="*.yaml" --include="*.yml" 2>/dev/null | sort -u)
}

CORE_DANGLING=$(dangling_refs "${CORE_PATHS[@]}")
if [[ -n "${CORE_DANGLING}" ]]; then
    error "The workflow layer references paths missing from the bundle:"
    printf '%s\n' "${CORE_DANGLING}" >&2
    exit 1
fi
ok "Workflow layer is self-contained"

OTHER_DANGLING=$(dangling_refs "${SPEC_DIR}/agents" "${SPEC_DIR}/kb" "${SPEC_DIR}/sdd")
OTHER_COUNT=$(printf '%s' "${OTHER_DANGLING}" | grep -c '.' || true)
if [[ "${OTHER_COUNT}" -gt 0 ]]; then
    warn "${OTHER_COUNT} references outside the MVP scope (roles, KB, SDD docs) point at paths not in the bundle:"
    printf '%s\n' "${OTHER_DANGLING}" | head -20
fi

# ─── Step 7: Summary ─────────────────────────────────────────────────────────

SKILL_COUNT=$(find "${SKILLS_DIR}" -name "SKILL.md" | wc -l | tr -d ' ')
ROLE_COUNT=$(find "${SPEC_DIR}/agents" -name "*.md" -not -name "README.md" | wc -l | tr -d ' ')
KB_COUNT=$(find "${SPEC_DIR}/kb" -mindepth 1 -maxdepth 1 -type d ! -name "_templates" | wc -l | tr -d ' ')
if [[ -x "${SPEC_DIR}/tools/spec-linter/spec-lint" ]]; then
    LINTER_STATUS="bundled"
else
    LINTER_STATUS="not bundled"
fi

echo ""
echo "============================================"
printf "${GREEN}AgentSpec Devin Build Complete${NC}\n"
echo "============================================"
echo "  Profile:  ${PROFILE:-full}"
echo "  Skills:   ${SKILL_COUNT}"
echo "  Roles:    ${ROLE_COUNT}"
echo "  KB:       ${KB_COUNT} domains"
echo "  Linter:   ${LINTER_STATUS}"
echo ""
echo "  Output:   ${OUT_DIR}/"
echo ""
echo "  Install:  see ${OUT_DIR}/README.md"
echo "============================================"
