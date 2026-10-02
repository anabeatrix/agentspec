
### Analytics design

Load KB patterns only from the domains present under `.agentspec/kb/`; skip any other domain this skill names.

For every model in the file manifest, the DESIGN states:

| Item | Content |
|---|---|
| Grain | What one row represents |
| Primary key | The column or columns, and the test that proves uniqueness |
| Materialization | View, table, or incremental, with the incremental strategy and its key when used |
| Lineage | The sources and upstream models it reads, each traced to the DEFINE's source inventory |
| Tests | Uniqueness, not-null, relationships, accepted values, and one reconciliation against the number the user named in discovery |

If the DEFINE has no source inventory, or lists a grain, key, or metric definition as an open question, stop: the design cannot be completed. Report what is missing and name `@skills:sdd-define` or `@skills:sdd-iterate` as the next step.
