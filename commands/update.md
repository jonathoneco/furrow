# /furrow update

Compare project configuration against installed Furrow version.

1. Read `.claude/furrow.yaml` from the project.
2. Compare against the installed Furrow version's expected configuration.
3. Report drift: missing fields, deprecated fields, version mismatches.
4. Suggest updates if the project config is behind.
