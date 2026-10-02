
### Analytics discovery

For any feature that creates or changes a data model, complete both discoveries before scoring clarity. They feed the DEFINE's problem statement, success criteria, and "Data Contract" section.

**Business context.** Ask the user, in one message, whatever the input does not already answer:

- Which decision or question does this model serve, and who consumes it (dashboard, report, another model, a person)?
- How is each metric defined, in the business's words: what counts, what is excluded, which date it is attributed to?
- What is one row of the result (the grain), and over which period and time zone?
- Which numbers will the user compare it against to trust it (an existing report, a finance figure)?

**Source tables.** For every source the model will read, record in the source inventory:

| Item | How to establish it |
|---|---|
| Location and owner | The dbt `sources` definition or the catalog |
| Grain and primary key | Query for duplicates on the candidate key |
| Volume and freshness | Row count and the latest load or event timestamp |
| Columns used | Type, null rate, and distinct values for status or category columns |
| Join keys | Cardinality of each join (one-to-one, one-to-many) and the share of unmatched rows |

Run the queries when the session has warehouse access. When it does not, read what the repository holds (source YAML, existing models, documentation), mark each remaining item `unverified`, and ask the user for it.

A source whose grain or key is `unverified`, or a metric without an agreed definition, is an open question: list it under Open Questions and save the document as `Needs Clarification`, whatever the clarity score.
