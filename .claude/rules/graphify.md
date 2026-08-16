# Graphify

This project has a knowledge graph at `graphify-out/` with god nodes, community
structure, and cross-file relationships, built by the `graphify` CLI.

- When asked to fix an issue or investigate a bug, use graphify to find the related
  file(s) and context before (or instead of) raw grep/read exploration: run
  `graphify query "<question>"` when `graphify-out/graph.json` exists. Use
  `graphify path "<A>" "<B>"` for relationships between two known nodes and
  `graphify explain "<concept>"` for a focused look at one node and its neighbors.
  These return a scoped subgraph, usually much smaller than `GRAPH_REPORT.md` or raw
  grep output.
- Use `graphify affected "<X>"` to find what a change to `X` impacts before editing.
- If `graphify-out/wiki/index.md` exists, use it for broad navigation instead of raw
  source browsing.
- Read `graphify-out/GRAPH_REPORT.md` only for broad architecture review, or when
  query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current
  (AST-only, no API cost).

A `PreToolUse` hook (`.claude/settings.json`) already nudges Bash/Grep and Read/Glob
calls toward graphify automatically — this file is the human-readable version of the
same policy for anyone reading CLAUDE.md.
