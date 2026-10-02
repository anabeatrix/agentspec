
### Phase 1 under Devin

- **Gap filling.** When the clarity score is below 12/15, send all gap questions in one numbered message, lowest-scoring elements first, and wait. If no answer comes, save the document as `Needs Clarification` and list what is missing; never invent entities to reach the gate.
- **Contract gate.** `.agentspec/tools/spec-linter/spec-lint` needs Python with `pydantic` and `pyyaml`. If it exits 2 because they are missing, report that the contract check did not run. Do not report a pass the linter did not return.
