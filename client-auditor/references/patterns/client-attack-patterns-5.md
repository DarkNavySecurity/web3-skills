# Client Attack Patterns 17-20

Pattern families covering memory safety, concurrency, undefined behavior, and serialization — the top CVE classes for C/C++ and Rust clients. Mechanism descriptions are preserved for pattern matching.

---

## PAT-17. Memory Safety Violations

**Broken invariant**
Every memory access must target validly allocated, correctly sized, and still-owned memory. No read or write may occur outside allocation bounds, after deallocation, or through an invalidated reference.

**Attacker input surface**
P2P message handlers, RPC request parsers, transaction deserialization, consensus state accessors, FFI bridge boundaries, and any code path that operates on raw pointers, iterators, or `unsafe` blocks.

**Trigger condition**
Attacker-controlled input influences a pointer, index, or allocation size in code that lacks bounds checking, lifetime enforcement, or ownership tracking.

**State-transition path**
Malformed input → unchecked index, dangling pointer, or integer overflow in size calculation → out-of-bounds read/write, use-after-free, or double-free → heap corruption, information leak, or arbitrary code execution.

**Impact envelope**
Remote code execution is the ceiling. Heap corruption can be weaponized for arbitrary write primitives. Information leaks expose keys or internal state. Even non-exploitable crashes constitute DoS.

**False-positive signal:** all pointer accesses are bounds-checked, all lifetimes are enforced by RAII/smart pointers, and all allocations are matched with exactly one deallocation.

**Applicable to:** C, C++, unsafe Rust. Skip for Go, Java, safe Rust, and other memory-managed languages.

**Recurring disguises / variants**
- Use-after-free: object freed by one thread/callback while another still holds a reference
- Buffer overflow: attacker-controlled length field used directly as memcpy size or array index
- Double-free: error path frees a buffer, then the normal cleanup path frees it again
- Uninitialized read: stack or heap buffer used before being fully written, leaking previous contents
- Iterator invalidation: container modified (insert/erase) while iteration is in progress
- Integer overflow in allocation: `count * element_size` wraps to a small value, allocating too little

**Audit questions**
- Who owns the memory being accessed? Can the owner deallocate it while this code path runs?
- Are all array/buffer accesses preceded by a bounds check against the actual allocation size?
- Do any integer calculations (addition, multiplication) determine allocation sizes or offsets? Can they wrap?
- For each `unsafe` block in Rust: what invariants must hold for the surrounding safe code to remain sound?
- For C++ containers: can any concurrent or callback-driven code path insert/erase while iteration is active?
- At every FFI boundary: which side allocates, which side frees, and is the contract enforced?

**Attack surfaces to investigate**

- **Async handler holding raw pointer across peer lifetime:** Message handlers that store a raw pointer or reference to a peer's buffer and process the data asynchronously — if the peer disconnects before processing completes, the buffer is freed and the handler writes through a dangling pointer, enabling heap corruption or RCE.
- **Wire length field passed directly to allocator:** Deserialization paths where a length field from the wire (32-bit or 64-bit) is used directly as an allocation size or vector resize argument without validation — attacker-chosen values can cause integer overflow (wrapping to a small allocation) followed by out-of-bounds writes.
- **Iterator invalidation via concurrent container modification:** Handlers that iterate over shared containers (maps, vectors, sets) while concurrent threads or callbacks insert or erase elements — the iterator is invalidated mid-loop, dereferencing freed or relocated memory.
- **Use-after-free across timeout/event boundaries:** State machines that free objects (validator records, peer sessions, transaction contexts) on timeout or disconnection while other code paths still hold references — the next event using the stale reference triggers use-after-free and potential state corruption.

---

## PAT-18. Concurrency Defects

**Broken invariant**
Shared mutable state must be accessed atomically with respect to all concurrent observers and modifiers. Lock acquisition must follow a consistent total order to prevent deadlock.

**Attacker input surface**
Any handler called from multiple threads or async tasks that reads or writes shared state: peer connection maps, mempool data structures, consensus round state, caches, and metrics counters.

**Trigger condition**
Two or more threads access the same data without sufficient synchronization, or locks are acquired in inconsistent orders across different code paths.

**State-transition path**
Concurrent access → data race (torn read/write), TOCTOU gap (check-then-act without holding lock), or lock ordering violation → corrupted state, lost updates, deadlock, or logic bypass.

**Impact envelope**
Data races can corrupt consensus state (chain split), lose transactions (fund loss), or crash the node (DoS). Deadlocks halt the node. TOCTOU bugs can bypass authorization or double-spend.

**False-positive signal:** all shared state is protected by a single lock held for the entire read-modify-write, or if the code uses lock-free structures with correct memory ordering.

