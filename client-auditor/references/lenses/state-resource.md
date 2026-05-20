# Lens: State And Resource Accounting

Use for state transitions, DB transactions, queues, mempool identity, replay protection, resource charging, fee accounting, cleanup, and crash consistency.

## Questions

- Does the system charge or reserve resources before expensive work and release them on every failure path?
- Are DB writes atomic across state, indexes, caches, receipts, event logs, and rollback metadata?
- Can replay identity differ across mempool, execution, consensus, bridge, or restart paths?
- Can queues, pending maps, retries, snapshots, or orphan pools grow without bounded cleanup?
- Are fee/refund/reward calculations deterministic, overflow-safe, and rounded in the intended direction?
- Can crash, cancellation, or partial commit leave state that later bypasses validation?
- Are state sync, pruning, and snapshot trust assumptions enforced before accepting data?

## Evidence Expectations

Promotion findings must name the resource or state invariant, the mutation path, and the missing cleanup/charge/atomicity guard. Include before/after state when possible.
