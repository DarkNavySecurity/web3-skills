# Pattern Routing

## Pattern Files

| File | Pattern IDs | Primary Focus |
|------|-------------|---------------|
| `patterns/client-attack-patterns-1.md` | PAT-01-PAT-04 | input panic, batch errors, EVM compatibility, validator state |
| `patterns/client-attack-patterns-2.md` | PAT-05-PAT-08 | vote dedup, nondeterminism, RPC crash, fee errors |
| `patterns/client-attack-patterns-3.md` | PAT-09-PAT-12 | P2P DoS, bridge integrity, unbounded compute, ZK circuits |
| `patterns/client-attack-patterns-4.md` | PAT-13-PAT-16 | charge order, replay, precision loss, wiring failures |
| `patterns/client-attack-patterns-5.md` | PAT-17-PAT-20 | memory safety, concurrency, undefined behavior, serialization |

## Applicability Filter

| ID | Applies if... |
|----|---------------|
| PAT-01 | Any attacker-controlled input reaches parsing, validation, or state transition code |
| PAT-02 | Batch loops, block finalization loops, or repeated item processing exists |
| PAT-03 | EVM compatibility layer, precompile, Frontier, geth fork, or Ethereum transaction translation exists |
| PAT-04 | Validator set, staking, session, or slashing state exists |
| PAT-05 | Voting, signatures, quorum counting, or duplicate suppression exists |
| PAT-06 | Consensus-path execution or block production exists |
| PAT-07 | RPC endpoints or external API handlers exist |
| PAT-08 | Dynamic fees, gas metering, fee markets, rewards, or charge/refund paths exist |
| PAT-09 | P2P message handlers, gossip, mempool admission, or peer scoring exists |
| PAT-10 | Bridge, XCM, IBC, cross-chain, or relayer message processing exists |
| PAT-11 | Block hooks, finalization, queue draining, or unbounded iteration exists |
| PAT-12 | ZK prover/verifier, proof parsing, or circuit constraints exist |
| PAT-13 | VM, host functions, gas charging, or pay-before-execute ordering exists |
| PAT-14 | Mempool, nonce, replay protection, fork replay, or state transition identity exists |
| PAT-15 | Rewards, balances, fees, precision, rounding, or financial accounting exists |
| PAT-16 | Module registration, route tables, plugin systems, runtime config, or hardfork wiring exists |
| PAT-17 | C/C++, unsafe Rust, FFI, raw pointers, manual memory, or unchecked indexing exists |
| PAT-18 | Threads, async shared state, locks, channels, caches, or concurrent maps exist |
| PAT-19 | C/C++ arithmetic, casts, shifts, platform-dependent serialization, or undefined behavior risk exists |
| PAT-20 | Any deserialization, codec, protobuf, scale, RLP, JSON-RPC, or binary wire format exists |

Assign only pattern files relevant to a hunt agent's subsystem and trust boundary.