**Applicable to:** Multi-threaded clients in any language. Skip for single-threaded runtimes.

**Recurring disguises / variants**
- Data race: two threads read-modify-write a counter or map entry without mutual exclusion
- TOCTOU: handler checks a condition (e.g., "peer is authorized"), releases lock, then acts on stale result
- Deadlock: thread A holds lock X and waits for lock Y; thread B holds lock Y and waits for lock X
- Atomicity violation: a multi-step state update is interrupted between steps, leaving inconsistent state
- Signal handler races: async signal handler accesses data structures that the main thread is modifying
- Missed notification: condition variable signaled before the waiter enters wait, causing indefinite block

**Audit questions**
- For each shared data structure: what lock protects it, and is the lock held for the entire read-modify-write?
- Is there a TOCTOU gap between checking a condition and acting on it?
- What is the global lock acquisition order? Can any two code paths acquire locks in different orders?
- Are there any lock-free data structures? Are memory ordering constraints (acquire/release/seq_cst) correct?
- Can an attacker control timing (e.g., by sending messages at specific intervals) to widen race windows?
- For async/await code: can a yield point occur between a check and its dependent action?

**Attack surfaces to investigate**

- **Check-then-act TOCTOU on connection limits:** Peer management code that checks a count or condition under a read lock, releases it, then acts under a write lock — under heavy connection churn, the gap allows the count to exceed maximums, exhausting file descriptors or memory.
- **Split-lock state inconsistency:** Data structures where different aspects (e.g., mempool contents vs fee accounting, validator set vs round state) are protected by different locks — carefully timed operations can cause the two views to diverge, enabling priority manipulation or incorrect state transitions.
- **Lock ordering inversion between subsystems:** Two or more code paths that acquire the same set of locks in different orders (e.g., validator-set lock then round-state lock vs the reverse) — adversarial timing can trigger deadlock, halting the node.
- **Unsynchronized pointer read across threads:** Handlers that read shared pointers (best block, chain tip, latest state root) without holding the appropriate lock — concurrent updates can produce torn reads on non-atomic architectures, returning partially constructed objects and crashing on invalid field access.

---

## PAT-19. Undefined / Platform-Dependent Behavior

**Broken invariant**
Consensus-critical code must produce identical, defined results on every supported platform, compiler, and configuration. No operation may invoke language-level undefined behavior.

**Attacker input surface**
Arithmetic operations, type casts, pointer arithmetic, bit manipulation, floating-point calculations, and any code compiled with optimization that relies on UB-free assumptions.

**Trigger condition**
Attacker-controlled input reaches an operation whose behavior is undefined by the language standard (C/C++ UB) or varies across platforms (type widths, endianness, floating-point rounding).

**State-transition path**
Attacker input → undefined or platform-dependent operation → compiler optimizes away safety checks, or different platforms compute different results → node crash, consensus split, or security bypass.

**Impact envelope**
UB can cause compilers to eliminate safety checks (e.g., overflow checks optimized away because "signed overflow can't happen"), leading to exploitable logic changes. Platform-dependent behavior causes consensus divergence.

**False-positive signal:** all arithmetic uses defined-overflow types, all casts are bounds-checked, and all consensus arithmetic avoids floating-point.

**Applicable to:** C, C++ primarily. Also relevant to Rust FFI and assembly blocks. Less relevant to Go (defined overflow semantics) and safe Rust (panics on overflow in debug, wraps in release).

**Recurring disguises / variants**
- Signed integer overflow: C/C++ UB that compilers exploit to remove "impossible" branches
- Strict aliasing violation: accessing memory through incompatible pointer types, enabling miscompilation
- Null pointer dereference in context where compiler assumed non-null (UB-based optimization)
- Platform-dependent `sizeof`: `size_t`, `long`, or `int` width differs between 32-bit and 64-bit
- Floating-point non-determinism: different rounding modes or FMA availability across CPUs
- Unsequenced side effects: order of evaluation varies between compilers for complex expressions
- Bit shift by type width: `1 << 32` on a 32-bit int is UB in C/C++

**Audit questions**
- Are there any signed integer arithmetic operations on attacker-controlled values? Can they overflow?
- Does consensus code use `int`, `long`, `size_t`, or other platform-dependent types?
- Is floating-point arithmetic used in any consensus or fee calculation?
- Are there casts between pointer types that could violate strict aliasing?
- Does the code rely on specific evaluation order for expressions with side effects?
- For each bit shift: is the shift amount guaranteed to be less than the type width?

**Attack surfaces to investigate**

