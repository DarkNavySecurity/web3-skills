# Lens: Network Surface

Use for P2P, gossip, peer scoring, mempool admission, RPC-to-network bridges, networking codecs, and asymmetric DoS.

## Questions

- Can a low-cost peer message force high CPU, memory, disk, DB, signature, or decompression work?
- Are message size, nesting depth, collection length, and recursion limits enforced before allocation or expensive validation?
- Can peer scoring, reputation, ban, or backoff be manipulated to eclipse honest peers or preserve malicious peers?
- Does RPC expose a path into mempool, p2p broadcast, consensus state, or expensive queries without equivalent limits?
- Are per-peer, global, and per-resource rate limits coherent, or can an attacker shard across peers/IPs/topics?
- Can invalid messages poison caches, queues, bloom filters, request maps, or dedup state?
- Are partial reads, timeouts, disconnects, and cancellation paths cleaned up correctly?

## Evidence Expectations

Promotion findings should include attacker cost, victim resource cost, rate or amplification math, and the missing guard location. For DoS claims, quantify the bottleneck when possible.
