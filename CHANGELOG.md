## 4.1.0

### Additive changes

- New types: `CyclesConsumed`, `CanisterMetricsArgs`, `CanisterMetricsResult`.
- New method: `canister_metrics` (query) — returns per-category cycles consumed by a canister.

### Housekeeping

- Updated upstream `did/ic.did` source from `dfinity/portal` → `dfinity/developer-docs` (new authoritative location).
- `REGENERATING.md`: documented `didc` ≥ 0.6.x build-from-source requirement and the `PascalCase` type-name conversion step.

## 4.0.0

Types are now generated from the upstream Candid spec ([`did/ic.did`](./did/ic.did), mirrored from [`dfinity/developer-docs`](https://github.com/dfinity/developer-docs/blob/main/public/references/ic.did)) via `didc bind --target mo`. The generated module lives at `mo:ic/Types`; `mo:ic` itself stays a thin actor wrapper.

### Migration

Imports change:

```motoko
// before
import IC "mo:ic";
let args : IC.CreateCanisterArgs = ...;
await IC.ic.create_canister(args);

// after
import { ic } "mo:ic";
import IC "mo:ic/Types";
let args : IC.CreateCanisterArgs = ...;
await ic.create_canister(args);
```

### Toolchain

- `[requirements] moc` raised to `1.4.0` for `Float32` (used by `read_/upload_canister_snapshot_metadata` `globals` variants).

### Breaking type changes (aligned to upstream `.did`)

- `BitcoinNetwork`: removed `#regtest` (spec only has `#mainnet`/`#testnet`).
- `CanisterSettings` / `DefiniteCanisterSettings`: added `environment_variables`, `snapshot_visibility`. Record literals must include them (use `null` for `?` fields).
- `TakeCanisterSnapshotArgs`: added `uninstall_code : ?Bool`, `sender_canister_version : ?Nat64`.
- `ChangeDetails`:
  - new variant case `#rename_canister` — exhaustive `switch` patterns must handle it.
  - `#creation` extended with `environment_variables_hash : ?Blob`.
  - `#load_snapshot` extended with `from_canister_id : ?Principal` and `source` variant.

### Additive changes

- New methods: `canister_metadata`, `list_canisters`, `read_canister_snapshot_data`, `read_canister_snapshot_metadata`, `upload_canister_snapshot_data`, `upload_canister_snapshot_metadata`.
- New types: `EnvironmentVariable`, `SnapshotVisibility`, `CanisterMetadataArgs`/`Result`, `CanisterIdRange`, `ListCanistersResult`, `ReadCanisterSnapshotData{Args,Response}`, `ReadCanisterSnapshotMetadata{Args,Response}`, `UploadCanisterSnapshotData{Args}`, `UploadCanisterSnapshotMetadata{Args,Response}`.
- `HttpRequestArgs.method`: added `#put`, `#delete` (additive on input variants).
- `CanisterStatusResult`: added `ready_for_migration : Bool`, `version : Nat64`.
- `SubnetInfoResult`: added `registry_version : Nat64`.

## 3.2.0
- Decoupled `TransformFunction` from `Transform` type

## 3.1.0

Updated types:
- `HttpRequestArgs` - Added experimental `is_replicated` field to switch between replicated and non-replicated http outcalls

## 3.0.0

Added methods:
- `subnet_info` - Get subnet information including replica version
- `vetkd_derive_key` - Derive encrypted keys using vetKD
- `vetkd_public_key` - Get public keys for vetKD

Added types:
- `SchnorrAux` - Auxiliary data for Schnorr signatures
- `SubnetInfoArgs` and `SubnetInfoResult` - For subnet information queries
- `VetkdCurve`, `VetkdDeriveKeyArgs`, `VetkdDeriveKeyResult`, `VetkdPublicKeyArgs`, `VetkdPublicKeyResult` - For vetKD (Verifiable Encrypted Threshold Key Derivation) support

Updated types:
- `CanisterSettings` - Added `wasm_memory_threshold` field
- `CanisterStatusResult` - Added `memory_metrics` field with detailed memory usage information
- `DefiniteCanisterSettings` - Added `wasm_memory_threshold` field
- `LogVisibility` - Added `#allowed_viewers` option for fine-grained log access control
- `SignWithSchnorrArgs` - Added optional `aux` field for auxiliary data
- `UninstallCodeArgs` - Renamed from `uninstall_code_args` for consistency

## 2.1.0
- Added wrappers for `ic` calls like `http_request` that automatically calculate the minimum amount of cycles and attach them with the call (by @Kamirus)

## 2.0.0

Changes:
- Added `#regtest` to `BitcoinNetwork` type

Added methods:
- `bitcoin_get_block_headers`
- `delete_canister_snapshot`
- `fetch_canister_logs`
- `list_canister_snapshots`
- `load_canister_snapshot`
- `schnorr_public_key`
- `sign_with_schnorr`
- `take_canister_snapshot`

Removed methods:
- `bitcoin_get_balance_query` (query version removed)
- `bitcoin_get_utxos_query` (query version removed)

## 1.0.1
- Add license and keywords to `mops.toml`

## 1.0.0
- Updated interface to the latest version
- New methods:
  - `bitcoin_get_balance_query`
  - `bitcoin_get_utxos_query`
  - `canister_info`
  - `node_metrics_history`
  - `install_chunked_code`
  - `stored_chunks`
  - `upload_chunk`
  - `clear_chunk_store`

**Breaking changes**:
- All `[Nat8]` types are now `Blob`