- **Signed overflow eliminating safety checks:** Fee, reward, or balance calculations using signed integer multiplication on attacker-controlled values — when overflow occurs, the compiler (exploiting C/C++ UB) may optimize away the subsequent overflow check, producing negative values or bypassing limits.
- **Platform-dependent type width in consensus arithmetic:** Consensus calculations (vote weight aggregation, stake totals, block size limits) using `int`, `long`, or `size_t` — different results on 32-bit vs 64-bit validators can be triggered by an attacker who pushes values past the 32-bit boundary, splitting the network by architecture.
- **Floating-point non-determinism in state transitions:** Block reward, fee distribution, or penalty calculations using `float`/`double` for intermediate results — different CPUs, compilers, or optimization levels produce subtly different rounding, accumulating state root divergence over many blocks.
- **Strict aliasing violation in serialization:** Serialization or deserialization routines that cast between incompatible pointer types (`char*` to `uint64_t*`) for performance — the strict aliasing violation causes compiler reordering of reads and writes, producing corrupted output on optimized builds but correct output on debug builds.

---

## PAT-20. Serialization Boundary Hardening

**Broken invariant**
Every deserialized message must be structurally valid, bounded in resource consumption, canonically encoded, and round-trip consistent before it influences any node state.

**Attacker input surface**
P2P protocol messages, RPC request bodies, transaction payloads, block headers, state sync snapshots, and any data crossing a trust boundary via wire format (protobuf, RLP, SSZ, borsh, SCALE, JSON, custom binary).

**Trigger condition**
The parser accepts input that is structurally valid at the wire level but violates semantic constraints: excessive nesting depth, length-prefix values exceeding available data, non-canonical encoding of the same logical value, or round-trip asymmetry where `encode(decode(x)) != x`.

**State-transition path**
Malformed wire data → parser accepts without full validation → excessive allocation (nesting bomb), incorrect comparison (non-canonical), or state divergence (round-trip asymmetry) → DoS, consensus split, or logic bypass.

**Impact envelope**
Nesting/size bombs cause OOM (DoS). Non-canonical encodings cause hash mismatches or comparison failures (consensus split). Round-trip asymmetry causes signatures to verify against different data than what was executed (logic bypass, potential fund theft).

**False-positive signal:** the parser enforces maximum depth/size before allocation, rejects non-canonical forms, and the codebase proves round-trip consistency for all serialized types.

**Applicable to:** All blockchain clients regardless of language. Every client has serialization boundaries.

**Recurring disguises / variants**
- Nesting depth bomb: deeply nested protobuf/JSON/RLP structures cause stack overflow or exponential parsing time
- Length-prefix overflow: a 4-byte length field claims more data than the message contains; parser allocates based on claim
- Non-canonical encoding: the same integer encoded as 1 byte or 5 bytes; different nodes hash different encodings
- Round-trip asymmetry: decode accepts relaxed input but encode produces strict output; signature verification uses re-encoded form
- Field ordering ambiguity: serialization format allows reordering of fields; different orderings produce different hashes
- Trailing garbage: parser succeeds but ignores trailing bytes; different implementations consume different amounts

**Audit questions**
- Is there a maximum nesting depth enforced during parsing? What happens if exceeded — error or panic?
- Are length-prefixed fields validated against remaining message bytes BEFORE allocation?
- Can the same logical value be encoded in multiple byte sequences? Does the parser reject non-canonical forms?
- Does `encode(decode(x)) == x` hold for all accepted inputs? Where is this tested?
- Are there any fields where declared size could be negative (signed integer) or exceed 2^31?
- Does the parser consume exactly the expected number of bytes, or can trailing data be silently ignored?

**Attack surfaces to investigate**

- **Unbounded nesting depth in recursive parsing:** Protocol message formats (protobuf, JSON, RLP, custom binary) where nested structures are parsed recursively without a depth limit — an attacker sends a deeply nested message (thousands of levels) to overflow the stack and crash the node.
- **Non-canonical integer encoding causing hash divergence:** Serialization formats that allow the same integer value to be encoded in multiple ways (leading zero bytes, variable-length encoding) — different node implementations may canonicalize differently when computing hashes, causing consensus splits on blocks containing non-canonical fields.
- **Round-trip asymmetry bypassing signature verification:** Wire formats where the decoder accepts relaxed/non-canonical input but the signature verification path re-encodes canonically before hashing — an attacker submits data where the signed bytes differ from the executed bytes, bypassing authorization.
- **Length-prefix allocation before data validation:** Deserialization paths where a length-prefix field (32-bit or 64-bit) determines allocation size, and the parser allocates before verifying that the remaining message actually contains that many bytes — an attacker sends a message with a multi-GB length claim to cause OOM before any application-level validation.
