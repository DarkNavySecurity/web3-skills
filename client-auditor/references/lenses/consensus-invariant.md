# Lens: Consensus Invariant

Use for consensus, finality, fork choice, validator lifecycle, slashing, block production, and state-transition determinism.

## Questions

- Can two honest nodes accept different canonical state from the same inputs?
- Are fork choice tie-breakers deterministic across platforms, map iteration, time, randomness, or local DB order?
- Are block/header/proposal validation checks identical across admission, gossip, execution, and finalization?
- Can validator set, stake, epoch, or slashing state be read before the update that should define it?
- Are equivocation, duplicate vote, replay, and late-message rules consistent across forks and restarts?
- Do hardfork or protocol-version gates activate at the same height/time in all paths?
- Can partially persisted consensus state survive crash/restart and violate safety or liveness?

## Evidence Expectations

Promotion findings must cite the external consensus input, the state transition or fork-choice decision, and the broken safety/liveness property. Prefer `[DIFF-PASS]`, `[SPEC-PASS]`, or `[TRACE]` with exact branch conditions.
