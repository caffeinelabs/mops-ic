# IC management canister interface

[![mops](https://oknww-riaaa-aaaam-qaf6a-cai.raw.ic0.app/badge/mops/ic)](https://mops.one/ic)
[![documentation](https://oknww-riaaa-aaaam-qaf6a-cai.raw.ic0.app/badge/documentation/ic)](https://mops.one/ic/docs)

Motoko interface for the IC management canister (`aaaaa-aa`). The Motoko types are generated from the upstream Candid spec mirrored at [`did/ic.did`](./did/ic.did) (from [`dfinity/developer-docs`](https://github.com/dfinity/developer-docs/blob/main/public/references/ic.did)).

See [Call](https://mops.one/ic/docs/Call) module documentation for automatic calculation of the minimum amount of cycles and attaching them to the call.

## Examples

### Import
```motoko
import { ic } "mo:ic";
import IC "mo:ic/Types";
```

`ic` is the management canister actor; `IC` is the module of request/response types.

### Fetch canister status
```motoko
import { ic } "mo:ic";

let canisterId = Principal.fromText("e3mmv-5qaaa-aaaah-aadma-cai");
let canisterStatus = await ic.canister_status({ canister_id = canisterId });

Debug.print("status = " # debug_show canisterStatus.status);
Debug.print("memory_size = " # debug_show canisterStatus.memory_size);
Debug.print("module_hash = " # debug_show canisterStatus.module_hash);
Debug.print("settings = " # debug_show canisterStatus.settings);
```

### Update canister settings
Here we set the canister controllers to a single blackhole canister.
```motoko
import { ic } "mo:ic";
import IC "mo:ic/Types";

let canisterId = Principal.fromText("e3mmv-5qaaa-aaaah-aadma-cai");
let settings : IC.CanisterSettings = {
	controllers = ?[Principal.fromText("e3mmv-5qaaa-aaaah-aadma-cai")];
	compute_allocation = null;
	memory_allocation = null;
	freezing_threshold = null;
	reserved_cycles_limit = null;
	log_visibility = null;
	snapshot_visibility = null;
	wasm_memory_limit = null;
	wasm_memory_threshold = null;
	environment_variables = null;
};
await ic.update_settings({
	canister_id = canisterId;
	settings = settings;
	sender_canister_version = null;
});
```
