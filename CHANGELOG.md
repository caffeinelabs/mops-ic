## 6.0.0

HTTPS outcalls move to pricing version `2` ("pay-as-you-go"), which charges for the resources a call consumes rather than for `max_response_bytes`. Costs come from `Prim.costHttpRequestV2` (`ic0.cost_http_request_v2`), so this release requires `moc` 2.1.0.

### Migration

`Call.httpRequest` changes from `(IC.HttpRequestArgs) -> async IC.HttpRequestResult` to a builder that always sets `pricing_version = ?2`:

```motoko
// before
let response = await Call.httpRequest(args);

// after: keep building the arguments as before
let response = await Call.httpRequestFromArgs(args).send();

// or build them in place, and narrow the reservation with what the call is expected to use
let response = await Call.httpRequest("https://example.com/api")
  .withMethod(#post)
  .withMaxResponseBytes(4_000)
  .withExpectedRoundtripTimeMs(300)
  .send();
```

Every call site fails to compile until it migrates. Switching the pricing version under an unchanged signature would have been silent.

### Breaking changes

- `Call.httpRequest(url)` returns a `Call.HttpRequest` builder. `Call.httpRequestFromArgs(args)` starts one from existing arguments and overwrites `pricing_version` with `?2`.
- `Call.Cost.httpRequest(args, expected)` prices version `2` and takes a `Call.Cost.ExpectedUsage`. Pass `Call.Cost.worstCase` for the reservation the builder attaches by default. The version `1` `Call.Cost.httpRequest(args)` is removed; `Prim.costHttpRequest` still exposes it.
- `[requirements] moc` raised to `2.1.0`, the first release with `Prim.costHttpRequestV2`.

### Additive changes

- `Call.flexibleHttpRequest(url)` and `Call.flexibleHttpRequestFromArgs(args)` build a `flexible_http_request`, in which a committee of nodes return their individual responses. `Call.Cost.flexibleHttpRequest(args, expected)` prices one.
- Both builders take `withExpected*` setters. Under version `2` the attached cycles are also each node's budget, so anything left unset falls back to the most the outcall could consume. Unspent cycles are refunded.
- A request without a `transform` reserves nothing for one. A flexible outcall with `replication` set caps its expected transformed size at the result limit divided by `min_responses`, since larger responses cannot all be delivered.
- New types: `Call.HttpMethod`, `Call.Transform`, `Call.ReplicationCounts`, `Call.HttpRequest`, `Call.FlexibleHttpRequest`, and `Call.Cost.ExpectedUsage`.

### Housekeeping

- `[toolchain] pocket-ic` pinned to `16.1.0`. The HTTPS outcall tests moved to `test/HttpRequest.test.mo` and run on PocketIC in a new `test-pocket-ic` CI job, because the `dfx` 0.30.1 replica implements an earlier draft of `ic0.cost_http_request_v2`. PocketIC makes no outcalls under `mops test`, so those tests check pricing only.

## 5.0.0

Regenerated from the upstream Candid spec through interface spec 0.70.0 (dfinity/developer-docs#394, #333, #254, #252, #346, #315, #302). Motoko record literals must name every field, so the new input/status fields below are breaking even though they are optional in Candid.

### Migration

Hand-built `IC.HttpRequestArgs`, `IC.CanisterSettings`, `IC.FetchCanisterLogsArgs`, and `CanisterStatusResult.memory_metrics` literals need the new fields (use `null` for optional ones):

```motoko
// before
let request : IC.HttpRequestArgs = { url; method; headers; body; max_response_bytes; transform; is_replicated };

// after
let request : IC.HttpRequestArgs = { url; method; headers; body; max_response_bytes; transform; is_replicated; pricing_version = null };
```

`Call.httpRequest` is unchanged: it still takes `IC.HttpRequestArgs` and still attaches the version-1 (`ic0.cost_http_request`) cost. Pass `pricing_version = ?2` only after computing and attaching a version-2 reservation yourself. `moc` 2.1.0 exposes `Prim.costHttpRequestV2` (`ic0.cost_http_request_v2`); this package does not call it.

`IC.StatusVisibility` spells the Candid `public` case as `#public_` (Motoko reserved word).

### Breaking changes

- `CanisterSettings` / `DefiniteCanisterSettings`: added `minimum_incoming_canister_call_cycles` (spec 0.64.0, dfinity/developer-docs#302), `log_memory_limit` (spec 0.67.0, dfinity/developer-docs#252), `status_visibility` (spec 0.65.0, dfinity/developer-docs#315).
- `HttpRequestArgs`: added `pricing_version : ?Nat32` — `1` (legacy, default, deprecated) or `2` (pay-as-you-go). Spec 0.68.0, dfinity/developer-docs#254.
- `FetchCanisterLogsArgs`: added `filter : ?{ #by_idx; #by_timestamp_nanos }` (spec 0.67.0, dfinity/developer-docs#252).
- `CanisterStatusResult.memory_metrics`: added `log_memory_store_size : Nat` (spec 0.67.0).

### Additive changes

- New types: `StatusVisibility`, `FlexibleHttpRequestArgs`, `FlexibleHttpRequestErr`, `FlexibleHttpRequestResult`, `HttpRequestResourceReport`, `SubnetMetricsArgs`, `SubnetMetricsResult`.
- New method: `ic.flexible_http_request` — committee of nodes return individual HTTP responses instead of subnet consensus (spec 0.68.0, dfinity/developer-docs#254).
- New method: `ic.subnet_metrics` (update) — subnet-wide metrics for a subnet: `block_height`, `num_canisters`, `canister_state_bytes`, `consumed_cycles_total`, `update_transactions_total`, and `million_round_instructions_total` (instructions in units of one million, rounded up). Experimental. Spec 0.69.0, dfinity/developer-docs#333.
- `EcdsaCurve` gains `#secp256r1` (threshold ECDSA on NIST P-256; signatures and SLIP-10 derivation match `secp256k1`). `Call.Cost.signWithEcdsa` maps it to `1`, the `ic0.cost_sign_with_ecdsa` curve argument. Spec 0.70.0, dfinity/developer-docs#394. Exhaustive `switch`es on `EcdsaCurve` must handle the new case; constructing `#secp256k1` is unchanged.
- `canister_info` is now a query method on `Types.Self` (spec 0.67.0, dfinity/developer-docs#346); inter-canister update calls still work.

### Housekeeping

- Refreshed `did/ic.did` from `dfinity/developer-docs` main (spec 0.64.0–0.70.0).
- `REGENERATING.md`: install `didc` 0.6.2 from the GitHub release instead of building from source.
- `[toolchain] moc` raised to `2.1.0`. `[requirements] moc` stays `1.4.0` (`Float32`). Dropped `--default-persistent-actors` from `[moc].args` (`moc` 2.0 removes the flag; actors are persistent by default). `Call.Cost.httpRequest` uses `Array.values()` instead of the `.vals()` that `moc` 1.16 deprecates (`M0269`).

## 4.2.0

### Additive changes

- `HttpRequestArgs.method` gains the `#patch` case. The IC interface spec added `patch` to `http_request` (dfinity/developer-docs#289, merged 2026-06-29); `PATCH` HTTPS outcalls are rolled out across all subnets. Additive variant-case change — existing `#get`/`#head`/`#post`/`#put`/`#delete` callers are unaffected.

### Housekeeping

- Refreshed `did/ic.did` from `dfinity/developer-docs` main (only the `http_request_args.method` variant changed).

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