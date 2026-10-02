
---

## Running under Devin

Everything above this line is the AgentSpec skill as written for Claude Code. Where it assumes a Claude Code capability, apply the substitution below; on any conflict, this section wins.

**Input for this run:** $ARGUMENTS

If the line above is empty or still shows a literal placeholder, take the input from the user's message.

| The skill says | Under Devin |
|---|---|
| Delegate to `@agent-name` via the Task tool or a subagent | There are no subagents. Read the role file `.agentspec/agents/{category}/{agent-name}.md`, apply its guidance yourself for that file, and record the attribution as `@agent-name (role)`. If that role file is not in the bundle, treat the row as `(general)`. |
| "The executor" or a `{phase}-agent` and its policies | Read `.agentspec/agents/workflow/{phase}-agent.md` before starting; its policies, stop conditions, and escalation rules bind you. Ignore its `tools`, `model`, and `color` frontmatter. |
| `AskUserQuestion` | Send a message in the session and wait for the reply. |
| `Read(...)`, `Write(...)`, `Glob`, `Grep` | Your own file, search, and shell tools. |
| Validate with MCP | Use an MCP server only if one is configured for this organization; otherwise check the official documentation on the web. If neither is possible, keep the lower confidence score and say so. |
| Suggest the next `@skills:sdd-...` step | Name the next skill and its argument in your final message; do not start the next phase on your own. |

Phase documents are the only state shared between sessions. Commit every document this phase creates or updates under `.agentspec/sdd/` to the working branch and push it, so the next phase can read it from a fresh session.

Only one skill is active at a time: finish this phase, report, and stop for review before another phase is invoked.
