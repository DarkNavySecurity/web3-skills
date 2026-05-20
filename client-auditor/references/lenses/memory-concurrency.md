# Lens: Memory And Concurrency

Use for unsafe Rust, C/C++, FFI, raw buffers, locks, async tasks, shared caches, cancellation, and race-sensitive state.

## Questions

- Can attacker-controlled lengths, offsets, or counts reach unchecked indexing, pointer arithmetic, casts, shifts, or allocation?
- Are unsafe Rust blocks justified by invariants that are actually enforced at all call sites?
- Do FFI boundaries validate ownership, lifetime, alignment, nullability, and thread-safety assumptions?
- Can locks be acquired in inconsistent order or held across await/blocking calls?
- Can cancellation, timeout, or disconnect leave shared state half-updated?
- Are caches and maps protected consistently across reads and writes, including callbacks and background tasks?
- Does platform-dependent behavior change serialization, hashing, ordering, arithmetic, or consensus-visible output?

## Evidence Expectations

Promotion findings must identify the concurrent actors or memory boundary, attacker-controlled input, the violated invariant, and whether impact is crash, corruption, data race, nondeterminism, or consensus-visible divergence.
