
### Phase 2 under Devin

- **Agent matching.** Assign `@agent-name` in the file manifest exactly as described; under Devin the name selects the role file the build phase will read, not a subagent.
- **Contract gate.** `.agentspec/tools/spec-linter/spec-lint` needs Python with `pydantic` and `pyyaml`. If it exits 2 because they are missing, report that the contract check did not run. Do not report a pass the linter did not return.
