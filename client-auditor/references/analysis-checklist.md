# Analysis Checklist

Seven lenses to apply when analyzing code at a trust boundary. These are questions to ask, not steps to execute in order — apply whichever are relevant to the code you're reading.

---

## 1. Branch Exhaustion

For every branch in the handler (if/else, switch/case, ternary, early return, loop condition):

- What does an attacker control at this branch point?
- What state does this branch modify?
- What happens on the path NOT taken — does the else/default/fallthrough have the same protections as the primary path?
- Have you read every branch, or are you assuming some are safe without checking?

The goal is completeness: a confirmed high-severity vulnerability was missed because the auditor skipped the else branch of a handler deemed "simple." Don't mark any branch as harmless without applying the other six lenses to it.

---

## 2. Zero-Trust Message Check

For messages and requests arriving from external sources:

- Can this message arrive WITHOUT the local node requesting it? (unsolicited message)
- If yes: what state does the handler modify for unsolicited messages?
- Is there correlation between a prior outbound request and this inbound message? (request ID, sequence number, pending-set check)
- Does the handler distinguish "I asked for this" from "peer just sent it"?
- What happens if an attacker sends 10,000 of these per second with no prior interaction?

Unsolicited message paths are the highest-risk surface — any peer can trigger them at will.

---

## 3. Data Lifetime Trace

For each data structure written by the handler:

- **Where** does the data go after this handler returns? (in-memory cache, database, queue, global map)
- **What bounds** exist on the data structure's size? (max entries, max bytes, per-peer isolation)
- **When** is data removed? (TTL, LRU eviction, explicit cleanup, never)
- **Injection rate**: how fast can an attacker add data? (messages/sec × data/message)
- **Cleanup rate**: how fast is data removed under normal operation? (items/sec, time between cleanup passes)
- If injection_rate > cleanup_rate, how long until resource exhaustion?

Data that enters the system but never leaves is a resource exhaustion vector.

---

## 4. Quantitative Resource Accounting

For each resource-consuming operation, compute concrete numbers:

- **Cost per unit**: bytes / reads / cycles per item processed
- **Units per message**: packet_size / unit_size, or loop iteration bound
- **Rate limit**: messages/sec allowed, credit system, per-IP limit
- **Total consumption**: units_per_msg × cost_per_unit × msgs_before_disconnect
- **System capacity**: available memory, disk IOPS, CPU budget
- **Time to impact**: total_consumption / system_capacity

Timeline calibration: seconds = critical, minutes = high, hours = medium, days = low.

"Could allocate memory" is not a finding. "Allocates 4 KB per message × 100 messages/sec × 300 sec before disconnect = 120 MB per peer, 1000 peers = 120 GB" is a finding.

---

## 5. Missing-Defense Inventory

Before analyzing what the code DOES, check what it SHOULD do. For each handler at a trust boundary, check whether these defenses are present:

- [ ] **Input size validation** — message size, array length, field count
- [ ] **Request correlation** — is this a reply to something we asked for?
- [ ] **Per-peer resource isolation** — separate quotas/caches per peer
- [ ] **Rate limiting** — specific to this message type's cost, not just connection-level
- [ ] **Verify-before-store** — validate data before caching/persisting
- [ ] **Resource cap** — hard limit on the destination data structure
- [ ] **Load shedding** — overload detection and graceful degradation
- [ ] **Cleanup/eviction** — mechanism for removing stored data

For each: mark PRESENT (with code reference) or ABSENT. A handler with no bugs but also no defenses is still a finding — absent defenses are the vulnerability.

---

## 6. Thread Safety

*Apply only to multi-threaded clients. Skip for single-threaded runtimes.*

For each shared data structure accessed by the handler:

- Is this handler called from a single thread or multiple threads?
- What lock protects the shared state? Is it held for the entire read-modify-write sequence?
- Is there a TOCTOU gap between checking a condition and acting on it?
- Can another thread modify the data structure between this handler's read and write?
- What is the lock acquisition order? Can this handler deadlock with another code path?

---

## 7. Memory Safety

*Apply only to C/C++ and unsafe Rust. Skip for memory-managed languages.*

For each pointer, reference, or buffer operation in the handler:

- Who owns the memory being accessed? Can the owner free it while this handler runs?
- Are array/buffer accesses bounds-checked before use?
- Do any integer calculations determine allocation sizes or offsets? Can they overflow?
- For C++ iterators: can the underlying container be modified while iteration is in progress?
- For FFI boundaries: who is responsible for freeing allocated memory? Is the contract documented and enforced?
