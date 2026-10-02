
### Analytics build

Before the first task, check the entry condition: the DESIGN's status is `Ready for Build` and its DEFINE exists with a source inventory. If not, do not build. This is a blocker, not a decision fork: report what is missing and name `@skills:sdd-design` as the next step.

After the models build, run the reconciliation test the DESIGN specifies and record the compared numbers in the BUILD_REPORT.
