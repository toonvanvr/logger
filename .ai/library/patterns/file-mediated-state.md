# Pattern: File-Mediated State Transfer Between Sub-Agents

**Context**: When orchestrating multiple AI sub-agents (SAs), direct context passing between them is limited. Files serve as the communication medium.

## Design

### Principle

SAs communicate by reading and writing files in `.ai/scratch/` (temporal, session-specific) and `.ai/memory/` (persistent, generic knowledge). The orchestrator coordinates by:
1. Telling each SA where to write output
2. Telling subsequent SAs where to read input

### File Types

| Location | Purpose | Lifetime |
|----------|---------|----------|
| `.ai/scratch/{date}_{topic}/` | Phase-specific WIP, drafts, SA outputs | Session |
| `.ai/memory/` | Generic reusable knowledge (handbook, design specs) | Persistent across sessions |
| `.ai/library/` | Curated patterns, skills, domain knowledge | Permanent (committed) |
| `ai_status.md` (repo root) | Human-facing status + checkpoint requests | Session |

### Rules

1. **SAs write to designated paths** — orchestrator specifies the exact output file
2. **Minimize terminal output** — SAs put results in files, not stdout
3. **No sub-agent spawning** — only 1 layer of delegation (orchestrator → SA)
4. **Append-only progress tracking** — `progress.md` is append-only to prevent state loss
5. **Scratch is temporary** — gitignored, discarded between sessions
6. **Memory is session-persistent** — kept for the session but may be archived

### Anti-Patterns

- Putting phase-specific state in `memory/` (use `scratch/` instead)
- Large terminal responses instead of file writes
- SAs trying to spawn their own sub-agents

## When to Use

- Multi-step AI workflows with orchestrator/worker pattern
- When context windows are limited and state must survive summarization
- When human checkpoints are needed between phases
