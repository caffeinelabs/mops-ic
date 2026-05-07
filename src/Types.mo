// This is a generated Motoko binding.
// Please use `import service "ic:canister_id"` instead to call canisters on the IC if possible.

module {
  public type BitcoinAddress = Text;
  public type BitcoinBlockHash = Blob;
  public type BitcoinBlockHeader = Blob;
  public type BitcoinBlockHeight = Nat32;
  public type BitcoinGetBalanceArgs = {
    network : BitcoinNetwork;
    address : BitcoinAddress;
    min_confirmations : ?Nat32;
  };
  public type BitcoinGetBalanceResult = Satoshi;
  public type BitcoinGetBlockHeadersArgs = {
    start_height : BitcoinBlockHeight;
    end_height : ?BitcoinBlockHeight;
    network : BitcoinNetwork;
  };
  public type BitcoinGetBlockHeadersResult = {
    tip_height : BitcoinBlockHeight;
    block_headers : [BitcoinBlockHeader];
  };
  public type BitcoinGetCurrentFeePercentilesArgs = {
    network : BitcoinNetwork;
  };
  public type BitcoinGetCurrentFeePercentilesResult = [MillisatoshiPerByte];
  public type BitcoinGetUtxosArgs = {
    network : BitcoinNetwork;
    filter : ?{ #page : Blob; #min_confirmations : Nat32 };
    address : BitcoinAddress;
  };
  public type BitcoinGetUtxosResult = {
    next_page : ?Blob;
    tip_height : BitcoinBlockHeight;
    tip_block_hash : BitcoinBlockHash;
    utxos : [Utxo];
  };
  public type BitcoinNetwork = { #mainnet; #testnet };
  public type BitcoinSendTransactionArgs = {
    transaction : Blob;
    network : BitcoinNetwork;
  };
  public type CanisterId = Principal;
  public type CanisterIdRange = { end : CanisterId; start : CanisterId };
  public type CanisterInfoArgs = {
    canister_id : CanisterId;
    num_requested_changes : ?Nat64;
  };
  public type CanisterInfoResult = {
    controllers : [Principal];
    module_hash : ?Blob;
    recent_changes : [Change];
    total_num_changes : Nat64;
  };
  public type CanisterInstallMode = {
    #reinstall;
    #upgrade : ?{
      wasm_memory_persistence : ?{ #keep; #replace };
      skip_pre_upgrade : ?Bool;
    };
    #install;
  };
  public type CanisterLogRecord = {
    idx : Nat64;
    timestamp_nanos : Nat64;
    content : Blob;
  };
  public type CanisterMetadataArgs = { name : Text; canister_id : CanisterId };
  public type CanisterMetadataResult = { value : Blob };
  public type CanisterSettings = {
    freezing_threshold : ?Nat;
    wasm_memory_threshold : ?Nat;
    environment_variables : ?[EnvironmentVariable];
    controllers : ?[Principal];
    reserved_cycles_limit : ?Nat;
    log_visibility : ?LogVisibility;
    snapshot_visibility : ?SnapshotVisibility;
    wasm_memory_limit : ?Nat;
    memory_allocation : ?Nat;
    compute_allocation : ?Nat;
  };
  public type CanisterStatusArgs = { canister_id : CanisterId };
  public type CanisterStatusResult = {
    memory_metrics : {
      wasm_binary_size : Nat;
      wasm_chunk_store_size : Nat;
      canister_history_size : Nat;
      stable_memory_size : Nat;
      snapshots_size : Nat;
      wasm_memory_size : Nat;
      global_memory_size : Nat;
      custom_sections_size : Nat;
    };
    status : { #stopped; #stopping; #running };
    memory_size : Nat;
    ready_for_migration : Bool;
    version : Nat64;
    cycles : Nat;
    settings : DefiniteCanisterSettings;
    query_stats : {
      response_payload_bytes_total : Nat;
      num_instructions_total : Nat;
      num_calls_total : Nat;
      request_payload_bytes_total : Nat;
    };
    idle_cycles_burned_per_day : Nat;
    module_hash : ?Blob;
    reserved_cycles : Nat;
  };
  public type Change = {
    timestamp_nanos : Nat64;
    canister_version : Nat64;
    origin : ChangeOrigin;
    details : ChangeDetails;
  };
  public type ChangeDetails = {
    #creation : {
      controllers : [Principal];
      environment_variables_hash : ?Blob;
    };
    #code_deployment : {
      mode : { #reinstall; #upgrade; #install };
      module_hash : Blob;
    };
    #load_snapshot : {
      canister_version : Nat64;
      source : { #metadata_upload : Any; #taken_from_canister : Any };
      from_canister_id : ?Principal;
      taken_at_timestamp : Nat64;
      snapshot_id : SnapshotId;
    };
    #rename_canister : {
      rename_to : {
        canister_id : CanisterId;
        version : Nat64;
        total_num_changes : Nat64;
      };
      canister_id : CanisterId;
      requested_by : Principal;
      total_num_changes : Nat64;
    };
    #controllers_change : { controllers : [Principal] };
    #code_uninstall;
  };
  public type ChangeOrigin = {
    #from_user : { user_id : Principal };
    #from_canister : { canister_version : ?Nat64; canister_id : CanisterId };
  };
  public type ChunkHash = { hash : Blob };
  public type ClearChunkStoreArgs = { canister_id : CanisterId };
  public type CreateCanisterArgs = {
    settings : ?CanisterSettings;
    sender_canister_version : ?Nat64;
  };
  public type CreateCanisterResult = { canister_id : CanisterId };
  public type DefiniteCanisterSettings = {
    freezing_threshold : Nat;
    wasm_memory_threshold : Nat;
    environment_variables : [EnvironmentVariable];
    controllers : [Principal];
    reserved_cycles_limit : Nat;
    log_visibility : LogVisibility;
    snapshot_visibility : SnapshotVisibility;
    wasm_memory_limit : Nat;
    memory_allocation : Nat;
    compute_allocation : Nat;
  };
  public type DeleteCanisterArgs = { canister_id : CanisterId };
  public type DeleteCanisterSnapshotArgs = {
    canister_id : CanisterId;
    snapshot_id : SnapshotId;
  };
  public type DepositCyclesArgs = { canister_id : CanisterId };
  public type EcdsaCurve = { #secp256k1 };
  public type EcdsaPublicKeyArgs = {
    key_id : { name : Text; curve : EcdsaCurve };
    canister_id : ?CanisterId;
    derivation_path : [Blob];
  };
  public type EcdsaPublicKeyResult = { public_key : Blob; chain_code : Blob };
  public type EnvironmentVariable = { value : Text; name : Text };
  public type FetchCanisterLogsArgs = { canister_id : CanisterId };
  public type FetchCanisterLogsResult = {
    canister_log_records : [CanisterLogRecord];
  };
  public type HttpHeader = { value : Text; name : Text };
  public type HttpRequestArgs = {
    url : Text;
    method : { #get; #put; #head; #post; #delete };
    max_response_bytes : ?Nat64;
    body : ?Blob;
    transform : ?{
      function : shared query {
          context : Blob;
          response : HttpRequestResult;
        } -> async HttpRequestResult;
      context : Blob;
    };
    headers : [HttpHeader];
    is_replicated : ?Bool;
  };
  public type HttpRequestResult = {
    status : Nat;
    body : Blob;
    headers : [HttpHeader];
  };
  public type InstallChunkedCodeArgs = {
    arg : Blob;
    wasm_module_hash : Blob;
    mode : CanisterInstallMode;
    chunk_hashes_list : [ChunkHash];
    target_canister : CanisterId;
    store_canister : ?CanisterId;
    sender_canister_version : ?Nat64;
  };
  public type InstallCodeArgs = {
    arg : Blob;
    wasm_module : WasmModule;
    mode : CanisterInstallMode;
    canister_id : CanisterId;
    sender_canister_version : ?Nat64;
  };
  public type ListCanisterSnapshotsArgs = { canister_id : CanisterId };
  public type ListCanisterSnapshotsResult = [Snapshot];
  public type ListCanistersResult = { canisters : [CanisterIdRange] };
  public type LoadCanisterSnapshotArgs = {
    canister_id : CanisterId;
    sender_canister_version : ?Nat64;
    snapshot_id : SnapshotId;
  };
  public type LogVisibility = {
    #controllers;
    #public_;
    #allowed_viewers : [Principal];
  };
  public type MillisatoshiPerByte = Nat64;
  public type NodeMetrics = {
    num_block_failures_total : Nat64;
    node_id : Principal;
    num_blocks_proposed_total : Nat64;
  };
  public type NodeMetricsHistoryArgs = {
    start_at_timestamp_nanos : Nat64;
    subnet_id : Principal;
  };
  public type NodeMetricsHistoryResult = [
    { timestamp_nanos : Nat64; node_metrics : [NodeMetrics] }
  ];
  public type Outpoint = { txid : Blob; vout : Nat32 };
  public type ProvisionalCreateCanisterWithCyclesArgs = {
    settings : ?CanisterSettings;
    specified_id : ?CanisterId;
    amount : ?Nat;
    sender_canister_version : ?Nat64;
  };
  public type ProvisionalCreateCanisterWithCyclesResult = {
    canister_id : CanisterId;
  };
  public type ProvisionalTopUpCanisterArgs = {
    canister_id : CanisterId;
    amount : Nat;
  };
  public type RawRandResult = Blob;
  public type ReadCanisterSnapshotDataArgs = {
    kind : {
      #wasm_module : { size : Nat64; offset : Nat64 };
      #wasm_memory : { size : Nat64; offset : Nat64 };
      #stable_memory : { size : Nat64; offset : Nat64 };
      #wasm_chunk : { hash : Blob };
    };
    canister_id : CanisterId;
    snapshot_id : SnapshotId;
  };
  public type ReadCanisterSnapshotDataResponse = { chunk : Blob };
  public type ReadCanisterSnapshotMetadataArgs = {
    canister_id : CanisterId;
    snapshot_id : SnapshotId;
  };
  public type ReadCanisterSnapshotMetadataResponse = {
    globals : [
      { #f32 : Float32; #f64 : Float; #i32 : Int32; #i64 : Int64; #v128 : Nat }
    ];
    canister_version : Nat64;
    source : { #metadata_upload : Any; #taken_from_canister : Any };
    certified_data : Blob;
    global_timer : ?{ #active : Nat64; #inactive };
    on_low_wasm_memory_hook_status : ?{
      #condition_not_satisfied;
      #executed;
      #ready;
    };
    wasm_module_size : Nat64;
    stable_memory_size : Nat64;
    wasm_chunk_store : [{ hash : Blob }];
    taken_at_timestamp : Nat64;
    wasm_memory_size : Nat64;
  };
  public type Satoshi = Nat64;
  public type SchnorrAlgorithm = { #ed25519; #bip340secp256k1 };
  public type SchnorrAux = { #bip341 : { merkle_root_hash : Blob } };
  public type SchnorrPublicKeyArgs = {
    key_id : { algorithm : SchnorrAlgorithm; name : Text };
    canister_id : ?CanisterId;
    derivation_path : [Blob];
  };
  public type SchnorrPublicKeyResult = { public_key : Blob; chain_code : Blob };
  public type SignWithEcdsaArgs = {
    key_id : { name : Text; curve : EcdsaCurve };
    derivation_path : [Blob];
    message_hash : Blob;
  };
  public type SignWithEcdsaResult = { signature : Blob };
  public type SignWithSchnorrArgs = {
    aux : ?SchnorrAux;
    key_id : { algorithm : SchnorrAlgorithm; name : Text };
    derivation_path : [Blob];
    message : Blob;
  };
  public type SignWithSchnorrResult = { signature : Blob };
  public type Snapshot = {
    id : SnapshotId;
    total_size : Nat64;
    taken_at_timestamp : Nat64;
  };
  public type SnapshotId = Blob;
  public type SnapshotVisibility = {
    #controllers;
    #public_;
    #allowed_viewers : [Principal];
  };
  public type StartCanisterArgs = { canister_id : CanisterId };
  public type StopCanisterArgs = { canister_id : CanisterId };
  public type StoredChunksArgs = { canister_id : CanisterId };
  public type StoredChunksResult = [ChunkHash];
  public type SubnetInfoArgs = { subnet_id : Principal };
  public type SubnetInfoResult = {
    replica_version : Text;
    registry_version : Nat64;
  };
  public type TakeCanisterSnapshotArgs = {
    replace_snapshot : ?SnapshotId;
    canister_id : CanisterId;
    uninstall_code : ?Bool;
    sender_canister_version : ?Nat64;
  };
  public type TakeCanisterSnapshotResult = Snapshot;
  public type UninstallCodeArgs = {
    canister_id : CanisterId;
    sender_canister_version : ?Nat64;
  };
  public type UpdateSettingsArgs = {
    canister_id : CanisterId;
    settings : CanisterSettings;
    sender_canister_version : ?Nat64;
  };
  public type UploadCanisterSnapshotDataArgs = {
    chunk : Blob;
    kind : {
      #wasm_module : { offset : Nat64 };
      #wasm_memory : { offset : Nat64 };
      #stable_memory : { offset : Nat64 };
      #wasm_chunk;
    };
    canister_id : CanisterId;
    snapshot_id : SnapshotId;
  };
  public type UploadCanisterSnapshotMetadataArgs = {
    globals : [
      { #f32 : Float32; #f64 : Float; #i32 : Int32; #i64 : Int64; #v128 : Nat }
    ];
    replace_snapshot : ?SnapshotId;
    certified_data : Blob;
    global_timer : ?{ #active : Nat64; #inactive };
    on_low_wasm_memory_hook_status : ?{
      #condition_not_satisfied;
      #executed;
      #ready;
    };
    wasm_module_size : Nat64;
    canister_id : CanisterId;
    stable_memory_size : Nat64;
    wasm_memory_size : Nat64;
  };
  public type UploadCanisterSnapshotMetadataResponse = {
    snapshot_id : SnapshotId;
  };
  public type UploadChunkArgs = { chunk : Blob; canister_id : CanisterId };
  public type UploadChunkResult = ChunkHash;
  public type Utxo = { height : Nat32; value : Satoshi; outpoint : Outpoint };
  public type VetkdCurve = { #bls12_381_g2 };
  public type VetkdDeriveKeyArgs = {
    context : Blob;
    key_id : { name : Text; curve : VetkdCurve };
    input : Blob;
    transport_public_key : Blob;
  };
  public type VetkdDeriveKeyResult = { encrypted_key : Blob };
  public type VetkdPublicKeyArgs = {
    context : Blob;
    key_id : { name : Text; curve : VetkdCurve };
    canister_id : ?CanisterId;
  };
  public type VetkdPublicKeyResult = { public_key : Blob };
  public type WasmModule = Blob;
  public type Self = actor {
    /// bitcoin interface
    bitcoin_get_balance : shared BitcoinGetBalanceArgs -> async BitcoinGetBalanceResult;
    bitcoin_get_block_headers : shared BitcoinGetBlockHeadersArgs -> async BitcoinGetBlockHeadersResult;
    bitcoin_get_current_fee_percentiles : shared BitcoinGetCurrentFeePercentilesArgs -> async BitcoinGetCurrentFeePercentilesResult;
    bitcoin_get_utxos : shared BitcoinGetUtxosArgs -> async BitcoinGetUtxosResult;
    bitcoin_send_transaction : shared BitcoinSendTransactionArgs -> async ();
    /// Public canister data
    canister_info : shared CanisterInfoArgs -> async CanisterInfoResult;
    canister_metadata : shared CanisterMetadataArgs -> async CanisterMetadataResult;
    canister_status : shared query CanisterStatusArgs -> async CanisterStatusResult;
    clear_chunk_store : shared ClearChunkStoreArgs -> async ();
    create_canister : shared CreateCanisterArgs -> async CreateCanisterResult;
    delete_canister : shared DeleteCanisterArgs -> async ();
    delete_canister_snapshot : shared DeleteCanisterSnapshotArgs -> async ();
    deposit_cycles : shared DepositCyclesArgs -> async ();
    /// Threshold ECDSA signature
    ecdsa_public_key : shared EcdsaPublicKeyArgs -> async EcdsaPublicKeyResult;
    /// canister logging
    fetch_canister_logs : shared query FetchCanisterLogsArgs -> async FetchCanisterLogsResult;
    http_request : shared HttpRequestArgs -> async HttpRequestResult;
    install_chunked_code : shared InstallChunkedCodeArgs -> async ();
    install_code : shared InstallCodeArgs -> async ();
    list_canister_snapshots : shared ListCanisterSnapshotsArgs -> async ListCanisterSnapshotsResult;
    /// subnet admin methods
    list_canisters : shared query () -> async ListCanistersResult;
    load_canister_snapshot : shared LoadCanisterSnapshotArgs -> async ();
    /// metrics interface
    node_metrics_history : shared NodeMetricsHistoryArgs -> async NodeMetricsHistoryResult;
    /// provisional interfaces for the pre-ledger world
    provisional_create_canister_with_cycles : shared ProvisionalCreateCanisterWithCyclesArgs -> async ProvisionalCreateCanisterWithCyclesResult;
    provisional_top_up_canister : shared ProvisionalTopUpCanisterArgs -> async ();
    raw_rand : shared () -> async RawRandResult;
    read_canister_snapshot_data : shared ReadCanisterSnapshotDataArgs -> async ReadCanisterSnapshotDataResponse;
    read_canister_snapshot_metadata : shared ReadCanisterSnapshotMetadataArgs -> async ReadCanisterSnapshotMetadataResponse;
    /// Threshold Schnorr signature
    schnorr_public_key : shared SchnorrPublicKeyArgs -> async SchnorrPublicKeyResult;
    sign_with_ecdsa : shared SignWithEcdsaArgs -> async SignWithEcdsaResult;
    sign_with_schnorr : shared SignWithSchnorrArgs -> async SignWithSchnorrResult;
    start_canister : shared StartCanisterArgs -> async ();
    stop_canister : shared StopCanisterArgs -> async ();
    stored_chunks : shared StoredChunksArgs -> async StoredChunksResult;
    /// subnet info
    subnet_info : shared SubnetInfoArgs -> async SubnetInfoResult;
    /// Canister snapshots
    take_canister_snapshot : shared TakeCanisterSnapshotArgs -> async TakeCanisterSnapshotResult;
    uninstall_code : shared UninstallCodeArgs -> async ();
    update_settings : shared UpdateSettingsArgs -> async ();
    upload_canister_snapshot_data : shared UploadCanisterSnapshotDataArgs -> async ();
    upload_canister_snapshot_metadata : shared UploadCanisterSnapshotMetadataArgs -> async UploadCanisterSnapshotMetadataResponse;
    upload_chunk : shared UploadChunkArgs -> async UploadChunkResult;
    vetkd_derive_key : shared VetkdDeriveKeyArgs -> async VetkdDeriveKeyResult;
    /// Threshold key derivation
    vetkd_public_key : shared VetkdPublicKeyArgs -> async VetkdPublicKeyResult;
  }
}
