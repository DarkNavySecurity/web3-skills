# Trust Boundaries

A trust boundary is any interface where data or control crosses from one trust level to another. Every entry point sits at one of seven levels, numbered by **attacker-pool size**. Lower number = larger pool = higher default audit priority.

## The 7 Levels

### 1. Unauthenticated network input

- **Pool**: anyone on the Internet
- **Examples**: public RPC over HTTP, JSON-RPC, REST, public WebSocket, unauthenticated P2P gossip, mempool ingest from random peers, snapshot/light-client serve, file or URL fetch driven by external requests
- **Impact ceiling (default)**: chain-halt if path reaches consensus; node-crash or remote DoS otherwise
- **Elevate to L1 from a lower tier when**: an endpoint nominally requiring credentials accepts anonymous calls in default config; an admin RPC is exposed on a public interface; SSRF lets external input reach internal services

### 2. Cross-chain / bridge inbound

- **Pool**: anyone who can post a transaction on the source chain (typically ≈ Internet)
- **Examples**: IBC packets, Wormhole VAAs, LayerZero messages, relayer-delivered cross-chain calls, light-client header submissions, oracle-pushed data from an external chain
- **Impact ceiling (default)**: same as L1 once the message enters core protocol code; trust additionally depends on the bridge's own validator set
- **Elevate when**: the bridge validator set is itself permissionless or has a known compromise history

### 3. Authenticated peer

- **Pool**: any peer that has completed the protocol handshake — no stake or durable identity required
- **Examples**: libp2p secured peer, devp2p RLPx, authenticated WebSocket subscription, post-handshake gossip topics
- **Impact ceiling (default)**: amplified DoS, gossip pollution, peer-table corruption
- **Elevate when**: the handshake gives the peer access to consensus-path code or signed-state mutation

### 4. Signed user transaction (fee / key gated)

- **Pool**: anyone holding a key plus the required fee
- **Examples**: signed transactions in block execution, mempool submission, signed contract calls, signed validator self-bonds, fee-gated RPC methods that require a signature
- **Impact ceiling (default)**: economic loss to the signer; consensus-state corruption only if the path bypasses normal validation
- **Elevate when**: the fee is trivially cheap relative to the impact

### 5. Stake-gated consensus message

- **Pool**: the active validator set
- **Examples**: block proposer payload, validator votes, consensus protocol messages, slashing evidence, pre-/post-commit messages
- **Impact ceiling (default)**: chain-halt, equivocation, finality break — impact is **high** even though pool is small
- **Severity note**: do not downgrade just because the attacker pool is small; impact dominates severity here

### 6. Operator / role-gated admin

- **Pool**: node operators or out-of-band allowlisted accounts
- **Examples**: admin RPC, debug RPC, `personal_*` namespaces, operator-only CLI subcommands, role-gated cluster endpoints, prestaked or allowlisted role
- **Impact ceiling (default)**: local node compromise, key disclosure, validator misbehavior
- **Elevate when**: the role is bound to a key with broad capabilities (signer key, withdrawal key, admin multisig member)

### 7. Internal / governance

- **Pool**: same-process callers, or on-chain governance / multisig participants
- **Examples**: IPC, in-process bus, governance proposal execution, timelock execution, root-key actions, internal cron / scheduler
- **Impact ceiling (default)**: depends entirely on what the privileged caller can do — often everything
- **Severity note**: when in scope, governance bugs are typically the highest-impact class even though L7

## Multi-Reach Rule

When a code path can be reached from more than one level, assign the **lowest-numbered (most external)** level and note the alternate path in the manifest's entry-points table `Notes` column. Severity must be calibrated against the worst reachable attacker, not the most authenticated one.

## What `trust_level` Does NOT Encode

The level only tells you the attacker-pool size for direct reach. It does **not** by itself encode:

- **Impact amplification** — whether the path runs in consensus, mempool, storage, or off-chain. Capture this in `pattern_refs`, `Subsystem` / `Focus`, or the finding's `## Impact` section.
- **Attack surface shape** — codec, state mutation, side-effect category. Capture in the entry-points `Notes` column or `pattern_refs`.
- **Deployment exposure** — public vs validator-only vs operator-internal. Note in the entry-points table.

Severity (`judging.md`) reads `trust_level` together with these orthogonal dimensions; do not try to fold them into the level itself. L5 and L7 routinely produce higher-severity findings than L3 because impact dominates.
