# Discovery Playbook

Use this during recon to reduce missed entry points. Record what you found and what remains uncertain; do not imply full coverage when discovery is partial.

## Rust Discovery

- Check `Cargo.toml`, workspace members, major crates, `runtime/`, `pallets/`, `node/`, `crates/`, `consensus/`, `network/`, `rpc/`.
- Search trait implementations and macros that hide entry points: `impl .* for`, `#[pallet::call]`, `construct_runtime!`, `async_trait`, `Service`, `NetworkBehaviour`, `Handler`, `ValidateUnsigned`, `SignedExtension`.
- Record runtime/pallet/crate boundaries and which crate owns state transitions.
- Mark unsafe/concurrency signals: `unsafe`, `Arc<Mutex`, `RwLock`, `tokio::spawn`, channels, shared caches, global statics.

## Go Discovery

- Check `go.mod`, package layout, and whether `go list ./...` is available.
- Search service registration and interface binding: `Register`, `RegisterRoutes`, `RegisterService`, `NewServer`, `Start`, `Listen`, `Handle`, `OnReceive`, `Receive`, `ABCI`, `PrepareProposal`, `ProcessProposal`.
- Record ABCI, RPC, p2p, mempool, consensus, state, and storage packages separately.
- Mark goroutine/concurrency signals: `go func`, channels, `sync.Mutex`, `sync.Map`, context cancellation, shared caches.

## C/C++ Discovery

- Check for `compile_commands.json`, `CMakeLists.txt`, `Makefile`, `meson.build`, `BUILD`, and generated code directories.
- Search network and dispatch surfaces: `handler`, `onMessage`, `process`, `doApply`, `doCommand`, `recv`, `decode`, `deserialize`, `ParseFrom`, `visit`.
- Record serialization, DB transaction, consensus, and networking ownership boundaries.
- Mark memory/concurrency signals: raw pointers, manual allocation, atomics, locks, thread pools, callbacks, platform-specific casts/shifts.

## Required Recon Notes

Add these sections to `manifest.md`:

```markdown
## Discovery Confidence
| Area | Confidence | Evidence | Miss Risk |
|------|------------|----------|-----------|

## Miss Risk Notes
- ...

## Unresolved Entry Point Questions
- ...
```

Confidence values: `high`, `medium`, or `low`. Use `low` when framework entry points are macro/generated/interface-driven and not fully resolved.
