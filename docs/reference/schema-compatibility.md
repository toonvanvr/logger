# Schema Compatibility Policy

This policy applies to protocol-facing shared schemas in `packages/shared/src/`:
- `stored-entry.ts`
- `event-message.ts`
- `data-message.ts`
- `session-message.ts`
- `server-broadcast.ts`
- `viewer-command.ts`

## Compatibility Classes

### Additive (minor-safe)
- New optional fields.
- New variants only when consumers can safely ignore unknown types (or behind explicit capability flags).
- New enum values only when unknown enum values are handled safely.

### Conditionally compatible (requires migration note + tests)
- Tightened validation constraints (limits/regex/date strictness).
- Fields that become semantically required in some contexts.
- Alias deprecations (for example `sessionId` vs `session_id`) during a transition window.

## Alias Compatibility Rules

- Canonical field names take precedence when both canonical and alias forms are present in one payload.
	- Current canonical/alias pairs:
		- `session_id` (canonical) over `sessionId` (alias)
		- `text` (canonical) over `search` (alias)
- Alias behavior must be covered by transport tests for:
	- Alias-only payloads (still accepted during transition)
	- Dual-field payloads (canonical precedence)

## Deprecation Windows

- Alias removals are `conditionally compatible` until the deprecation window expires, then become `breaking`.
- Each deprecation must document:
	1. First release where deprecation is announced.
	2. Last release where alias is accepted.
	3. First release where alias is rejected.
- Protocol docs must include migration guidance while an alias remains accepted.

### Breaking (major)
- Removed fields or variants.
- Renamed fields without a compatibility alias.
- Narrowed unions or removed accepted enum values.

## Required Gate for Schema Changes

Any schema contract change must ship in the same change-set with:
1. Compatibility classification (`additive`, `conditional`, or `breaking`).
2. Updated fixtures/tests in `packages/shared/test/fixture-validation.test.ts` when relevant.
3. Protocol documentation updates in `docs/reference/protocol.md`.
4. Backward-compatible shared export surface unless explicitly marked breaking.
