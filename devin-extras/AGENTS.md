# AgentSpec

This repository uses AgentSpec, a Spec-Driven Development (SDD) workflow for data engineering. Features move through five phases, each producing a document the next phase consumes.

## Workflow

| Phase | Skill | Input | Output |
|---|---|---|---|
| 0 Brainstorm (optional) | `@skills:sdd-brainstorm` | An idea or rough notes | `.agentspec/sdd/features/BRAINSTORM_{FEATURE}.md` |
| 1 Define | `@skills:sdd-define` | A BRAINSTORM document, notes, or a request | `.agentspec/sdd/features/DEFINE_{FEATURE}.md` |
| 2 Design | `@skills:sdd-design` | The DEFINE document | `.agentspec/sdd/features/DESIGN_{FEATURE}.md` |
| 3 Build | `@skills:sdd-build` | The DESIGN document | Code and `.agentspec/sdd/reports/BUILD_REPORT_{FEATURE}.md` |
| 4 Ship | `@skills:sdd-ship` | The DEFINE document | `.agentspec/sdd/archive/{FEATURE}/SHIPPED_{DATE}.md` |
| Any | `@skills:sdd-iterate` | A phase document and the change | The updated document and confirmed cascades |

`@skills:sdd-workflow` explains the sequence and routes to the right phase.

When a request asks to build or change a feature and no phase is named, suggest the phase that fits and wait for the user to invoke it. A request written as `/define ...` or `!define ...` means `@skills:sdd-define`, and likewise for the other phases.

## Rules

1. **One phase per step.** Run the invoked phase, commit and push its documents, report, and stop. Do not start the next phase on your own.
2. **KB first.** Before recommending or writing anything in a domain, read `.agentspec/kb/_index.yaml` and the matching `.agentspec/kb/{domain}/` files. State the evidence behind each recommendation.
3. **Roles, not subagents.** `.agentspec/agents/{category}/{name}.md` describes a specialist. When a skill or a DESIGN manifest names one, read that file and apply it yourself.
4. **Templates and contracts are binding.** Documents follow `.agentspec/sdd/templates/`; phase transitions and statuses follow `.agentspec/sdd/architecture/WORKFLOW_CONTRACTS.yaml`.
5. **Never fabricate requirements.** When information is missing, ask in the session and wait.

## Layout

| Path | Contents |
|---|---|
| `.agents/skills/sdd-*/` | Phase methodology (skills) |
| `.agentspec/agents/` | Specialist roles, by category |
| `.agentspec/kb/` | Knowledge base domains |
| `.agentspec/sdd/templates/` | Phase document templates |
| `.agentspec/sdd/architecture/` | Workflow contracts and architecture |
| `.agentspec/sdd/features/`, `reports/`, `archive/` | This project's phase documents |
| `.agentspec/tools/spec-linter/` | Contract check for DEFINE and DESIGN documents |

Everything under `.agents/skills/sdd-*`, `.agentspec/agents/`, `.agentspec/kb/`, `.agentspec/sdd/templates/`, `.agentspec/sdd/architecture/`, and `.agentspec/tools/` is generated from AgentSpec. Do not edit it here; changes belong upstream.
