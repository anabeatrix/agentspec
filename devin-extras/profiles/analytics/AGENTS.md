
## Analytics engineering rules

These rules apply to any work that creates or changes a data model: a dbt model, a SQL transformation, a schema, or a metric definition.

1. **No model without discovery and design.** Before writing or changing a model, a `DEFINE_{FEATURE}.md` with status `✅ Complete (Designed)` and a `DESIGN_{FEATURE}.md` with status `Ready for Build` must exist under `.agentspec/sdd/features/`. If either is missing, do not write the model: say which phase is missing, name the skill that runs it, and wait.
2. **Discovery covers the business and the tables.** The DEFINE records the business question, who consumes the result, the definition of every metric, and a profile of every source table. Assumed grain, keys, or metric definitions are open questions, not requirements.
3. **Design states the model's shape.** The DESIGN gives, for each model, its grain, primary key, materialization, upstream sources, and tests.
4. **Exemption.** A change that leaves grain, keys, joins, filters, and metric logic untouched (a description, formatting, a renamed alias with no downstream effect) may skip the phases. Say that you are using the exemption and why.

This bundle carries only the analytics KB domains (`dbt`, `sql-patterns`, `data-modeling`, `data-quality`) and roles. When a skill names a KB domain or a role that is not under `.agentspec/`, skip it and continue with what is present.
