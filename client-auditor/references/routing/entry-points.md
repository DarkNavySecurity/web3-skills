# Entry Point Signatures

Use these patterns during recon. Record file, line number, function name, and likely trust boundary for every match.

| Framework | Patterns to grep |
|-----------|------------------|
| Substrate/Rust | `fn on_initialize`, `fn on_finalize`, `fn apply_extrinsic`, `fn execute_block`, `fn on_idle`, `fn on_offchain_worker`, `#\[pallet::call\]`, `fn handle_`, `rpc_methods`, `register_rpc`, `fn validate_unsigned`, `fn pre_dispatch` |
| Go (Cosmos SDK) | `EndBlock`, `BeginBlock`, `FinalizeBlock`, `DeliverTx`, `CheckTx`, `PrepareProposal`, `ProcessProposal`, `RegisterRoutes`, `NewQuerier`, `Receive`, `OnReceive` |
| Go (execution client) | `Handle`, `handleMsg`, `ApplyTransaction`, `Finalize`, `Seal`, `VerifyHeader`, `RegisterApis` |
| C/C++ | `processLedger`, `doApply`, `onConsensus`, `handleMessage`, `onMessage`, `handler`, `doCommand` |
| Universal | `unsafe`, `unwrap()`, `panic!`, `unreachable!`, `expect(`, `todo!`, `unimplemented!` |

Also search for message type enum dispatch, protobuf services, bridge or cross-layer handlers, XCM/IBC handlers, precompile dispatch tables, mempool admission, database commit paths, and network codec boundaries.
